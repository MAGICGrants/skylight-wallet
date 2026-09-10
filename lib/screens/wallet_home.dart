import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/status_icon.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:skylight_wallet/widgets/wallet_navigation_bar.dart';
import 'package:wallet_domain/wallet_domain.dart' show TxDetails;

/// The balance hero's big number style, mirroring Spice's `coin_home.dart`.
TextStyle get _balanceStyle => TextStyle(
  fontFamily: 'Ubuntu Mono',
  fontSize: 33,
  height: 1,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.66,
  color: BrandColors.ink,
  fontFeatures: const [FontFeature.tabularFigures()],
);

TextStyle get _balanceSubStyle =>
    TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 13.5, height: 1, color: BrandColors.inkMuted);

/// Monero is decimal-12; cap the displayed coin amount for legibility.
String _amountText(double amount) => amount.toStringAsFixed(5);

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final Map<String, dynamic>? args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null && args['showTxSuccessToast'] == true) {
        _showTxSuccessToast();
      }
    });
  }

  void _showTxDetails(TxDetails txDetails) {
    showTxDetailsDialog(context, txDetails);
  }

  void _showTxSuccessToast() {
    final i18n = AppLocalizations.of(context)!;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(i18n.sendTransactionSuccessfullySent)));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = appWalletOf(context, listen: true);
    final fiatRate = context.watch<FiatRateModel>();

    final unlockedBalance = wallet.unlockedBalance ?? 0;
    final unlockedBalanceFiat =
        fiatRate.rateFor('XMR') is double && wallet.unlockedBalance is double
        ? wallet.unlockedBalance! * fiatRate.rateFor('XMR')!
        : null;
    final lockedBalance = (wallet.totalBalance ?? 0) - (wallet.unlockedBalance ?? 0);
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';

    var lwsConnectionIconStatus = StatusIconStatus.fail;
    if (wallet.isFullySynced) {
      lwsConnectionIconStatus = StatusIconStatus.complete;
    } else if (wallet.usingTor &&
            TorService.sharedInstance.status == TorConnectionStatus.connecting ||
        !wallet.hasAttemptedConnection ||
        wallet.isConnected && !wallet.isSynced ||
        wallet.isConnected && wallet.isSynced && (wallet.syncedHeight ?? 0) == 0) {
      lwsConnectionIconStatus = StatusIconStatus.loading;
    }

    return Scaffold(
      backgroundColor: BrandColors.paper,
      bottomNavigationBar: WalletNavigationBar(selectedIndex: 0),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BalanceHero(
                              wallet: wallet,
                              unlockedBalance: unlockedBalance,
                              unlockedBalanceFiat: unlockedBalanceFiat,
                              lockedBalance: lockedBalance,
                              fiatSymbol: fiatSymbol,
                              fiatRate: fiatRate,
                              disconnected:
                                  wallet.torRequirementBroken ||
                                  lwsConnectionIconStatus == StatusIconStatus.fail,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                              child: _ActionRow(
                                onReceive: () => Navigator.pushNamed(context, '/receive'),
                                onSend: () => Navigator.pushNamed(context, '/send'),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                              child: SectionHeader(
                                label: i18n.coinHomeActivityTitle,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ActivitySliver(
                        wallet: wallet,
                        i18n: i18n,
                        fiatRate: fiatRate,
                        fiatSymbol: fiatSymbol,
                        onTapTx: _showTxDetails,
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 2),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SvgPicture.asset('assets/logo.svg', width: 26, height: 26),
          ),
          const SizedBox(width: 9),
          Text(
            'Skylight Wallet',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 17,
              height: 1,
              color: BrandColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  final AppWallet wallet;
  final double unlockedBalance;
  final double? unlockedBalanceFiat;
  final double lockedBalance;
  final String fiatSymbol;
  final FiatRateModel fiatRate;
  final bool disconnected;

  const _BalanceHero({
    required this.wallet,
    required this.unlockedBalance,
    required this.unlockedBalanceFiat,
    required this.lockedBalance,
    required this.fiatSymbol,
    required this.fiatRate,
    required this.disconnected,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final showFiat = !fiatRate.isDisabled && unlockedBalanceFiat != null;
    final coinText = '${_amountText(unlockedBalance)} XMR';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fiat leads when available; otherwise the coin amount is the hero,
          // with a skeleton while the rate is still loading.
          if (showFiat)
            BalanceText.split(formatFiat(unlockedBalanceFiat!, fiatSymbol), style: _balanceStyle)
          else if (!fiatRate.isDisabled && !fiatRate.hasFailed)
            Skeletonizer(child: Text('0.0000', style: _balanceStyle))
          else
            Text(coinText, style: _balanceStyle),
          const SizedBox(height: 10),
          if (showFiat) Text(coinText, style: _balanceSubStyle),
          if (lockedBalance > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+${lockedBalance.toStringAsFixed(12)} ${i18n.pending.toLowerCase()}',
                style: _balanceSubStyle,
              ),
            ),
          if (fiatRate.hasFailed && !fiatRate.isDisabled)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, size: 15, color: BrandColors.error),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      i18n.homeFiatApiError,
                      overflow: TextOverflow.ellipsis,
                      style: BrandText.caption.copyWith(color: BrandColors.error),
                    ),
                  ),
                ],
              ),
            ),
          _connectionRow(context, i18n),
        ],
      ),
    );
  }

  /// The connection info row: transport/kind pills. While syncing the pills
  /// compact to icons with "x blocks left" beside them; when the connection has
  /// failed, the same slot shows "Disconnected" in red.
  Widget _connectionRow(BuildContext context, AppLocalizations i18n) {
    final cw = xmrWallet(context);
    if (cw == null || cw.connectionAddress.isEmpty) return const SizedBox.shrink();
    final blocks = wallet.syncBlocksRemaining;
    final trailing = blocks != null
        ? i18n.homeBlocksRemaining(NumberFormat.decimalPattern().format(blocks))
        : disconnected
        ? i18n.homeDisconnected
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: trailing == null
          ? ConnectionPills(wallet: cw)
          : Row(
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
            ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback onReceive;
  final VoidCallback onSend;

  const _ActionRow({required this.onReceive, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: ActionButton(
            icon: Icons.arrow_downward,
            label: i18n.homeReceive,
            onPressed: onReceive,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ActionButton(icon: Icons.arrow_upward, label: i18n.homeSend, onPressed: onSend),
        ),
      ],
    );
  }
}

class _ActivitySliver extends StatelessWidget {
  final AppWallet wallet;
  final AppLocalizations i18n;
  final FiatRateModel fiatRate;
  final String fiatSymbol;
  final void Function(TxDetails tx) onTapTx;

  const _ActivitySliver({
    required this.wallet,
    required this.i18n,
    required this.fiatRate,
    required this.fiatSymbol,
    required this.onTapTx,
  });

  @override
  Widget build(BuildContext context) {
    // The engine wallet supplies the exact-BigInt tx history the shared row
    // reads; the parent watches the neutral wallet (listen: true) so this
    // subtree rebuilds when the history changes.
    final asset = xmrWallet(context)!;
    final txs = asset.txHistory;

    if (txs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            i18n.homeNoTransactions,
            textAlign: TextAlign.center,
            style: BrandText.bodyMuted,
          ),
        ),
      );
    }

    // Flatten into day-header strings interleaved with tx entries (matches Spice).
    final rows = <Object>[];
    DateTime? lastDay;
    for (final tx in txs) {
      final d = DateTime.fromMillisecondsSinceEpoch(tx.timestamp * 1000);
      final day = DateTime(d.year, d.month, d.day);
      if (day != lastDay) {
        rows.add(DateFormat('d MMMM').format(day).toUpperCase());
        lastDay = day;
      }
      rows.add(tx);
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row is String) {
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 4 : 16, bottom: 4),
              child: SectionHeader(label: row, padding: EdgeInsets.zero),
            );
          }
          final tx = row as TxDetails;
          // No coin icon: Skylight is single-coin (Monero), so the leading badge
          // is a coin-agnostic direction circle. Divider only within a day group.
          final next = index + 1 < rows.length ? rows[index + 1] : null;
          return TxActivityRow(
            tx: tx,
            asset: asset,
            showCoinIcon: false,
            labels: TxActivityLabels(received: i18n.coinHomeReceived, sent: i18n.coinHomeSent),
            fiatRate: fiatRate,
            fiatSymbol: fiatSymbol,
            showDivider: next is TxDetails,
            onTap: () => onTapTx(tx),
          );
        },
      ),
    );
  }
}
