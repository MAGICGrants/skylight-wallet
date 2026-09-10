import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:skylight_wallet/periodic_tasks.dart';
import 'package:skylight_wallet/services/foreground_sync_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/util/logging.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

const isDemoMode = String.fromEnvironment('DEMO_MODE') == 'true';

const connectionTypeOptions = ['lws', 'node'];

/// Shared form widget used by both ConnectionSetupScreen and the connection settings dialog
class ConnectionSettingsForm extends StatefulWidget {
  final String saveButtonLabel;
  final VoidCallback onSaved;
  final bool isInDialog;
  final Future<void> Function()? onBeforeSave;

  const ConnectionSettingsForm({
    super.key,
    required this.saveButtonLabel,
    required this.onSaved,
    this.isInDialog = false,
    this.onBeforeSave,
  });

  @override
  State<ConnectionSettingsForm> createState() => _ConnectionSettingsFormState();
}

class _ConnectionSettingsFormState extends State<ConnectionSettingsForm> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _customProxyPortController = TextEditingController();

  bool _useTor = false;
  String _connectionType = 'lws';
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

  // The as-loaded values, so save can tell what the user actually changed:
  // enabling sync or editing the connection needs a working test; disabling
  // sync alone does not.
  String _initialAddress = '';
  String _initialProxyPort = '';
  bool _initialUseTor = false;
  String _initialConnectionType = 'lws';
  bool _initialBackgroundSync = false;
  bool _initialForegroundSync = false;

  bool get _isNode => _connectionType == 'node';

  /// Background/continuous sync only helps a full-node connection (the slow
  /// on-device scan); LWS syncs server-side. Android-only.
  bool get _showSyncOptions => Platform.isAndroid && _isNode;

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
        _initialBackgroundSync = bg;
        _initialForegroundSync = fg;
      });
    }
  }

  // Toggles are pending: they stage the choice and are applied by _saveConnection
  // (enabling requires saving over a working connection; disabling does not).
  void _setBackgroundSyncEnabled(bool value) => setState(() => _backgroundSyncEnabled = value);

  void _setForegroundSyncEnabled(bool value) => setState(() => _foregroundSyncEnabled = value);

  /// Persists the pending sync selection and starts/stops the services. LWS
  /// can't sync on-device, so both are forced off when the saved connection
  /// isn't an Android node.
  Future<void> _applySyncSelection() async {
    final bg = _showSyncOptions && _backgroundSyncEnabled;
    final fg = _showSyncOptions && _foregroundSyncEnabled;
    // Captured before the await so the notification starts from the live status.
    final synced = fg && appWalletOf(context).isFullySynced;
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.backgroundSyncEnabled, bg);
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.foregroundSyncEnabled, fg);
    if (fg) {
      await startForegroundSync(synced: synced);
    } else {
      await stopForegroundSync();
    }
    await applyBackgroundTaskRegistration();
    if (mounted) {
      setState(() {
        _backgroundSyncEnabled = bg;
        _foregroundSyncEnabled = fg;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPersistedConnection();
  }

  @override
  void dispose() {
    _torStatusTimer?.cancel();
    _addressController.dispose();
    _customProxyPortController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedConnection() async {
    final wallet = appWalletOf(context);
    final conn = await wallet.getPersistedConnection();

    final useTor = conn.useTor && TorSettingsService.sharedInstance.torMode != TorMode.disabled;
    final type = connectionTypeOptions.contains(conn.connectionType) ? conn.connectionType : 'lws';
    setState(() {
      _addressController.text = conn.address;
      _customProxyPortController.text = conn.proxyPort;
      _useTor = useTor;
      _connectionType = type;
      _initialAddress = cleanConnectionAddress(conn.address);
      _initialProxyPort = conn.proxyPort;
      _initialUseTor = useTor;
      _initialConnectionType = type;
    });

    if (conn.useTor && TorSettingsService.sharedInstance.torMode == TorMode.builtIn) {
      _pollTorStatus();
    }

    if (_showSyncOptions) _loadSyncPrefs();
  }

  Future<void> _scanQrCode() async {
    final i18n = AppLocalizations.of(context)!;

    final result = await Navigator.pushNamed(context, '/scan_qr');

    if (result != null && result is String) {
      final scannedAddress = cleanConnectionAddress(result);
      if (isValidConnectionAddress(scannedAddress)) {
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
    final value = cleanConnectionAddress(rawValue);
    final i18n = AppLocalizations.of(context)!;

    // Strip any typed http(s):// from the field itself so it's ignored.
    if (_addressController.text != value) {
      _addressController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }

    final useTor = onionAddressRegex.hasMatch(value);

    // Never auto-disable Tor if the user already turned it on.
    _setUseTor(useTor || _useTor);

    setState(() {
      _hasTested = false;
      _errorMessage = isRemoteIp(value) ? i18n.connectionRemoteIpNotAllowed : null;
    });

    if (hadProtocol) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              addressUsesSsl(value) ? i18n.connectionProtocolHttps : i18n.connectionProtocolHttp,
            ),
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

      if (TorSettingsService.sharedInstance.torMode == TorMode.builtIn &&
          TorService.sharedInstance.status != TorConnectionStatus.connected) {
        _pollTorStatus();
      }
    }
  }

  void _pollTorStatus() {
    _torStatusTimer?.cancel();
    _torStatusTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      final status = TorService.sharedInstance.status;
      if (status == TorConnectionStatus.connected) {
        setState(() {
          _torStatus = status;
        });
        timer.cancel();
      }
    });
  }

  void _setConnectionType(String value) {
    setState(() {
      _connectionType = value;
      _hasTested = false;
      _errorMessage = null;
    });
    if (value == 'node' && Platform.isAndroid) _loadSyncPrefs();
  }

  String _connectionTypeLabel(AppLocalizations i18n, String type) {
    return type == 'node' ? i18n.connectionTypeNode : i18n.connectionTypeLws;
  }

  /// Resolves the SOCKS proxy port to pass to `wallet.testConnection`. When Tor
  /// is enabled this comes from the running TorService; otherwise it's the
  /// optional custom HTTP/SOCKS proxy field.
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
    final wallet = appWalletOf(context);
    final daemonAddress = cleanConnectionAddress(_addressController.text);

    if (isDemoMode && daemonAddress == 'demo') {
      setState(() {
        _hasTested = true;
        _connectionSuccess = true;
      });
      return;
    }

    if (isRemoteIp(daemonAddress)) {
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
      await wallet.testConnection(
        address: daemonAddress,
        proxyPort: proxyPort,
        useTor: _useTor,
        connectionType: _connectionType,
      );
      if (!mounted || _testCancelled) return;
      setState(() {
        _connectionSuccess = true;
        _latencyMs = stopwatch.elapsedMilliseconds;
      });
    } catch (error) {
      log(LogLevel.warn, 'testConnection failed: $error');
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
    final i18n = AppLocalizations.of(context)!;
    final daemonAddress = cleanConnectionAddress(_addressController.text);
    final proxyAddress = _customProxyPortController.text;

    if (isRemoteIp(daemonAddress)) {
      setState(() => _errorMessage = i18n.connectionRemoteIpNotAllowed);
      return;
    }

    final wallet = appWalletOf(context);

    wallet.setConnection(
      address: daemonAddress,
      proxyPort: proxyAddress,
      useTor: _useTor,
      connectionType: _connectionType,
    );

    await wallet.persistCurrentConnection();

    // Apply the pending sync selection over the connection just saved (also
    // rebuilds the background schedule, which on iOS depends on whether the
    // saved connection is LWS and whether it uses Tor).
    await _applySyncSelection();

    await widget.onBeforeSave?.call();

    widget.onSaved();
  }

  /// How the successful probe reached the server (the one server fact we can
  /// state from an unauthenticated test).
  String _successDetail(AppLocalizations i18n) {
    if (_useTor) return i18n.connectionReachedOverTor;
    if (_customProxyPortController.text.trim().isNotEmpty) return i18n.connectionReachedViaProxy;
    return i18n.connectionReachedDirect;
  }

  /// Maps this wrapper's flags onto the shared test-card state: starting-Tor
  /// takes over; then idle / testing / success / failure.
  ConnectionTestState _testState(TorMode torMode) {
    if (_useTor && torMode == TorMode.builtIn && _torStatus != TorConnectionStatus.connected) {
      return ConnectionTestState.startingTor;
    }
    if (!_hasTested) return ConnectionTestState.idle;
    if (_connectionTestIsLoading) return ConnectionTestState.testing;
    return _connectionSuccess ? ConnectionTestState.success : ConnectionTestState.failure;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final torMode = TorSettingsService.sharedInstance.torMode;
    final addressHint = _isNode ? i18n.connectionNodeAddressHint : i18n.lwsSetupAddressHint;

    final hasWorkingConnection = _hasTested && _connectionSuccess && !_connectionTestIsLoading;
    final connectionChanged =
        cleanConnectionAddress(_addressController.text) != _initialAddress ||
        _useTor != _initialUseTor ||
        _customProxyPortController.text != _initialProxyPort ||
        _connectionType != _initialConnectionType;
    final enablingSync =
        (_backgroundSyncEnabled && !_initialBackgroundSync) ||
        (_foregroundSyncEnabled && !_initialForegroundSync);
    final syncChanged =
        _backgroundSyncEnabled != _initialBackgroundSync ||
        _foregroundSyncEnabled != _initialForegroundSync;
    // Disabling sync alone needs no working connection; enabling it or editing
    // the connection does.
    final disablingSyncOnly = syncChanged && !enablingSync && !connectionChanged;
    final canSave = !_connectionTestIsLoading && (hasWorkingConnection || disablingSyncOnly);

    return ConnectionFormView(
      labels: ConnectionFormLabels(
        proxyPortLabel: i18n.lwsSetupProxyPortLabel,
        proxyPortHint: i18n.lwsSetupProxyPortHint,
        useTorLabel: i18n.lwsSetupUseTorLabel,
        startingTorTitle: i18n.lwsSetupStartingTor,
        testButton: i18n.lwsSetupTestConnectionButton,
        testStop: i18n.connectionTestStop,
        testingTitle: i18n.connectionTestingTitle,
        testingDetail: i18n.connectionTestingDetail,
        testAgain: i18n.connectionTestAgain,
        resultWorksTitle: i18n.connectionResultWorksTitle,
        resultFailedTitle: i18n.connectionResultFailedTitle,
        resultFailedDetail: i18n.connectionResultFailedDetail,
      ),
      addressLabel: i18n.address,
      addressHint: addressHint,
      addressController: _addressController,
      onAddressChanged: _onAddressChange,
      onScan: (Platform.isAndroid || Platform.isIOS) ? _scanQrCode : null,
      errorMessage: _errorMessage,
      proxyController: _customProxyPortController,
      onProxyChanged: _onProxyPortChange,
      proxyEnabled: !_useTor,
      connectionTypeLabels: [for (final t in connectionTypeOptions) _connectionTypeLabel(i18n, t)],
      selectedTypeIndex: connectionTypeOptions.indexOf(_connectionType),
      onSelectType: (i) => _setConnectionType(connectionTypeOptions[i]),
      useTor: _useTor,
      torDisabled: torMode == TorMode.disabled,
      onToggleTor: () => _setUseTor(!_useTor),
      pillProxyPort: _customProxyPortController.text,
      pillAddress: cleanConnectionAddress(_addressController.text),
      syncRows: _showSyncOptions
          ? [
              ConnectionSyncRow(
                label: i18n.settingsBackgroundSyncLabel,
                help: i18n.settingsBackgroundSyncDescription,
                checked: _backgroundSyncEnabled,
                onToggle: _setBackgroundSyncEnabled,
              ),
              ConnectionSyncRow(
                label: i18n.settingsForegroundSyncLabel,
                help: i18n.settingsForegroundSyncDescription,
                checked: _foregroundSyncEnabled,
                onToggle: _setForegroundSyncEnabled,
              ),
            ]
          : const [],
      testState: _testState(torMode),
      onTest: _testConnection,
      onStopTest: _stopTest,
      onTestAgain: _testConnection,
      successDetail: _successDetail(i18n),
      successLatency: _latencyMs != null ? '$_latencyMs ms' : null,
      saveButtonLabel: widget.saveButtonLabel,
      canSave: canSave,
      onSave: _saveConnection,
    );
  }
}
