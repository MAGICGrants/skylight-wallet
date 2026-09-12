import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/widgets/connection_settings_form.dart';
import 'package:skylight_wallet/widgets/fiat_api_settings_form.dart';
import 'package:skylight_wallet/widgets/tor_settings_form.dart';
import 'package:skylight_wallet/models/language_model.dart';
import 'package:skylight_wallet/models/theme_model.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/periodic_tasks.dart';
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/widgets/language_sheet.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:skylight_wallet/widgets/wallet_navigation_bar.dart';
import 'package:wallet_infra/wallet_infra.dart' show BiometricAuth, BiometricAuthResult;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _newTxNotificationsEnabled = false;
  var _appLockEnabled = false;
  var _verboseLoggingEnabled = false;
  FiatApiMode _fiatMode = FiatApiMode.torOnly;
  // Toggles animate only after the stored values have loaded, so they don't
  // slide from off→on when the screen first appears.
  var _animateToggles = false;
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadPackageInfo();
  }

  void _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  void _loadPreferences() async {
    final newTxNotificationsEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ??
        false;

    final appLockEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.appLockEnabled) ?? false;

    final verboseLoggingEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.verboseLoggingEnabled) ??
        false;

    final fiatMode = await FiatRateModel.loadFiatApiMode();

    if (!mounted) return;
    setState(() {
      _newTxNotificationsEnabled = newTxNotificationsEnabled;
      _appLockEnabled = appLockEnabled;
      _verboseLoggingEnabled = verboseLoggingEnabled;
      _fiatMode = fiatMode;
    });
    // Enable animation a frame after the loaded values are painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _animateToggles = true);
    });
  }

  void _setTxNotificationsEnabled(bool value) async {
    final wallet = appWalletOf(context);

    setState(() {
      _newTxNotificationsEnabled = value;
    });

    if (value) {
      final isAllowed = await NotificationService().promptPermission();

      if (isAllowed) {
        // Start from now, so switching this on doesn't announce the backlog of
        // everything already received.
        await wallet.markExistingTxsAsNotified();
        await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, true);
        await applyBackgroundTaskRegistration();
      }
    } else {
      await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, false);
      await applyBackgroundTaskRegistration();
    }
  }

  void _setAppLockEnabled(bool value) async {
    final i18n = AppLocalizations.of(context)!;

    if (value) {
      final result = await BiometricAuth.authenticate(reason: i18n.settingsAppLockUnlockReason);
      // Enabling app-lock is an explicit opt-in, so decline and error both report.
      if (result != BiometricAuthResult.authenticated) {
        if (mounted) {
          showBrandToast(context, i18n.settingsAppLockUnableToAuthError);
        }
        return;
      }
    }

    setState(() {
      _appLockEnabled = value;
    });

    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.appLockEnabled, value);
  }

  void _setVerboseLoggingEnabled(bool value) async {
    setState(() {
      _verboseLoggingEnabled = value;
    });

    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.verboseLoggingEnabled, value);
  }

  void _exportLogs() async {
    final i18n = AppLocalizations.of(context)!;

    try {
      final logFiles = await getLogFiles();

      if (logFiles.isEmpty) {
        if (mounted) {
          showBrandToast(context, i18n.settingsExportLogsError);
        }
        return;
      }

      if (mounted) {
        ExportLogsDialog.show(
          context,
          logFiles,
          ExportLogsLabels(
            title: i18n.settingsExportLogsLabel,
            cancel: i18n.cancel,
            exportError: i18n.settingsExportLogsError,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showBrandToast(context, i18n.settingsExportLogsError);
      }
    }
  }

  void _showDeleteWalletDialog() {
    final i18n = AppLocalizations.of(context)!;
    showConfirmSheet(
      context: context,
      icon: Icons.delete_outline,
      iconBg: BrandColors.errorBg,
      iconColor: BrandColors.error,
      title: i18n.settingsDeleteWalletButton,
      body: i18n.settingsDeleteWalletDialogText,
      confirmLabel: i18n.settingsDeleteWalletDialogDeleteButton,
      cancelLabel: i18n.cancel,
      onConfirm: _deleteWallet,
    );
  }

  void _showViewLwsKeysDialog() {
    final i18n = AppLocalizations.of(context)!;
    showConfirmSheet(
      context: context,
      icon: Icons.warning_amber_rounded,
      iconBg: BrandColors.warningBg,
      iconColor: BrandColors.warning,
      title: i18n.warning,
      body: i18n.settingsViewLwsKeysDialogText,
      confirmLabel: i18n.settingsViewLwsKeysDialogRevealButton,
      cancelLabel: i18n.cancel,
      confirmColor: BrandColors.warning,
      onConfirm: () => Navigator.pushNamed(context, '/lws_keys'),
    );
  }

  /// Gate the seed behind a device auth even though the app is already
  /// unlocked. Reaching this screen hands over the seed and secret spend key,
  /// which is total, irreversible control of the funds; the warning sheet alone
  /// stops nobody holding the phone.
  Future<void> _showViewSecretKeysDialog() async {
    final i18n = AppLocalizations.of(context)!;

    if (Platform.isAndroid || Platform.isIOS) {
      final result = await BiometricAuth.authenticate(reason: i18n.revealSeedAuthReason);
      if (result != BiometricAuthResult.authenticated) {
        if (mounted) {
          showBrandToast(context, i18n.settingsAppLockUnableToAuthError);
        }
        return;
      }
      if (!mounted) return;
    }

    showConfirmSheet(
      context: context,
      icon: Icons.warning_amber_rounded,
      iconBg: BrandColors.errorBg,
      iconColor: BrandColors.error,
      title: i18n.warning,
      body: i18n.settingsViewSecretKeysDialogText,
      confirmLabel: i18n.settingsViewSecretKeysDialogRevealButton,
      cancelLabel: i18n.cancel,
      onConfirm: () => Navigator.pushNamed(context, '/secret_keys'),
    );
  }

  Future<void> _deleteWallet() async {
    await deleteWallet(context);
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (Route<dynamic> route) => false);
    }
  }

  double _sheetMaxHeight(BuildContext sheetContext) {
    final media = MediaQuery.of(sheetContext);
    return (media.size.height - media.viewInsets.bottom) * 0.86;
  }

  /// Settings popup chrome, matching Spice's sheets: a handle, an icon + title
  /// header, then the form scrolling below (the form carries its own save
  /// button and pops on success).
  Future<void> _showSettingsSheet({
    required IconData icon,
    required String title,
    required Widget form,
  }) {
    return showBrandSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: _sheetMaxHeight(sheetContext)),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: Row(
                    children: [
                      SheetIcon(
                        icon: icon,
                        bg: BrandColors.surfaceTinted,
                        color: BrandColors.primaryDeep,
                      ),
                      const SizedBox(width: 11),
                      Expanded(child: Text(title, style: BrandText.sheetTitle)),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                    child: form,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTorSettings() async {
    final i18n = AppLocalizations.of(context)!;

    void onSaved() {
      appWalletOf(context).load();
      Provider.of<FiatRateModel>(context, listen: false).startService();
      Navigator.pop(context);
    }

    await _showSettingsSheet(
      icon: Icons.public,
      title: i18n.torSettingsTitle,
      form: TorSettingsForm(saveButtonLabel: i18n.torSettingsSaveButton, onSaved: onSaved),
    );
    // Disabling Tor can auto-disable a Tor-only fiat mode, so refresh both rows.
    if (mounted) await _refreshFiatMode();
  }

  void _showFiatApiSettings() async {
    final i18n = AppLocalizations.of(context)!;

    await _showSettingsSheet(
      icon: Icons.attach_money,
      title: i18n.settingsFiatApiSettingsLabel,
      form: FiatApiSettingsForm(
        saveButtonLabel: i18n.torSettingsSaveButton,
        onSaved: () async {
          await Provider.of<FiatRateModel>(context, listen: false).startService();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
    if (mounted) await _refreshFiatMode();
  }

  void _showConnectionSettings() async {
    final i18n = AppLocalizations.of(context)!;

    void onSaved() {
      // Rebuilds the wallet if the server kind (LWS↔node) changed, then resyncs.
      applyConnectionChange(context);
      Provider.of<FiatRateModel>(context, listen: false).startService();
      Navigator.pop(context);
    }

    await _showSettingsSheet(
      icon: Icons.dns,
      title: i18n.settingsConnectionSettingsLabel,
      form: ConnectionSettingsForm(
        saveButtonLabel: i18n.torSettingsSaveButton,
        onSaved: onSaved,
        isInDialog: true,
      ),
    );
    // The connection address subtitle follows the wallet, but the Tor mode row
    // reads a singleton — refresh so an edit here shows immediately.
    if (mounted) setState(() {});
  }

  Future<void> _refreshFiatMode() async {
    final mode = await FiatRateModel.loadFiatApiMode();
    if (mounted) setState(() => _fiatMode = mode);
  }

  String _torModeLabel(AppLocalizations i18n) =>
      switch (TorSettingsService.sharedInstance.torMode) {
        TorMode.builtIn => i18n.torSettingsModeBuiltIn,
        TorMode.external => i18n.torSettingsModeExternal,
        TorMode.disabled => i18n.torSettingsModeDisabled,
      };

  String _fiatModeLabel(AppLocalizations i18n) => switch (_fiatMode) {
    FiatApiMode.torOnly => i18n.fiatApiSettingsModeTorOnly,
    FiatApiMode.clearnet => i18n.fiatApiSettingsModeClearnet,
    FiatApiMode.disabled => i18n.fiatApiSettingsModeDisabled,
  };

  /// A plain-language description of the active connection, e.g. "LWS in Local
  /// Network" / "Node over Tor" / "Node over Clearnet". Null when unconfigured.
  /// Routing is classified like the connection pills (Tor / local / clearnet).
  String? _connectionSubtitle(AppWallet wallet, AppLocalizations i18n) {
    if (wallet.connectionAddress.isEmpty) return null;
    final server = wallet.isNodeMode
        ? i18n.settingsConnectionServerNode
        : i18n.settingsConnectionServerLws;
    final route = wallet.connectionUseTor
        ? i18n.settingsConnectionOverTor
        : addressIsLocal(wallet.connectionAddress)
        ? i18n.settingsConnectionInLocalNetwork
        : i18n.settingsConnectionOverClearnet;
    return '$server $route';
  }

  String _themeLabel(AppLocalizations i18n, String value) => switch (value) {
    'light' => i18n.settingsThemeLight,
    'dark' => i18n.settingsThemeDark,
    _ => i18n.settingsThemeSystem,
  };

  void _showThemePicker() {
    final i18n = AppLocalizations.of(context)!;
    final theme = context.read<ThemeModel>();
    showThemePickerSheet(
      context,
      labels: SettingsPickerLabels(
        title: i18n.settingsThemeLabel,
        subtitle: i18n.settingsThemeSheetSubtitle,
        done: i18n.done,
      ),
      options: [
        ThemePickerOption(
          value: 'light',
          label: i18n.settingsThemeLight,
          description: i18n.settingsThemeLightDesc,
          swatch: const ThemeSwatchSpec(
            ground: Color(0xFFF2F6FA),
            barColor: Color(0xFFB4CFE2),
            accentColor: Color(0xFFF5681C),
          ),
        ),
        ThemePickerOption(
          value: 'dark',
          label: i18n.settingsThemeDark,
          description: i18n.settingsThemeDarkDesc,
          swatch: const ThemeSwatchSpec(
            ground: Color(0xFF03090F),
            barColor: Color(0xFF1A2837),
            accentColor: Color(0xFFF2883C),
          ),
        ),
        ThemePickerOption(
          value: 'system',
          label: i18n.settingsThemeSystem,
          description: i18n.settingsThemeSystemDesc,
          swatch: const ThemeSwatchSpec(
            gradient: LinearGradient(
              colors: [Color(0xFFF2F6FA), Color(0xFF102A4C)],
              stops: [0.5, 0.5],
            ),
            barColor: Color(0xFF7E93AB),
            accentColor: Color(0xFFF5681C),
          ),
        ),
      ],
      selected: theme.theme,
      onSelect: theme.setTheme,
      iconBg: BrandColors.surfaceTinted,
      iconColor: BrandColors.primaryDeep,
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final language = context.watch<LanguageModel>();
    final theme = context.watch<ThemeModel>();
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final wallet = appWalletOf(context, listen: true);
    final fiatRate = context.watch<FiatRateModel>();
    final showNotifyToggle = Platform.isAndroid || (Platform.isIOS && !wallet.isNodeMode);
    final connectionSubtitle = _connectionSubtitle(wallet, i18n);
    final fiatSubtitle = _fiatMode == FiatApiMode.disabled
        ? _fiatModeLabel(i18n)
        : '${_fiatModeLabel(i18n)} · ${fiatRate.fiatCode}';

    return Scaffold(
      backgroundColor: BrandColors.paper,
      bottomNavigationBar: const WalletNavigationBar(selectedIndex: 2),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: BrandScreenHeader(
                    center: Text(
                      i18n.settingsTitle,
                      style: BrandText.appBar.copyWith(fontSize: 16),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsGroup(
                          label: i18n.settingsSectionGeneral,
                          tiles: [
                            SettingsNavTile(
                              title: i18n.settingsThemeLabel,
                              value: _themeLabel(i18n, theme.theme),
                              onTap: _showThemePicker,
                            ),
                            SettingsNavTile(
                              title: i18n.settingsLanguageLabel,
                              value:
                                  languageNames[language.language]?.$1 ??
                                  language.language.toUpperCase(),
                              onTap: () => showLanguageSheet(context),
                            ),
                            if (isMobile)
                              SettingsToggleTile(
                                title: i18n.settingsAppLockLabel,
                                value: _appLockEnabled,
                                onChanged: _setAppLockEnabled,
                                animate: _animateToggles,
                              ),
                            SettingsLinkTile(
                              title: i18n.settingsConnectionSettingsLabel,
                              subtitle: connectionSubtitle,
                              linkLabel: i18n.settingsLwsViewKeysButton,
                              onTap: _showConnectionSettings,
                            ),
                            SettingsLinkTile(
                              title: i18n.settingsTorSettingsLabel,
                              subtitle: _torModeLabel(i18n),
                              linkLabel: i18n.settingsLwsViewKeysButton,
                              onTap: _showTorSettings,
                            ),
                            SettingsLinkTile(
                              title: i18n.settingsFiatApiSettingsLabel,
                              subtitle: fiatSubtitle,
                              linkLabel: i18n.settingsLwsViewKeysButton,
                              onTap: _showFiatApiSettings,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SettingsGroup(
                          label: i18n.settingsSectionBehaviour,
                          tiles: [
                            if (showNotifyToggle)
                              SettingsToggleTile(
                                title: i18n.settingsNotifyNewTxsLabel,
                                description: Platform.isIOS
                                    ? i18n.settingsNotifyNewTxsDescriptionIos
                                    : i18n.settingsNotifyNewTxsDescription,
                                value: _newTxNotificationsEnabled,
                                onChanged: _setTxNotificationsEnabled,
                                animate: _animateToggles,
                              ),
                            SettingsToggleTile(
                              title: i18n.settingsVerboseLoggingLabel,
                              description: Platform.isIOS
                                  ? i18n.settingsVerboseLoggingDescriptionIos
                                  : i18n.settingsVerboseLoggingDescription,
                              value: _verboseLoggingEnabled,
                              onChanged: _setVerboseLoggingEnabled,
                              animate: _animateToggles,
                            ),
                            // Only meaningful with logs to export, so hide it when
                            // verbose logging is off rather than disabling it.
                            if (Platform.isIOS && _verboseLoggingEnabled)
                              SettingsLinkTile(
                                title: i18n.settingsExportLogsLabel,
                                linkLabel: i18n.settingsExportLogsButton,
                                onTap: _exportLogs,
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SettingsGroup(
                          label: i18n.settingsSectionWallet,
                          tiles: [
                            SettingsLinkTile(
                              title: i18n.settingsLwsViewKeysLabel,
                              titleColor: BrandColors.warning,
                              onTap: _showViewLwsKeysDialog,
                            ),
                            SettingsLinkTile(
                              title: i18n.settingsSecretKeysLabel,
                              titleColor: BrandColors.error,
                              onTap: _showViewSecretKeysDialog,
                            ),
                            SettingsLinkTile(
                              title: i18n.settingsDeleteWalletButton,
                              titleColor: BrandColors.error,
                              onTap: _showDeleteWalletDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SettingsGroup(
                          label: i18n.settingsSectionAbout,
                          tiles: [
                            SettingsNavTile(
                              title: i18n.welcomeTermsLink,
                              onTap: () => Navigator.pushNamed(context, '/terms_of_service'),
                            ),
                            SettingsNavTile(
                              title: i18n.welcomePrivacyLink,
                              onTap: () => Navigator.pushNamed(context, '/privacy_policy'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Skylight Wallet v$_appVersion (build $_buildNumber)',
                            style: BrandText.caption.copyWith(color: BrandColors.inkFaint),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
