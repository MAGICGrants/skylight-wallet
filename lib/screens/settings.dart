import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/models/contact_model.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/widgets/connection_settings_form.dart';
import 'package:skylight_wallet/models/language_model.dart';
import 'package:skylight_wallet/models/theme_model.dart';
import 'package:skylight_wallet/screens/lws_keys.dart';
import 'package:skylight_wallet/screens/secret_keys.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:wallet_backup_platform/backup_ui.dart' show BackupLocalizations;
import 'package:wallet_fhse/security_keys_ui.dart'
    show AppLockTile, DesktopAutoLockTile, FhseLocalizations, SecurityKeysState, securityKeysState;
import 'package:wallet_domain/wallet_domain.dart' show OpenAliasMode;
import 'package:wallet_fhse/wallet_fhse.dart' show SecurityKeyService;
import 'package:wallet_infra/wallet_infra.dart' show SyncFrequency, loadSyncFrequency;
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/widgets/language_sheet.dart';
import 'package:skylight_wallet/widgets/privacy_settings_sheets.dart';
import 'package:skylight_wallet/widgets/sync_frequency_sheet.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:skylight_wallet/widgets/wallet_navigation_bar.dart';

/// Desktop: settings as a wide centered modal (opened from the sidebar); mobile
/// keeps the full-screen tab.
Future<void> showSettingsSheet(BuildContext context) {
  return showBrandSheet<void>(
    context: context,
    isScrollControlled: true,
    maxWidth: 720,
    builder: (ctx) => ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 640),
      child: const SettingsScreen(asModal: true),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  /// Content-only render for the desktop settings modal (2-column, no shell).
  final bool asModal;

  const SettingsScreen({super.key, this.asModal = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _newTxNotificationsEnabled = false;
  var _syncFrequency = SyncFrequency.periodic;
  var _loggingEnabled = false;
  SecurityKeysState? _securityKeys;
  FiatApiMode _fiatMode = FiatApiMode.torOnly;
  OpenAliasMode _openAliasMode = OpenAliasMode.torOnly;
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
    if (!mounted) return;
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  void _loadPreferences() async {
    final newTxNotificationsEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ??
        false;

    final loggingEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.loggingEnabled) ?? false;

    final fiatMode = await FiatRateModel.loadFiatApiMode();
    final openAliasMode = await OpenAliasMode.load();
    final syncFrequency = await loadSyncFrequency();
    await _loadSecurityKeys();

    if (!mounted) return;
    setState(() {
      _newTxNotificationsEnabled = newTxNotificationsEnabled;
      _loggingEnabled = loggingEnabled;
      _fiatMode = fiatMode;
      _openAliasMode = openAliasMode;
      _syncFrequency = syncFrequency;
    });
    // Enable animation a frame after the loaded values are painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _animateToggles = true);
    });
  }

  /// Only whether a background run that finds a payment says so. Whether runs
  /// happen at all is Sync Frequency's.
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
      }
    } else {
      await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, false);
    }
  }

  void _showSyncFrequency() async {
    final frequency = await showSyncFrequencySettings(context);
    if (frequency != null && mounted) setState(() => _syncFrequency = frequency);
  }

  Future<void> _loadSecurityKeys() async {
    if (!SecurityKeyService.isSupportedPlatform) return;
    try {
      final state = await securityKeysState();
      if (mounted) setState(() => _securityKeys = state);
    } catch (_) {
      // Advanced Security says what went wrong; the rest of Settings loads.
    }
  }

  Future<void> _openAdvancedSecurity() async {
    await Navigator.pushNamed(context, '/advanced_security');
    await _loadSecurityKeys();
  }

  String _securityKeysValue(FhseLocalizations i18n) {
    final state = _securityKeys;
    if (state == null || !state.engaged) return i18n.advancedSecurityOff;
    if (state.unreadable) return i18n.advancedSecurityNeedsAttention;
    return i18n.advancedSecurityKeyCount(state.keys.length);
  }

  void _setLoggingEnabled(bool value) async {
    setState(() {
      _loggingEnabled = value;
    });

    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.loggingEnabled, value);
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
            exportError: i18n.settingsExportLogsFailed,
          ),
        );
      }
    } catch (e) {
      // Not "no logs found": the listing itself failed, which is a different
      // thing to tell the user than an empty list.
      if (mounted) {
        showBrandToast(context, i18n.settingsExportLogsFailed);
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

  void _showDeleteAddressBookDialog() {
    final i18n = AppLocalizations.of(context)!;
    showConfirmSheet(
      context: context,
      icon: Icons.delete_outline,
      iconBg: BrandColors.errorBg,
      iconColor: BrandColors.error,
      title: i18n.settingsDeleteAddressBookButton,
      body: i18n.settingsDeleteAddressBookDialogText,
      confirmLabel: i18n.settingsDeleteAddressBookDialogDeleteButton,
      cancelLabel: i18n.cancel,
      onConfirm: _deleteAddressBook,
    );
  }

  // Only the address book: deleting the wallet keeps it, and this keeps the
  // wallet. A backup syncing to iCloud or Android backup records the deletions.
  Future<void> _deleteAddressBook() async {
    final i18n = AppLocalizations.of(context)!;
    await Provider.of<ContactModel>(context, listen: false).deleteAll();
    if (mounted) showBrandToast(context, i18n.settingsAddressBookDeleted);
  }

  Future<void> _showViewLwsKeysDialog() async {
    final i18n = AppLocalizations.of(context)!;
    final ok = await showConfirmSheet(
      context: context,
      icon: Icons.warning_amber_rounded,
      iconBg: BrandColors.warningBg,
      iconColor: BrandColors.warning,
      title: i18n.warning,
      body: i18n.settingsViewLwsKeysDialogText,
      confirmLabel: i18n.settingsViewLwsKeysDialogRevealButton,
      cancelLabel: i18n.cancel,
      confirmColor: BrandColors.warning,
    );
    if (ok != true || !mounted) return;
    if (isDesktop) {
      await showLwsKeysSheet(context);
    } else {
      await Navigator.pushNamed(context, '/lws_keys');
    }
  }

  /// The recovery phrase and secret spend key are total, irreversible control of
  /// the funds, so the warning alone is not enough: the screen (or desktop
  /// sheet) needs a passing App Lock, asked again even though the app is
  /// already unlocked (`/secret_keys` is an AppLockGate route;
  /// [showSecretKeysSheet] asks itself).
  Future<void> _showViewSecretKeysDialog() async {
    final i18n = AppLocalizations.of(context)!;

    final ok = await showConfirmSheet(
      context: context,
      icon: Icons.warning_amber_rounded,
      iconBg: BrandColors.errorBg,
      iconColor: BrandColors.error,
      title: i18n.warning,
      body: i18n.settingsViewSecretKeysDialogText,
      confirmLabel: i18n.settingsViewSecretKeysDialogRevealButton,
      cancelLabel: i18n.cancel,
    );
    if (ok != true || !mounted) return;
    if (isDesktop) {
      await showSecretKeysSheet(context);
    } else {
      await Navigator.pushNamed(context, '/secret_keys');
    }
  }

  Future<void> _deleteWallet() async {
    await deleteWallet(context);
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (Route<dynamic> route) => false);
    }
  }

  Future<void> _showTorSettings() async {
    await showTorSettingsSheet(context);
    // Disabling Tor can auto-disable a Tor-only fiat mode, so refresh both rows.
    if (mounted) await _refreshFiatMode();
  }

  Future<void> _showFiatApiSettings() async {
    await showFiatApiSettingsSheet(context);
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

    await showSettingsFormSheet(
      context,
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

  Future<void> _showOpenAliasSettings() async {
    final changed = await showOpenAliasSheet(context);
    if (changed == true) {
      final mode = await OpenAliasMode.load();
      if (mounted) setState(() => _openAliasMode = mode);
    }
  }

  String _openAliasModeLabel(AppLocalizations i18n) => switch (_openAliasMode) {
    OpenAliasMode.torOnly => i18n.fiatApiSettingsModeTorOnly,
    OpenAliasMode.clearnet => i18n.fiatApiSettingsModeClearnet,
    OpenAliasMode.disabled => i18n.fiatApiSettingsModeDisabled,
  };

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
    final wallet = appWalletOf(context, listen: true);
    final fiatRate = context.watch<FiatRateModel>();
    // Sync Frequency and the notifications it feeds: phones only.
    final showNotifyToggle = Platform.isAndroid || Platform.isIOS;
    final connectionSubtitle = _connectionSubtitle(wallet, i18n);
    final fiatSubtitle = _fiatMode == FiatApiMode.disabled
        ? _fiatModeLabel(i18n)
        : '${_fiatModeLabel(i18n)} · ${fiatRate.fiatCode}';

    final groups = <Widget>[
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
            value: languageNames[language.language]?.$1 ?? language.language.toUpperCase(),
            onTap: () => showLanguageSheet(context),
          ),
          SettingsLinkTile(
            title: i18n.settingsConnectionSettingsLabel,
            subtitle: connectionSubtitle,
            linkLabel: i18n.settingsLwsViewKeysButton,
            onTap: _showConnectionSettings,
          ),
          SettingsLinkTile(
            title: i18n.settingsFiatApiSettingsLabel,
            subtitle: fiatSubtitle,
            linkLabel: i18n.settingsLwsViewKeysButton,
            onTap: _showFiatApiSettings,
          ),
        ],
      ),
      SettingsGroup(
        label: i18n.settingsSectionSecurityPrivacy,
        tiles: [
          // Always on: how long the app may be away before it asks again.
          const AppLockTile(),
          if (isDesktopOS) const DesktopAutoLockTile(),
          if (SecurityKeyService.isSupportedPlatform)
            SettingsNavTile(
              title: FhseLocalizations.of(context).advancedSecurityLabel,
              value: _securityKeysValue(FhseLocalizations.of(context)),
              onTap: _openAdvancedSecurity,
            ),
          SettingsLinkTile(
            title: i18n.settingsTorSettingsLabel,
            subtitle: _torModeLabel(i18n),
            linkLabel: i18n.settingsLwsViewKeysButton,
            onTap: _showTorSettings,
          ),
          SettingsLinkTile(
            title: i18n.settingsOpenAliasSettingsLabel,
            subtitle: _openAliasModeLabel(i18n),
            linkLabel: i18n.settingsLwsViewKeysButton,
            onTap: _showOpenAliasSettings,
          ),
        ],
      ),
      SettingsGroup(
        label: i18n.settingsSectionData,
        tiles: [
          SettingsNavTile(
            title: BackupLocalizations.of(context).backupTitle,
            onTap: () => Navigator.pushNamed(context, '/metadata_backup'),
          ),
          SettingsToggleTile(
            title: i18n.settingsLoggingLabel,
            description: Platform.isIOS
                ? i18n.settingsLoggingDescriptionIos
                : i18n.settingsLoggingDescription,
            value: _loggingEnabled,
            onChanged: _setLoggingEnabled,
            animate: _animateToggles,
          ),
          // Only meaningful with logs to export, so hide it when
          // logging is off rather than disabling it.
          if (Platform.isIOS && _loggingEnabled)
            SettingsLinkTile(
              title: i18n.settingsExportLogsLabel,
              linkLabel: i18n.settingsExportLogsButton,
              onTap: _exportLogs,
            ),
          SettingsLinkTile(
            title: i18n.settingsDeleteAddressBookButton,
            titleColor: BrandColors.error,
            onTap: _showDeleteAddressBookDialog,
          ),
        ],
      ),
      if (showNotifyToggle)
        SettingsGroup(
          label: i18n.settingsSectionBehaviour,
          tiles: [
            SettingsNavTile(
              title: i18n.settingsSyncFrequencyLabel,
              value: syncFrequencyLabels(i18n).nameOf(_syncFrequency),
              onTap: _showSyncFrequency,
            ),
            SettingsToggleTile(
              title: i18n.settingsNotifyNewTxsLabel,
              description: i18n.settingsNotifyNewTxsDescription,
              value: _newTxNotificationsEnabled,
              onChanged: _setTxNotificationsEnabled,
              animate: _animateToggles,
            ),
          ],
        ),
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
      SettingsGroup(
        label: i18n.settingsSectionAbout,
        tiles: [
          SettingsNavTile(
            title: i18n.welcomeTermsLink,
            onTap: () => Navigator.pushNamed(context, '/terms_of_service', arguments: true),
          ),
          SettingsNavTile(
            title: i18n.welcomePrivacyLink,
            onTap: () => Navigator.pushNamed(context, '/privacy_policy', arguments: true),
          ),
          SettingsNavTile(
            title: i18n.settingsLicensesLabel,
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Skylight Wallet',
              applicationVersion: _appVersion,
            ),
          ),
        ],
      ),
    ];

    final versionFooter = Center(
      child: Text(
        'Skylight Wallet v$_appVersion (build $_buildNumber)',
        style: BrandText.caption.copyWith(color: BrandColors.inkFaint),
      ),
    );

    if (widget.asModal) return _modalBody(i18n, groups, versionFooter);

    final tiles = <Widget>[
      for (var i = 0; i < groups.length; i++) ...[if (i > 0) const SizedBox(height: 18), groups[i]],
      const SizedBox(height: 16),
      versionFooter,
    ];

    return Scaffold(
      backgroundColor: BrandColors.paper,
      bottomNavigationBar: const WalletNavigationBar(selectedIndex: 3),
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: tiles),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The desktop settings modal: a header + a two-column body of the groups that
  /// wraps to one column when the modal is narrow (design: 720px, 2 columns).
  Widget _modalBody(AppLocalizations i18n, List<Widget> groups, Widget versionFooter) {
    final hpad = isDesktopModal ? 0.0 : 20.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hpad, 2, isDesktopModal ? 34 : hpad, 18),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BrandColors.surfaceTinted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune, size: 19, color: BrandColors.primary),
              ),
              const SizedBox(width: 13),
              Text(
                i18n.settingsTitle,
                style: TextStyle(
                  fontFamily: 'Ubuntu',
                  fontSize: 21,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.ink,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hpad, 0, hpad, 2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 20.0;
                Widget stack(List<Widget> gs, {Widget? tail}) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < gs.length; i++) ...[
                      if (i > 0) const SizedBox(height: gap),
                      gs[i],
                    ],
                    if (tail != null) ...[const SizedBox(height: gap), tail],
                  ],
                );
                if (constraints.maxWidth >= 520) {
                  final half = (groups.length / 2).ceil();
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: stack(groups.sublist(0, half))),
                      const SizedBox(width: 22),
                      Expanded(child: stack(groups.sublist(half), tail: versionFooter)),
                    ],
                  );
                }
                return stack(groups, tail: versionFooter);
              },
            ),
          ),
        ),
      ],
    );
  }
}
