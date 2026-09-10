import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/util/socks_http.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Shared form widget used by both TorSettingsScreen and the Tor settings dialog.
/// The three-way mode picker (Built-in / External / No Tor) renders as brand
/// [ModeSelectCard]s; External expands inline with its SOCKS port / Orbot /
/// connection-test controls.
class TorSettingsForm extends StatefulWidget {
  final String saveButtonLabel;
  final VoidCallback onSaved;

  const TorSettingsForm({super.key, required this.saveButtonLabel, required this.onSaved});

  @override
  State<TorSettingsForm> createState() => _TorSettingsFormState();
}

class _TorSettingsFormState extends State<TorSettingsForm> {
  TorMode _selectedMode = TorMode.builtIn;
  final TextEditingController _socksPortController = TextEditingController();
  bool _useOrbot = false;

  bool _isTestingConnection = false;
  bool _hasTested = false;
  bool _connectionSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final torSettings = TorSettingsService.sharedInstance;
    setState(() {
      _selectedMode = torSettings.torMode;
      _useOrbot = torSettings.useOrbot;
      _socksPortController.text = _useOrbot ? '9050' : torSettings.socksPort;
    });
  }

  Future<void> _saveSettings() async {
    final torSettings = TorSettingsService.sharedInstance;
    await torSettings.save(
      torMode: _selectedMode,
      socksPort: _socksPortController.text,
      useOrbot: _useOrbot,
    );
  }

  void _onSavePressed() async {
    // Read before the await: a Tor-only connection has to be told immediately
    // that its requirement can no longer be met, or it goes on presenting
    // itself as connected over Tor until something tries to reconnect.
    final wallet = appWalletOf(context);
    final previousMode = TorSettingsService.sharedInstance.torMode;
    final disablingTor = _selectedMode == TorMode.disabled && previousMode != TorMode.disabled;
    final enablingTor = _selectedMode != TorMode.disabled && previousMode == TorMode.disabled;

    // Warn before cutting Tor out from under a wallet connected over it. Cancel
    // leaves everything as-is; confirm marks the connection broken so nothing
    // reconnects until the user reconfigures it.
    if (disablingTor && wallet.usingTor) {
      final confirmed = await _confirmDisableTor();
      if (!confirmed) return;
      wallet.onGlobalTorDisabled();
    }

    var fiatChanged = false;

    // The fiat API can't reach Kraken over a Tor that's now off, so a Tor-only
    // fiat setting is turned off too (the setup form won't offer Tor again while
    // global Tor is disabled). Remember it was us, not the user, so re-enabling
    // Tor can restore it.
    if (disablingTor && await FiatRateModel.loadFiatApiMode() == FiatApiMode.torOnly) {
      await FiatRateModel.saveFiatApiMode(FiatApiMode.disabled);
      await SharedPreferencesService.set<bool>(SharedPreferencesKeys.fiatAutoDisabledByTor, true);
      fiatChanged = true;
    }

    // Turning Tor back on restores the fiat API to Tor mode, but only if we were
    // the ones who disabled it (a user who disabled it themselves keeps it off).
    if (enablingTor &&
        (await SharedPreferencesService.get<bool>(SharedPreferencesKeys.fiatAutoDisabledByTor) ??
            false)) {
      await FiatRateModel.saveFiatApiMode(FiatApiMode.torOnly);
      await SharedPreferencesService.remove(SharedPreferencesKeys.fiatAutoDisabledByTor);
      fiatChanged = true;
    }

    await _saveSettings();
    if (!mounted) return;
    if (fiatChanged) Provider.of<FiatRateModel>(context, listen: false).startService();
    widget.onSaved();
  }

  Future<bool> _confirmDisableTor() {
    final i18n = AppLocalizations.of(context)!;
    return showConfirmSheet(
      context: context,
      icon: Icons.warning_amber_rounded,
      iconBg: BrandColors.errorBg,
      iconColor: BrandColors.error,
      title: i18n.torDisabledWalletsWarningTitle,
      body: i18n.torDisabledWalletsWarningBody,
      confirmLabel: i18n.torDisabledWalletsWarningConfirm,
      cancelLabel: i18n.cancel,
    );
  }

  Future<void> _testConnection() async {
    if (_isTestingConnection) {
      return;
    }

    if (_selectedMode != TorMode.external) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _hasTested = true;
      _connectionSuccess = false;
    });

    try {
      final port = int.tryParse(_socksPortController.text) ?? 9050;
      final proxyInfo = (host: InternetAddress.loopbackIPv4, port: port);

      final response = await makeSocksHttpRequest(
        'GET',
        'https://check.torproject.org/api/ip',
        proxyInfo,
      ).timeout(Duration(seconds: 15));

      // Check if the response indicates we're connected through Tor
      final isTor = response.jsonBody != null && response.jsonBody['IsTor'] == true;

      setState(() {
        _connectionSuccess = response.statusCode == HttpStatus.ok && isTor;
      });
    } catch (e) {
      setState(() {
        _connectionSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  void _select(TorMode mode) {
    setState(() {
      _selectedMode = mode;
      _hasTested = false;
      _connectionSuccess = false;
    });
  }

  @override
  void dispose() {
    _socksPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    // External requires a passing test before it can be saved.
    final canSave =
        _selectedMode != TorMode.external ||
        (_connectionSuccess && _hasTested && !_isTestingConnection);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModeSelectCard(
          title: i18n.torSettingsModeBuiltIn,
          description: i18n.torChoiceBuiltInDesc,
          selected: _selectedMode == TorMode.builtIn,
          radioLeading: true,
          onTap: () => _select(TorMode.builtIn),
        ),
        const SizedBox(height: 9),
        ModeSelectCard(
          title: i18n.torSettingsModeExternal,
          description: i18n.torChoiceExternalDesc,
          selected: _selectedMode == TorMode.external,
          radioLeading: true,
          onTap: () => _select(TorMode.external),
          expanded: _externalFields(i18n, isMobile),
        ),
        const SizedBox(height: 9),
        ModeSelectCard(
          title: i18n.torSettingsModeDisabled,
          description: i18n.torChoiceNoTorDesc,
          selected: _selectedMode == TorMode.disabled,
          radioLeading: true,
          onTap: () => _select(TorMode.disabled),
        ),
        const SizedBox(height: BrandSpacing.lg),
        BrandButton(label: widget.saveButtonLabel, onPressed: canSave ? _onSavePressed : null),
      ],
    );
  }

  Widget _externalFields(AppLocalizations i18n, bool isMobile) {
    final portEnabled = !_useOrbot || !isMobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PortField(
          controller: _socksPortController,
          label: i18n.torSettingsSocksPortLabel,
          enabled: portEnabled,
          onChanged: () => setState(() {
            _hasTested = false;
            _connectionSuccess = false;
          }),
        ),
        if (isMobile)
          _OrbotCheck(
            value: _useOrbot,
            label: Platform.isIOS
                ? i18n.torSettingsUseOrbotLabelIos
                : i18n.torSettingsUseOrbotLabel,
            onChanged: (v) => setState(() {
              _useOrbot = v;
              if (v) _socksPortController.text = '9050';
              _hasTested = false;
              _connectionSuccess = false;
            }),
          ),
        const SizedBox(height: BrandSpacing.md),
        Row(
          children: [
            Expanded(child: _testStatus(i18n)),
            const SizedBox(width: BrandSpacing.md),
            _TestChip(
              label: i18n.torSettingsTestConnectionButton,
              onTap: _isTestingConnection ? null : _testConnection,
            ),
          ],
        ),
      ],
    );
  }

  Widget _testStatus(AppLocalizations i18n) {
    if (_isTestingConnection) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.primary),
        ),
      );
    }
    if (!_hasTested) return const SizedBox.shrink();
    if (_connectionSuccess) {
      return Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: BrandColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: BrandSpacing.sm),
          Text(
            i18n.torChoiceConnected,
            style: BrandText.caption.copyWith(
              color: BrandColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.error_outline, color: BrandColors.error, size: 18),
        const SizedBox(width: BrandSpacing.sm),
        Text(
          i18n.torChoiceTestFailed,
          style: BrandText.caption.copyWith(color: BrandColors.error, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Labeled inset field — a small-caps mono label above the value, per the
/// design (not a Material floating-label box).
class _PortField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final VoidCallback onChanged;

  const _PortField({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
      decoration: BoxDecoration(
        color: BrandColors.paper,
        borderRadius: BorderRadius.circular(BrandRadii.tile),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Ubuntu Mono',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: BrandColors.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 14, color: BrandColors.ink),
            cursorColor: BrandColors.primary,
            decoration: const InputDecoration.collapsed(hintText: '9050'),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

/// Small compact chip for the connection test action.
class _TestChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _TestChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: BrandColors.border),
    );
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: BrandColors.surfaceSunken,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: BrandColors.primaryDeep,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbotCheck extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  const _OrbotCheck({required this.value, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BrandSpacing.md),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? BrandColors.primary : BrandColors.card,
                borderRadius: BorderRadius.circular(6),
                border: value ? null : Border.all(color: BrandColors.inputBorder),
              ),
              child: value ? const Icon(Icons.check, size: 15, color: BrandColors.onPrimary) : null,
            ),
            const SizedBox(width: BrandSpacing.sm),
            Expanded(child: Text(label, style: BrandText.caption)),
          ],
        ),
      ),
    );
  }
}
