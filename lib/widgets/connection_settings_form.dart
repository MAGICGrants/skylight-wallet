import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/util/logging.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

const isDemoMode = String.fromEnvironment('DEMO_MODE') == 'true';

const connectionTypeOptions = ['lws', 'node'];

/// Drives the form's Save from outside — for the desktop onboarding footer,
/// whose Continue button sits beside Back rather than inside the form. Attach
/// with [ConnectionSettingsForm.controller]; [canSave] mirrors the internal
/// save gating and [save] triggers it.
class ConnectionFormController {
  _ConnectionSettingsFormState? _state;

  final ValueNotifier<bool> canSave = ValueNotifier(false);

  void save() => _state?._saveConnection();

  void _attach(_ConnectionSettingsFormState s) => _state = s;
  void _detach(_ConnectionSettingsFormState s) {
    if (_state == s) _state = null;
  }
}

/// Shared form widget used by both ConnectionSetupScreen and the connection settings dialog
class ConnectionSettingsForm extends StatefulWidget {
  final String saveButtonLabel;
  final VoidCallback onSaved;
  final bool isInDialog;
  final Future<void> Function()? onBeforeSave;

  /// Hide the built-in Save button and publish save state to [controller] — the
  /// host renders its own Save/Continue (desktop onboarding footer).
  final bool embedded;
  final ConnectionFormController? controller;

  const ConnectionSettingsForm({
    super.key,
    required this.saveButtonLabel,
    required this.onSaved,
    this.isInDialog = false,
    this.onBeforeSave,
    this.embedded = false,
    this.controller,
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
  TorConnectionStatus _torStatus = TorService.sharedInstance.status;
  Timer? _torStatusTimer;
  bool _testCancelled = false;
  int? _latencyMs;

  // The saved connection's raw Tor flag (before masking by the global Tor mode).
  // Used to warn when a Tor connection was silently turned off by disabling Tor.
  bool _savedConnectionUsedTor = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _loadPersistedConnection();
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _torStatusTimer?.cancel();
    _addressController.dispose();
    _customProxyPortController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedConnection() async {
    final wallet = appWalletOf(context);
    final conn = await wallet.getPersistedConnection();
    if (!mounted) return;

    final useTor = conn.useTor && TorSettingsService.sharedInstance.torMode != TorMode.disabled;
    final type = connectionTypeOptions.contains(conn.connectionType) ? conn.connectionType : 'lws';
    setState(() {
      _addressController.text = conn.address;
      _customProxyPortController.text = conn.proxyPort;
      _useTor = useTor;
      _savedConnectionUsedTor = conn.useTor;
      _connectionType = type;
    });

    if (conn.useTor && TorSettingsService.sharedInstance.torMode == TorMode.builtIn) {
      _pollTorStatus();
    }
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.pushNamed(context, '/scan_qr');
    if (!mounted) return;

    // Filled in exactly as if typed: the address rules run at Test and Save,
    // for a scanned address and a typed one alike.
    if (result != null && result is String) {
      final scannedAddress = cleanConnectionAddress(result);
      _addressController.text = scannedAddress;
      _onAddressChange(scannedAddress);
    }
  }

  void _onAddressChange(String rawValue) {
    final input = analyzeAddressInput(rawValue);
    final i18n = AppLocalizations.of(context)!;

    // Strip any typed http(s):// from the field itself so it's ignored.
    if (_addressController.text != input.cleaned) {
      _addressController.value = TextEditingValue(
        text: input.cleaned,
        selection: TextSelection.collapsed(offset: input.cleaned.length),
      );
    }

    // Never auto-disable Tor if the user already turned it on.
    _setUseTor(input.isOnion || _useTor);

    setState(() {
      _hasTested = false;
      _errorMessage = input.isRemoteIp ? i18n.connectionRemoteIpNotAllowed : null;
    });

    if (input.hadProtocol) {
      showBrandToast(context, switch (input.protocolHint) {
        AddressProtocolHint.onion => i18n.connectionProtocolHttpOnion,
        AddressProtocolHint.secure => i18n.connectionProtocolHttps,
        AddressProtocolHint.plain => i18n.connectionProtocolHttp,
      });
    }
  }

  void _onProxyPortChange(String value) {
    setState(() {
      _hasTested = false;
    });
  }

  void _setUseTor(bool? value) {
    if (value == true && TorSettingsService.sharedInstance.torMode == TorMode.disabled) {
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
    _loadConnectionForType(value);
  }

  /// Swaps the fields to the server saved for [type].
  ///
  /// Servers are stored per connection type, so selecting a mode selects that
  /// mode's server. Leaving the previous mode's address in the field is how an
  /// LWS connection could be saved pointing at a Monero node, which would hand
  /// the node the private view key.
  ///
  /// A mode with nothing saved clears the field rather than inheriting the other
  /// one's address. Switching mode clears the test, so Save waits for a new one.
  Future<void> _loadConnectionForType(String type) async {
    final wallet = appWalletOf(context);
    final conn = await wallet.getPersistedConnectionForType(type);
    // The user may have tapped another type while this was in flight.
    if (!mounted || _connectionType != type) return;

    final useTor = conn.useTor && TorSettingsService.sharedInstance.torMode != TorMode.disabled;
    setState(() {
      _addressController.text = conn.address;
      _customProxyPortController.text = conn.proxyPort;
      _useTor = useTor;
      _savedConnectionUsedTor = conn.useTor;
      _hasTested = false;
      _connectionSuccess = false;
      _errorMessage = null;
    });
  }

  String _connectionTypeLabel(AppLocalizations i18n, String type) {
    return type == 'node' ? i18n.connectionTypeNode : i18n.connectionTypeLws;
  }

  String _connectionAddressErrorMessage(AppLocalizations i18n, ConnectionAddressError error) =>
      switch (error) {
        ConnectionAddressError.remoteIp => i18n.connectionRemoteIpNotAllowed,
        ConnectionAddressError.pathNotSupported => i18n.connectionPathNotSupported,
        ConnectionAddressError.localOverTor => i18n.connectionLocalOverTorNotAllowed,
        ConnectionAddressError.onionNeedsTor => i18n.connectionOnionNeedsTor,
      };

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

  /// Whether this connection may carry a path after host:port (a server behind
  /// a reverse proxy at `/wallet`). The wallet decides: a node's client drops it.
  bool get _allowsPath => appWalletOf(context).connectionAllowsPath(_connectionType);

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

    final addrError = validateConnectionAddress(
      address: daemonAddress,
      useTor: _useTor,
      hasProxy: _customProxyPortController.text.trim().isNotEmpty,
      allowPath: _allowsPath,
    );
    if (addrError != null) {
      setState(() {
        _hasTested = false;
        _errorMessage = _connectionAddressErrorMessage(i18n, addrError);
      });
      return;
    }

    if (_useTor && TorSettingsService.sharedInstance.torMode == TorMode.disabled) {
      showBrandToast(context, i18n.lwsSetupTorDisabledError);
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

    final addrError = validateConnectionAddress(
      address: daemonAddress,
      useTor: _useTor,
      hasProxy: proxyAddress.trim().isNotEmpty,
      allowPath: _allowsPath,
    );
    if (addrError != null) {
      setState(() => _errorMessage = _connectionAddressErrorMessage(i18n, addrError));
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
    final addressHint = appWalletOf(context).connectionAddressExampleForType(_connectionType);

    final hasWorkingConnection = _hasTested && _connectionSuccess && !_connectionTestIsLoading;
    final canSave = !_connectionTestIsLoading && hasWorkingConnection;

    // Publish save state for an external Continue button (embedded mode).
    final controller = widget.controller;
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.canSave.value = canSave;
      });
    }

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
      // The saved connection used Tor, which is now disabled: prompt to reconfigure.
      warning: (_savedConnectionUsedTor && torMode == TorMode.disabled)
          ? i18n.connectionTorDisabledWarning
          : null,
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
      testState: _testState(torMode),
      onTest: _testConnection,
      onStopTest: _stopTest,
      onTestAgain: _testConnection,
      successDetail: _successDetail(i18n),
      successLatency: _latencyMs != null ? '$_latencyMs ms' : null,
      saveButtonLabel: widget.saveButtonLabel,
      canSave: canSave,
      onSave: _saveConnection,
      showSave: !widget.embedded,
    );
  }
}
