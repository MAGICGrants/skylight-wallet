import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/periodic_tasks.dart' show applyBackgroundTaskRegistration;
import 'package:skylight_wallet/screens/desktop/home_shell.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/screens/verify_seed.dart';
import 'package:skylight_wallet/widgets/home_labels.dart';
import 'package:skylight_wallet/widgets/privacy_settings_sheets.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:skylight_wallet/widgets/wallet_navigation_bar.dart';
import 'package:wallet_monero/wallet_monero.dart' show LwsPendingApproval;
import 'package:wallet_backup_platform/wallet_backup_platform.dart' show MetadataBackupSetup;
import 'package:wallet_domain/wallet_domain.dart' show CryptoWallet, SeedStore;
import 'package:wallet_fhse/security_keys_ui.dart' show securityKeysOn;
import 'package:wallet_infra/wallet_infra.dart' show StoreReview;

/// Monero is decimal-12; cap the displayed coin amount for legibility.
String _amountText(double amount) => amount.toStringAsFixed(5);

/// The resolved LWS connection state, driving the disconnected indicator.
enum StatusIconStatus { loading, complete, fail }

/// The balance/connection values the home renders, derived once and shared by
/// the mobile and desktop layouts.
typedef _HomeValues = ({
  double unlockedBalance,
  double? unlockedBalanceFiat,
  StatusIconStatus status,
  bool disconnected,
});

_HomeValues _deriveHome(AppWallet wallet, FiatRateModel fiatRate) {
  final unlockedBalance = wallet.unlockedBalance ?? 0;
  final unlockedBalanceFiat = fiatRate.rateFor('XMR') is double && wallet.unlockedBalance is double
      ? wallet.unlockedBalance! * fiatRate.rateFor('XMR')!
      : null;

  var status = StatusIconStatus.fail;
  if (wallet.isFullySynced) {
    status = StatusIconStatus.complete;
  } else if (wallet.usingTor &&
          TorService.sharedInstance.status == TorConnectionStatus.connecting ||
      !wallet.hasAttemptedConnection ||
      wallet.isConnected && !wallet.isSynced ||
      wallet.isConnected && wallet.isSynced && (wallet.syncedHeight ?? 0) == 0) {
    status = StatusIconStatus.loading;
  }

  return (
    unlockedBalance: unlockedBalance,
    unlockedBalanceFiat: unlockedBalanceFiat,
    status: status,
    disconnected: wallet.torRequirementBroken || status == StatusIconStatus.fail,
  );
}

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> with WidgetsBindingObserver {
  late final SecurityChecklist _checklist = SecurityChecklist(
    autoBackupOn: MetadataBackupSetup.automaticBackupOn,
    securityKeysOn: securityKeysOn,
    canVerifySeed: _canVerifySeed,
  );
  bool? _seedAskable;

  // The seed check asks for the words as kept since the wallet was made, or,
  // for an older wallet, its polyseed. Worked out once per visit.
  Future<bool> _canVerifySeed() async {
    final known = _seedAskable;
    if (known != null) return known;
    var askable = await SeedStore.exists();
    if (!askable && mounted) {
      askable = (await appWalletOf(context).readPolyseed()).isNotEmpty;
    }
    return _seedAskable = askable;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checklist.addListener(_onChecklistChanged);
    _checklist.refresh();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Here a wallet exists and its connection is applied: the first time
      // after onboarding, and after every unlock. Updates the tasks in place.
      unawaited(applyBackgroundTaskRegistration());

      final Map<String, dynamic>? args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null && args['showTxSuccessToast'] == true) {
        _showTxSuccessToast();
      }

      // Opening the app after a send is when a store review is asked for;
      // StoreReview decides whether one is due, once per launch.
      unawaited(StoreReview.requestIfDue(stillAppropriate: _stillOnHome));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checklist.removeListener(_onChecklistChanged);
    _checklist.dispose();
    super.dispose();
  }

  // A setting may have changed in the system settings (iCloud) meanwhile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checklist.refresh();
  }

  void _onChecklistChanged() {
    if (mounted) setState(() {});
  }

  // Still the screen in front, with the app in the foreground: the review
  // dialog must not land on a send or receive the user has already opened.
  bool _stillOnHome() =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void _showTxSuccessToast() {
    final i18n = AppLocalizations.of(context)!;

    showBrandToast(context, i18n.sendTransactionSuccessfullySent);
  }

  Future<void> _openStep(SecurityStep step) => switch (step) {
    SecurityStep.verifySeed =>
      isDesktop ? showVerifySeedSheet(context) : Navigator.pushNamed(context, '/verify_seed'),
    SecurityStep.autoBackup => Navigator.pushNamed(context, '/metadata_backup'),
    SecurityStep.tor => showTorSettingsSheet(context),
    SecurityStep.privateLookups => showPrivateLookupSheets(context),
    SecurityStep.securityKeys => Navigator.pushNamed(context, '/advanced_security'),
  };

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = appWalletOf(context, listen: true);
    final fiatRate = context.watch<FiatRateModel>();
    final v = _deriveHome(wallet, fiatRate);

    // The engine wallet, not the app adapter: the shared cards read its
    // exact history and balances.
    final cw = xmrWallet(context)!;
    final coins = <HomeCoin>[(wallet: cw, tokens: const <CryptoWallet>[])];
    final sections = HomeSections(activity: HomeActivity.shared, labels: homeLabels(i18n));
    final configured = cw.connectionAddress.isNotEmpty;
    Widget hero(Widget? footer) => HomeBalanceHero(
      fiatRate: fiatRate,
      fiatTotal: v.unlockedBalanceFiat,
      coinText: '${_amountText(v.unlockedBalance)} XMR',
      fiatErrorTooltip: i18n.homeFiatApiError,
      footer: footer,
    );
    void receive() => Navigator.pushNamed(context, '/receive');
    void send() => Navigator.pushNamed(context, '/send');
    void swap() => showBrandToast(context, i18n.coinHomeSwapComingSoon);
    final incoming = sections.incoming(coins);
    final chart = sections.chart(coins);
    // The server still waiting to approve this wallet, said where it matters.
    final notice = switch (wallet.lwsPendingApproval) {
      null => null,
      LwsPendingApproval.account => WarningCallout(i18n.lwsAwaitingApprovalAccount),
      LwsPendingApproval.restoreHeight => WarningCallout(i18n.lwsAwaitingApprovalRestoreHeight),
    };
    final checklist = securityChecklistCard(
      checklist: _checklist,
      labels: securityChecklistLabels(i18n),
      onStep: _openStep,
    );

    if (isDesktop) {
      return DesktopShell(
        active: DesktopNav.home,
        child: DesktopHomeLayout(
          status: configured
              ? _SyncStatusPill(status: v.status, blocksRemaining: wallet.syncBlocksRemaining)
              : null,
          balance: hero(configured ? ConnectionPills(wallet: cw) : null),
          actions: DesktopHomeActions(
            receiveLabel: i18n.homeReceive,
            sendLabel: i18n.homeSend,
            swapLabel: i18n.coinHomeSwap,
            onReceive: receive,
            onSend: send,
            onSwap: swap,
          ),
          wide: [?notice, ?incoming, chart],
          side: checklist,
        ),
      );
    }

    return WalletHomeView(
      header: HomeHeader(
        logo: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SvgPicture.asset('assets/logo.svg', width: 30, height: 30),
        ),
        title: 'Skylight Wallet',
      ),
      notice: notice,
      balance: hero(_ConnectionRow(wallet: wallet, disconnected: v.disconnected)),
      actions: HomeActionRow(
        receiveLabel: i18n.homeReceive,
        sendLabel: i18n.homeSend,
        swapLabel: i18n.coinHomeSwap,
        onReceive: receive,
        onSend: send,
        onSwap: swap,
      ),
      incoming: incoming,
      chart: chart,
      checklist: checklist,
      bottomNavigationBar: WalletNavigationBar(selectedIndex: 0),
    );
  }
}

/// The connection info row: transport/kind pills. While syncing the pills
/// compact to icons with "x blocks left" beside them; when the connection has
/// failed, the same slot shows "Disconnected" in red. Sits under the mobile
/// home's balance.
class _ConnectionRow extends StatelessWidget {
  final AppWallet wallet;
  final bool disconnected;

  const _ConnectionRow({required this.wallet, required this.disconnected});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final cw = xmrWallet(context);
    if (cw == null || cw.connectionAddress.isEmpty) return const SizedBox.shrink();
    final blocks = wallet.syncBlocksRemaining;
    final trailing = blocks != null
        ? i18n.homeBlocksRemaining(blocks)
        : disconnected
        ? i18n.homeDisconnected
        : null;
    if (trailing == null) return ConnectionPills(wallet: cw);
    return Row(
      children: [
        ConnectionPills(wallet: cw, compact: true),
        const SizedBox(width: 10),
        Container(width: 1, height: 14, color: BrandColors.borderStrong),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            trailing,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Ubuntu Mono',
              fontSize: 13,
              height: 1,
              color: disconnected ? BrandColors.error : BrandColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Desktop sync-status pill: a coloured dot + Synced / Syncing (blocks left) /
/// Disconnected, mirroring Spice's coin-home status pill.
class _SyncStatusPill extends StatelessWidget {
  final StatusIconStatus status;
  final int? blocksRemaining;

  const _SyncStatusPill({required this.status, required this.blocksRemaining});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final blocks = blocksRemaining;
    final (Color dot, String text) = switch (status) {
      StatusIconStatus.complete => (BrandColors.success, i18n.homeSynced),
      StatusIconStatus.loading => (
        BrandColors.warning,
        blocks != null ? i18n.homeBlocksRemaining(blocks) : i18n.homeSyncing,
      ),
      StatusIconStatus.fail => (BrandColors.error, i18n.homeDisconnected),
    };
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.surfaceSunken,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Ubuntu',
              fontSize: 12.5,
              height: 1,
              color: BrandColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
