import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/periodic_tasks.dart';
import 'package:spice_wallet/services/foreground_sync_service.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/services/tor_service.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

const isDemoMode = String.fromEnvironment('DEMO_MODE') == 'true';

final ipAddressRegex = RegExp(
  r'(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)){3}(?::\d{1,5})?$',
);
final domainAddressRegex = RegExp(
  r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}(?::\d{1,5})?$',
);
final onionAddressRegex = RegExp(r'[a-z2-7]{56}.onion(:\d{1,5})?$');

/// Which connection a [ConnectionSettingsForm] reads/writes/tests: the wallet's
/// node server, or its optional explorer.
enum ConnectionTarget { node, explorer }

/// Shared form widget for editing a server connection (address + Tor/SSL/proxy
/// + test). Operates against the wallet identified by [coinSymbol], on either
/// the node or the explorer connection per [target].
class ConnectionSettingsForm extends StatefulWidget {
  final String coinSymbol;
  final String saveButtonLabel;
  final VoidCallback onSaved;
  final bool isInDialog;
  final Future<void> Function()? onBeforeSave;
  final ConnectionTarget target;

  /// When true the Save button is pinned to the bottom of the available height
  /// (the fields scroll above it), matching the connection-setup screen. When
  /// false Save sits inline at the end of the form (dialogs / explorer setup).
  final bool pinnedSave;

  /// Fires with the selected connection type ('lws' / 'node' / '') on load and
  /// whenever the segmented control changes, so the screen can update its copy.
  final ValueChanged<String>? onConnectionTypeChanged;

  const ConnectionSettingsForm({
    super.key,
    required this.coinSymbol,
    required this.saveButtonLabel,
    required this.onSaved,
    this.isInDialog = false,
    this.onBeforeSave,
    this.target = ConnectionTarget.node,
    this.pinnedSave = false,
    this.onConnectionTypeChanged,
  });

  @override
  State<ConnectionSettingsForm> createState() => _ConnectionSettingsFormState();
}

class _ConnectionSettingsFormState extends State<ConnectionSettingsForm> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _customProxyPortController = TextEditingController();

  bool _useTor = false;
  bool _useSsl = false;
  String _connectionType = '';
  List<String> _connectionTypeOptions = const [];
  bool _hasTested = false;
  bool _connectionTestIsLoading = false;
  bool _connectionSuccess = false;
  String? _errorMessage;
  bool _backgroundSyncEnabled = false;
  bool _foregroundSyncEnabled = false;
  TorConnectionStatus _torStatus = TorService.sharedInstance.status;
  Timer? _torStatusTimer;
  bool _testCancelled = false;
  int? _latencyMs;

  /// Background / continuous sync only matter for a Monero **node** scan — the
  /// one heavy background job. LWS syncs server-side, so the toggles are hidden
  /// there (nothing to keep advancing in the background). Android-only.
  bool get _showSyncOptions =>
      Platform.isAndroid && widget.coinSymbol == 'XMR' && !_isExplorer && _connectionType == 'node';

  @override
  void initState() {
    super.initState();
    _loadPersistedConnection();
    // Load the toggle values up front (they're cheap global prefs); their
    // visibility is gated by _showSyncOptions, which only shows them in node
    // mode once the connection type has loaded / been selected.
    if (Platform.isAndroid && widget.coinSymbol == 'XMR' && !_isExplorer) _loadSyncPrefs();
  }

  Future<void> _loadSyncPrefs() async {
    final bg =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.backgroundSyncEnabled) ??
        false;
    final fg =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.foregroundSyncEnabled) ??
        false;
    if (mounted) {
      setState(() {
        _backgroundSyncEnabled = bg;
        _foregroundSyncEnabled = fg;
      });
    }
  }

  void _setBackgroundSyncEnabled(bool value) async {
    setState(() => _backgroundSyncEnabled = value);
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.backgroundSyncEnabled, value);
    await applyBackgroundTaskRegistration();
  }

  void _setForegroundSyncEnabled(bool value) async {
    setState(() => _foregroundSyncEnabled = value);
    // Capture before the await so context isn't used across an async gap. Seed
    // the notification "synced" only when every active wallet is caught up.
    final active = value
        ? Provider.of<WalletManager>(context, listen: false).activeWallets
        : const <CryptoWallet>[];
    final synced = active.isNotEmpty && active.every(isWalletFullySynced);
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.foregroundSyncEnabled, value);
    if (value) {
      await startForegroundSync(synced: synced);
    } else {
      await stopForegroundSync();
    }
  }

  /// Turns off both node-only sync options and stops their services. Called when
  /// an LWS connection is saved: LWS has nothing to keep advancing in the
  /// background, and the toggles are hidden there. The WorkManager task is then
  /// re-evaluated — it stays only if Notifications still needs it, on the lighter
  /// constraint.
  Future<void> _disableSyncForLws() async {
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.backgroundSyncEnabled, false);
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.foregroundSyncEnabled, false);
    await stopForegroundSync();
    await applyBackgroundTaskRegistration();
    if (mounted) {
      setState(() {
        _backgroundSyncEnabled = false;
        _foregroundSyncEnabled = false;
      });
    }
  }

  @override
  void dispose() {
    _torStatusTimer?.cancel();
    _addressController.dispose();
    _customProxyPortController.dispose();
    super.dispose();
  }

  bool get _isExplorer => widget.target == ConnectionTarget.explorer;

  Future<void> _loadPersistedConnection() async {
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(widget.coinSymbol);
    if (wallet == null) return;

    final conn = await (_isExplorer
        ? wallet.getPersistedExplorerConnection()
        : wallet.getPersistedConnection());

    final options = _isExplorer ? const <String>[] : wallet.connectionTypeOptions;

    setState(() {
      _addressController.text = conn.address;
      _customProxyPortController.text = conn.proxyPort;
      _useTor = conn.useTor && TorSettingsService.sharedInstance.torMode != TorMode.disabled;
      _useSsl = _sslForAddress(conn.address);
      _connectionTypeOptions = options;
      _connectionType = options.contains(conn.connectionType)
          ? conn.connectionType
          : (options.isNotEmpty ? options.first : '');
    });
    widget.onConnectionTypeChanged?.call(_connectionType);

    if (conn.useTor && TorSettingsService.sharedInstance.torMode == TorMode.builtIn) {
      _pollTorStatus();
    }
  }

  String _cleanAddress(String value) {
    return value.trim().replaceAll(RegExp(r'https?:\/\/'), '');
  }

  bool _isValidConnectionAddress(String value) {
    final connectionUrlRegex = RegExp(
      [ipAddressRegex.pattern, onionAddressRegex.pattern, domainAddressRegex.pattern].join('|'),
    );

    if (!connectionUrlRegex.hasMatch(value)) return false;
    // Remote (public) IP addresses are not allowed: use a domain (SSL) or a
    // local IP. Only IP literals are checked; domains/onion are fine.
    return !_isNonLocalIp(value);
  }

  /// Private/loopback IPv4 ranges that we consider "local network".
  bool _isLocalIp(String host) {
    if (host.startsWith('192.168.') || host.startsWith('10.') || host.startsWith('127.')) {
      return true;
    }
    final match = RegExp(r'^172\.(\d{1,3})\.').firstMatch(host);
    if (match != null) {
      final second = int.tryParse(match.group(1)!) ?? 0;
      return second >= 16 && second <= 31;
    }
    return false;
  }

  bool _isNonLocalIp(String value) {
    final host = value.split(':').first;
    return ipAddressRegex.hasMatch(value) && !_isLocalIp(host);
  }

  bool _sslForAddress(String value) {
    final host = value.split(':').first;
    if (onionAddressRegex.hasMatch(value)) return false;
    if (ipAddressRegex.hasMatch(value)) return false;
    if (host.endsWith('.local')) return false;
    return domainAddressRegex.hasMatch(value);
  }

  bool _isLocalAddress(String value) {
    final host = value.split(':').first;
    if (ipAddressRegex.hasMatch(value)) return _isLocalIp(host);
    return host.endsWith('.local');
  }

  Future<void> _scanQrCode() async {
    final i18n = AppLocalizations.of(context)!;

    final result = await Navigator.pushNamed(context, '/scan_qr');

    if (result != null && result is String) {
      final scannedAddress = _cleanAddress(result);
      if (_isValidConnectionAddress(scannedAddress)) {
        _addressController.text = scannedAddress;
        _onAddressChange(scannedAddress);
      } else {
        if (mounted) {
          if (widget.isInDialog) {
            setState(() {
              _errorMessage = i18n.lwsSetupInvalidQrCode;
            });
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(i18n.lwsSetupInvalidQrCode)));
          }
        }
      }
    }
  }

  void _onAddressChange(String rawValue) {
    final hadProtocol = RegExp(r'https?:\/\/').hasMatch(rawValue);
    final value = _cleanAddress(rawValue);

    // Strip any http(s):// the user typed from the field itself so it's ignored.
    if (_addressController.text != value) {
      _addressController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }

    final useTor = onionAddressRegex.hasMatch(value);
    final useSsl = _sslForAddress(value);
    final i18n = AppLocalizations.of(context)!;

    _setUseSsl(useSsl);
    // Never auto-disable Tor if the user already turned it on.
    _setUseTor(useTor || _useTor);

    setState(() {
      _hasTested = false;
      _errorMessage = _isNonLocalIp(value) ? i18n.connectionRemoteIpNotAllowed : null;
    });

    if (hadProtocol) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(useSsl ? i18n.connectionProtocolHttps : i18n.connectionProtocolHttp),
          ),
        );
    }
  }

  void _onProxyPortChange(String value) {
    setState(() {
      _hasTested = false;
    });
  }

  void _setUseTor(bool? value) {
    if (TorSettingsService.sharedInstance.torMode == TorMode.disabled) {
      log(LogLevel.info, 'Tor is disabled. Not setting useTor to true.');
      value = false;
    }

    setState(() {
      _useTor = value ?? false;
      _hasTested = false;
    });

    if (value == true) {
      _customProxyPortController.text = '';

      if (TorSettingsService.sharedInstance.torMode == TorMode.builtIn) {
        _pollTorStatus();
      }
    }
  }

  void _pollTorStatus() {
    _torStatusTimer?.cancel();

    // Sync to the live status now so a stale snapshot can't keep the
    // "starting" indicator up.
    final current = TorService.sharedInstance.status;
    if (current != _torStatus) {
      setState(() => _torStatus = current);
    }
    if (current == TorConnectionStatus.connected) return;

    _torStatusTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final status = TorService.sharedInstance.status;
      if (status == TorConnectionStatus.connected) {
        timer.cancel();
        if (mounted) setState(() => _torStatus = status);
      }
    });
  }

  void _setUseSsl(bool? value) {
    setState(() {
      _useSsl = value ?? false;
      _hasTested = false;
    });
  }

  void _setConnectionType(String value) {
    setState(() {
      _connectionType = value;
      _hasTested = false;
      _errorMessage = null;
    });
    widget.onConnectionTypeChanged?.call(value);
  }

  String _connectionTypeLabel(AppLocalizations i18n, String type) {
    switch (type) {
      case 'node':
        return i18n.connectionTypeNode;
      case 'lws':
        return i18n.connectionTypeLws;
      default:
        return type;
    }
  }

  /// Resolves the SOCKS proxy port to pass to `wallet.testConnection`.
  /// When the user enabled Tor, this comes from the running TorService;
  /// otherwise it's the optional custom HTTP/SOCKS proxy field.
  Future<String?> _resolveProxyPort() async {
    if (_useTor) {
      final proxyInfo = await TorSettingsService.sharedInstance.getProxy();
      return proxyInfo?.port.toString();
    }
    final custom = _customProxyPortController.text.trim();
    return custom.isEmpty ? null : custom;
  }

  Future _testConnection() async {
    final i18n = AppLocalizations.of(context)!;
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(widget.coinSymbol);
    if (wallet == null) return;

    final daemonAddress = _cleanAddress(_addressController.text);

    if (isDemoMode && daemonAddress == 'demo') {
      setState(() {
        _hasTested = true;
        _connectionSuccess = true;
      });
      return;
    }

    if (_isNonLocalIp(daemonAddress)) {
      setState(() {
        _hasTested = false;
        _errorMessage = i18n.connectionRemoteIpNotAllowed;
      });
      return;
    }

    if (_useTor && TorSettingsService.sharedInstance.torMode == TorMode.disabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(i18n.lwsSetupTorDisabledError)));
      return;
    }

    setState(() {
      _testCancelled = false;
      _hasTested = true;
      _connectionTestIsLoading = true;
      _connectionSuccess = false;
      _errorMessage = null;
      _latencyMs = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final proxyPort = await _resolveProxyPort();
      if (_isExplorer) {
        await wallet.testExplorerConnection(
          address: daemonAddress,
          proxyPort: proxyPort,
          useTor: _useTor,
        );
      } else {
        await wallet.testConnection(
          address: daemonAddress,
          proxyPort: proxyPort,
          useTor: _useTor,
          connectionType: _connectionType,
        );
      }
      if (!mounted || _testCancelled) return;
      setState(() {
        _connectionSuccess = true;
        _latencyMs = stopwatch.elapsedMilliseconds;
      });
    } catch (error) {
      log(LogLevel.warn, 'testConnection failed: $error', coin: widget.coinSymbol);
      if (!mounted || _testCancelled) return;
      setState(() {
        _connectionSuccess = false;
      });
    } finally {
      if (mounted && !_testCancelled) {
        setState(() {
          _connectionTestIsLoading = false;
        });
      }
    }
  }

  /// Best-effort UI cancel: the in-flight network call can't be aborted, but we
  /// drop its result and return the card to the untested state.
  void _stopTest() {
    setState(() {
      _testCancelled = true;
      _hasTested = false;
      _connectionTestIsLoading = false;
      _connectionSuccess = false;
    });
  }

  Future<void> _saveConnection() async {
    final daemonAddress = _cleanAddress(_addressController.text);
    final proxyAddress = _customProxyPortController.text;

    if (_isNonLocalIp(daemonAddress)) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.connectionRemoteIpNotAllowed);
      return;
    }

    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(widget.coinSymbol);
    if (wallet == null) return;

    if (_isExplorer) {
      wallet.setExplorerConnection(
        address: daemonAddress,
        proxyPort: proxyAddress,
        useTor: _useTor,
      );
      await wallet.persistExplorerConnection();
    } else {
      wallet.setConnection(
        address: daemonAddress,
        proxyPort: proxyAddress,
        useTor: _useTor,
        connectionType: _connectionType,
      );
      await wallet.persistCurrentConnection();

      // Background / continuous sync are node-only; saving an LWS connection
      // stops any that were enabled for node mode, since the toggles are now
      // hidden and would otherwise keep a service running with no way to stop it.
      if (Platform.isAndroid && widget.coinSymbol == 'XMR' && _connectionType != 'node') {
        await _disableSyncForLws();
      }
    }
    await widget.onBeforeSave?.call();

    widget.onSaved();
  }

  /// Route/security pills shown on the right of the Use-Tor row.
  List<Widget> _routePills() {
    final pills = <Widget>[];
    final address = _cleanAddress(_addressController.text);
    if (_useTor) {
      pills.add(
        _RoutePill(
          label: 'TOR',
          color: BrandColors.routeTor,
          bg: BrandColors.routeTorBg,
          icon: _PillIcon.tor,
        ),
      );
    } else if (_customProxyPortController.text.trim().isNotEmpty) {
      pills.add(
        _RoutePill(
          label: 'PROXY',
          color: BrandColors.routeProxy,
          bg: BrandColors.routeProxyBg,
          icon: _PillIcon.proxy,
        ),
      );
    }
    if (_useSsl) {
      pills.add(
        _RoutePill(
          label: 'HTTPS',
          color: BrandColors.success,
          bg: BrandColors.successBg,
          icon: _PillIcon.https,
        ),
      );
    } else if (_isLocalAddress(address)) {
      pills.add(
        _RoutePill(
          label: 'LOCAL',
          color: BrandColors.inkFaint,
          bg: BrandColors.surfaceMuted,
          icon: _PillIcon.local,
        ),
      );
    }
    return pills;
  }

  /// How the successful probe reached the server (the one server fact we can
  /// state from an unauthenticated test). Height / subaddress support aren't
  /// returned by the probe, so they're not shown.
  String _successDetail(AppLocalizations i18n) {
    if (_useTor) return i18n.connectionReachedOverTor;
    if (_customProxyPortController.text.trim().isNotEmpty) return i18n.connectionReachedViaProxy;
    return i18n.connectionReachedDirect;
  }

  Widget _buildTestCard(AppLocalizations i18n, TorMode torMode) {
    // Built-in Tor still bootstrapping takes over the test action.
    if (_useTor && torMode == TorMode.builtIn && _torStatus != TorConnectionStatus.connected) {
      return _StatusRowCard(leading: const _Spinner(), title: i18n.lwsSetupStartingTor);
    }
    if (!_hasTested) {
      return BrandButton.secondary(
        label: i18n.lwsSetupTestConnectionButton,
        icon: Icons.wifi,
        onPressed: _testConnection,
      );
    }
    if (_connectionTestIsLoading) {
      return _StatusRowCard(
        leading: const _Spinner(),
        title: i18n.connectionTestingTitle,
        detail: i18n.connectionTestingDetail,
        trailing: BrandButton.ghost(
          label: i18n.connectionTestStop,
          dense: true,
          expand: false,
          onPressed: _stopTest,
        ),
      );
    }
    if (_connectionSuccess) {
      return _ResultCard(
        icon: Icon(Icons.check, size: 13, color: BrandColors.success),
        iconBg: BrandColors.successBg,
        title: i18n.connectionResultWorksTitle,
        trailing: _latencyMs != null ? '$_latencyMs ms' : null,
        detail: _successDetail(i18n),
        onTestAgain: _testConnection,
        testAgainLabel: i18n.connectionTestAgain,
      );
    }
    return _ResultCard.failure(
      title: i18n.connectionResultFailedTitle,
      detail: i18n.connectionResultFailedDetail,
      onTestAgain: _testConnection,
      testAgainLabel: i18n.connectionTestAgain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final torMode = TorSettingsService.sharedInstance.torMode;
    final wallet = Provider.of<WalletManager>(context, listen: false).getWallet(widget.coinSymbol);
    final addressHint =
        (_isExplorer
            ? wallet?.explorerAddressExample
            : wallet?.connectionAddressExampleForType(_connectionType)) ??
        i18n.lwsSetupAddressHint;
    final addressLabel = _isExplorer ? i18n.explorerAddressLabel : i18n.address;
    final canSave = _hasTested && _connectionSuccess && !_connectionTestIsLoading;

    final content = <Widget>[
      if (_connectionTypeOptions.length > 1) ...[
        BrandSegmented(
          labels: [for (final t in _connectionTypeOptions) _connectionTypeLabel(i18n, t)],
          selectedIndex: _connectionTypeOptions
              .indexOf(_connectionType)
              .clamp(0, _connectionTypeOptions.length - 1),
          onSelect: (i) => _setConnectionType(_connectionTypeOptions[i]),
        ),
        const SizedBox(height: 20),
      ],
      _InsetField(
        label: addressLabel,
        controller: _addressController,
        hint: addressHint,
        mono: true,
        keyboardType: TextInputType.url,
        onChanged: _onAddressChange,
        trailing: (Platform.isAndroid || Platform.isIOS)
            ? _FieldIconButton(icon: Icons.qr_code_2, onPressed: _scanQrCode)
            : null,
      ),
      if (_errorMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(_errorMessage!, style: BrandText.caption.copyWith(color: BrandColors.error)),
        ),
      const SizedBox(height: 16),
      _InsetField(
        label: i18n.connectionProxyPortLabel,
        controller: _customProxyPortController,
        hint: i18n.connectionProxyPortHint,
        mono: true,
        number: true,
        enabled: !_useTor,
        onChanged: _onProxyPortChange,
      ),
      const SizedBox(height: 4),
      _CheckRow(
        checked: _useTor,
        onTap: torMode == TorMode.disabled ? null : () => _setUseTor(!_useTor),
        label: i18n.lwsSetupUseTorLabel,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: _routePills()),
      ),
      if (_showSyncOptions) ...[
        _CheckRow(
          checked: _backgroundSyncEnabled,
          onTap: () => _setBackgroundSyncEnabled(!_backgroundSyncEnabled),
          label: i18n.settingsBackgroundSyncLabel,
          help: i18n.settingsBackgroundSyncDescription,
        ),
        _CheckRow(
          checked: _foregroundSyncEnabled,
          onTap: () => _setForegroundSyncEnabled(!_foregroundSyncEnabled),
          label: i18n.settingsForegroundSyncLabel,
          help: i18n.settingsForegroundSyncDescription,
        ),
      ],
      const SizedBox(height: 16),
      _buildTestCard(i18n, torMode),
    ];

    final saveButton = BrandButton(
      label: widget.saveButtonLabel,
      onPressed: canSave ? _saveConnection : null,
    );

    if (widget.pinnedSave) {
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: content,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), child: saveButton),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...content, const SizedBox(height: 16), saveButton],
    );
  }
}

/// Bordered inset field with an optional floating label sitting on the border.
class _InsetField extends StatelessWidget {
  final String? label;
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final bool mono;
  final bool number;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  const _InsetField({
    required this.controller,
    required this.hint,
    this.label,
    this.enabled = true,
    this.mono = false,
    this.number = false,
    this.keyboardType,
    this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = enabled ? BrandColors.ink : BrandColors.inkMuted;
    final field = TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: number ? TextInputType.number : keyboardType,
      textInputAction: TextInputAction.done,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
      strutStyle: const StrutStyle(forceStrutHeight: true, height: 1.1, fontSize: 13.5),
      style: TextStyle(
        fontFamily: mono ? 'Ubuntu Mono' : 'Ubuntu',
        fontSize: 13.5,
        height: 1,
        color: textColor,
      ),
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: mono ? 'Ubuntu Mono' : 'Ubuntu',
          fontSize: 13.5,
          height: 1,
          color: BrandColors.inkMuted,
        ),
      ),
    );

    final box = BrandCard(
      radius: 14,
      borderColor: BrandColors.inputBorder,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        children: [
          Expanded(child: field),
          if (trailing != null) trailing!,
        ],
      ),
    );

    if (label == null) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: label!, padding: const EdgeInsets.only(left: 2, bottom: 9)),
        box,
      ],
    );
  }
}

/// Small icon button that sits inside a field's trailing slot (QR scan).
class _FieldIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _FieldIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(icon, size: 20, color: BrandColors.cinnamonDeep),
      ),
    );
  }
}

/// A square check + label row (Use Tor, sync toggles), with optional trailing
/// pills or a "?" help affordance.
class _CheckRow extends StatelessWidget {
  final bool checked;
  final VoidCallback? onTap;
  final String label;
  final String? help;
  final Widget? trailing;

  const _CheckRow({
    required this.checked,
    required this.onTap,
    required this.label,
    this.help,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Tap target is the check + label; vertical padding here sets the row
          // height (no extra slop on the box, which was bloating the gaps).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: checked ? BrandColors.cinnamon : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: checked ? null : Border.all(color: BrandColors.inputBorder),
                    ),
                    child: checked
                        ? const Icon(Icons.check, size: 15, color: BrandColors.onCinnamon)
                        : null,
                  ),
                  const SizedBox(width: 11),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: enabled ? BrandColors.ink : BrandColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (help != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: help!,
              triggerMode: TooltipTriggerMode.tap,
              child: Container(
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: BrandColors.inputBorder, width: 1.4),
                ),
                child: Text(
                  '?',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.inkMuted,
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

enum _PillIcon { tor, https, proxy, local }

/// Small route/security pill (TOR · HTTPS · PROXY · LOCAL). Icons are the exact
/// design line marks, tinted to the pill colour.
class _RoutePill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final _PillIcon icon;

  const _RoutePill({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });

  String _svg() {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    switch (icon) {
      case _PillIcon.tor:
        return '<svg viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2">'
            '<circle cx="12" cy="12" r="8.5"/><ellipse cx="12" cy="12" rx="3.6" ry="8.5"/>'
            '<path d="M3.5 12h17"/></svg>';
      case _PillIcon.https:
        return '<svg viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2.2" stroke-linecap="round">'
            '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>';
      case _PillIcon.proxy:
        return '<svg viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="M4 12h4M16 12h4"/><circle cx="12" cy="12" r="3.2"/></svg>';
      case _PillIcon.local:
        return '<svg viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2.2" stroke-linecap="round">'
            '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V7.5a4 4 0 0 1 7-2.6"/></svg>';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.string(_svg(), width: 11, height: 11),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Ubuntu Mono',
              fontSize: 9.5,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.76,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// White card container for the test-result states.
class _TestCard extends StatelessWidget {
  final Widget child;
  const _TestCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 4, 15, 10),
      child: child,
    );
  }
}

/// 22px spinner used in the "starting Tor" / "testing" states.
class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: BrandColors.cinnamonDeep,
        backgroundColor: BrandColors.border,
      ),
    );
  }
}

/// A leading + title (+ detail / trailing) row card, used for the Tor-starting
/// and test-running states.
class _StatusRowCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? detail;
  final Widget? trailing;

  const _StatusRowCard({required this.leading, required this.title, this.detail, this.trailing});

  @override
  Widget build(BuildContext context) {
    return _TestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.only(top: 8, bottom: detail != null ? 10 : 8),
            decoration: detail != null
                ? BoxDecoration(
                    border: Border(bottom: BorderSide(color: BrandColors.hairline)),
                  )
                : null,
            child: Row(
              children: [
                leading,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.ink,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Text(
                detail!,
                style: TextStyle(fontSize: 12.5, height: 1.45, color: BrandColors.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Test finished — success (green) or failure (red).
class _ResultCard extends StatelessWidget {
  final Widget? icon;
  final Color? iconBg;
  final String title;
  final String? trailing;
  final String detail;
  final VoidCallback onTestAgain;
  final String testAgainLabel;
  final bool isFailure;

  const _ResultCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.detail,
    required this.onTestAgain,
    required this.testAgainLabel,
    this.trailing,
  }) : isFailure = false;

  const _ResultCard.failure({
    required this.title,
    required this.detail,
    required this.onTestAgain,
    required this.testAgainLabel,
  }) : icon = null,
       iconBg = null,
       trailing = null,
       isFailure = true;

  @override
  Widget build(BuildContext context) {
    final titleColor = isFailure ? BrandColors.error : BrandColors.ink;
    return _TestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.only(top: 8, bottom: isFailure ? 4 : 10),
            decoration: isFailure
                ? null
                : BoxDecoration(
                    border: Border(bottom: BorderSide(color: BrandColors.hairline)),
                  ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFailure ? BrandColors.errorBg : iconBg,
                  ),
                  child: isFailure ? Icon(Icons.close, size: 13, color: BrandColors.error) : icon,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 11.5,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      color: BrandColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: isFailure ? 2 : 10, bottom: isFailure ? 8 : 4),
            child: Text(
              detail,
              style: TextStyle(
                fontSize: isFailure ? 12 : 12.5,
                height: isFailure ? 1.5 : 1.45,
                color: isFailure ? BrandColors.error : BrandColors.inkMuted,
              ),
            ),
          ),
          if (isFailure)
            BrandButton(label: testAgainLabel, dense: true, onPressed: onTestAgain)
          else
            Align(
              alignment: Alignment.centerRight,
              child: BrandButton.secondary(
                label: testAgainLabel,
                dense: true,
                expand: false,
                onPressed: onTestAgain,
              ),
            ),
        ],
      ),
    );
  }
}
