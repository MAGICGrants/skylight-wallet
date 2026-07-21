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
import 'package:spice_wallet/wallets/wallet_manager.dart';

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

  const ConnectionSettingsForm({
    super.key,
    required this.coinSymbol,
    required this.saveButtonLabel,
    required this.onSaved,
    this.isInDialog = false,
    this.onBeforeSave,
    this.target = ConnectionTarget.node,
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

  /// Background/continuous sync only helps a Monero full-node connection (the
  /// slow on-device scan); LWS syncs server-side. Android-only.
  bool get _showSyncOptions =>
      Platform.isAndroid && widget.coinSymbol == 'XMR' && !_isExplorer && _connectionType == 'node';

  @override
  void initState() {
    super.initState();
    _loadPersistedConnection();
    if (_showSyncOptions) _loadSyncPrefs();
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
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.foregroundSyncEnabled, value);
    if (value) {
      await startForegroundSync();
    } else {
      await stopForegroundSync();
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
      _hasTested = true;
      _connectionTestIsLoading = true;
      _connectionSuccess = false;
      _errorMessage = null;
    });

    try {
      final proxyPort = await _resolveProxyPort();
      if (_isExplorer) {
        await wallet.testExplorerConnection(
          address: daemonAddress,
          proxyPort: proxyPort,
          useSsl: _useSsl,
          useTor: _useTor,
        );
      } else {
        await wallet.testConnection(
          address: daemonAddress,
          proxyPort: proxyPort,
          useSsl: _useSsl,
          useTor: _useTor,
          connectionType: _connectionType,
        );
      }
      if (!mounted) return;
      setState(() {
        _connectionSuccess = true;
      });
    } catch (error) {
      log(LogLevel.warn, 'testConnection failed: $error', coin: widget.coinSymbol);
      if (!mounted) return;
      setState(() {
        _connectionSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _connectionTestIsLoading = false;
        });
      }
    }
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
        useSsl: _useSsl,
      );
      await wallet.persistExplorerConnection();
    } else {
      wallet.setConnection(
        address: daemonAddress,
        proxyPort: proxyAddress,
        useTor: _useTor,
        useSsl: _useSsl,
        connectionType: _connectionType,
      );
      await wallet.persistCurrentConnection();
    }

    // Sync only applies to a Monero node connection. If this XMR connection is
    // saved as non-node, turn any enabled sync off so it isn't left running
    // with no visible toggle to disable it.
    if (widget.coinSymbol == 'XMR' && !_isExplorer && _connectionType != 'node') {
      await _disableSync();
    }

    await widget.onBeforeSave?.call();

    widget.onSaved();
  }

  Future<void> _disableSync() async {
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.backgroundSyncEnabled, false);
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.foregroundSyncEnabled, false);
    await applyBackgroundTaskRegistration();
    await stopForegroundSync();
    if (mounted) {
      setState(() {
        _backgroundSyncEnabled = false;
        _foregroundSyncEnabled = false;
      });
    }
  }

  /// Right-aligned status chips under the address field (Tor / HTTPS / local).
  Widget _syncCheckbox({
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      secondary: Tooltip(
        message: description,
        triggerMode: TooltipTriggerMode.tap,
        child: Icon(Icons.help_outline, size: 20),
      ),
    );
  }

  Widget _buildConnectionIndicators(AppLocalizations i18n, TorMode torMode) {
    final chips = <Widget>[];

    if (_useTor) {
      chips.add(
        _statusChip(
          icon: SvgPicture.asset('assets/icons/tor.svg', width: 13, height: 13),
          label: torMode == TorMode.builtIn
              ? i18n.connectionIndicatorTorInternal
              : i18n.connectionIndicatorTorExternal(TorSettingsService.sharedInstance.socksPort),
          color: Colors.purple,
        ),
      );
    }

    if (_useSsl) {
      chips.add(
        _statusChip(
          icon: Icon(Icons.lock, size: 13, color: Colors.green),
          label: i18n.connectionIndicatorHttps,
          color: Colors.green,
        ),
      );
    } else if (_isLocalAddress(_cleanAddress(_addressController.text))) {
      chips.add(
        _statusChip(
          icon: Icon(Icons.lock_open, size: 13, color: Colors.grey),
          label: i18n.connectionIndicatorLocal,
          color: Colors.grey,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Wrap(spacing: 16, alignment: WrapAlignment.center, children: chips),
    );
  }

  Widget _statusChip({required Widget icon, required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        if (_connectionTypeOptions.length > 1)
          Center(
            child: SegmentedButton<String>(
              segments: _connectionTypeOptions
                  .map(
                    (type) => ButtonSegment<String>(
                      value: type,
                      label: Text(_connectionTypeLabel(i18n, type)),
                    ),
                  )
                  .toList(),
              selected: {_connectionType},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => _setConnectionType(selection.first),
            ),
          ),
        TextFormField(
          controller: _addressController,
          onChanged: _onAddressChange,
          decoration: InputDecoration(
            labelText: addressLabel,
            hintText: addressHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (Platform.isAndroid || Platform.isIOS)
                  IconButton(onPressed: _scanQrCode, icon: Icon(Icons.qr_code)),
                if (_hasTested && !_connectionTestIsLoading)
                  Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      _connectionSuccess ? Icons.check : Icons.cancel_outlined,
                      color: _connectionSuccess ? Colors.teal : Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          keyboardType: TextInputType.url,
        ),
        if (_errorMessage != null)
          Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        TextFormField(
          controller: _customProxyPortController,
          onChanged: _onProxyPortChange,
          enabled: !_useTor,
          decoration: InputDecoration(
            labelText: i18n.lwsSetupProxyPortLabel,
            hintText: i18n.lwsSetupProxyPortHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: Text(i18n.lwsSetupUseTorLabel),
              value: _useTor,
              onChanged: torMode == TorMode.disabled ? null : _setUseTor,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_showSyncOptions) ...[
              _syncCheckbox(
                label: i18n.settingsBackgroundSyncLabel,
                description: i18n.settingsBackgroundSyncDescription,
                value: _backgroundSyncEnabled,
                onChanged: _setBackgroundSyncEnabled,
              ),
              _syncCheckbox(
                label: i18n.settingsForegroundSyncLabel,
                description: i18n.settingsForegroundSyncDescription,
                value: _foregroundSyncEnabled,
                onChanged: _setForegroundSyncEnabled,
              ),
            ],
          ],
        ),
        _buildConnectionIndicators(i18n, torMode),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            if (_useTor &&
                torMode == TorMode.builtIn &&
                _torStatus != TorConnectionStatus.connected)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text(i18n.lwsSetupStartingTor),
                ],
              )
            else
              TextButton.icon(
                label: Text(i18n.lwsSetupTestConnectionButton),
                onPressed: () => _testConnection(),
                icon: !_connectionTestIsLoading
                    ? Icon(Icons.network_check)
                    : SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
              ),
            if (_connectionSuccess && _hasTested && !_connectionTestIsLoading)
              FilledButton.icon(onPressed: _saveConnection, label: Text(widget.saveButtonLabel)),
          ],
        ),
      ],
    );
  }
}
