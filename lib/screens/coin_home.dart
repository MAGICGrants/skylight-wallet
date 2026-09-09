import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:spice_wallet/consts.dart' as consts;
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/coin_settings.dart';
import 'package:spice_wallet/screens/explorer_setup.dart';
import 'package:spice_wallet/screens/receive.dart';
import 'package:spice_wallet/screens/send.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/util/format.dart';
import 'package:spice_wallet/widgets/tx_activity_row.dart';
import 'package:spice_wallet/widgets/connection_status_indicator.dart';
import 'package:spice_wallet/widgets/route_pill.dart';
import 'package:spice_wallet/widgets/tx_details.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class CoinHomeScreenArgs {
  final String coinSymbol;
  final bool showTxSuccessToast;

  CoinHomeScreenArgs({required this.coinSymbol, this.showTxSuccessToast = false});
}

TextStyle get _balanceStyle => TextStyle(
  fontFamily: 'Ubuntu Mono',
  fontSize: 33,
  height: 1,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.66,
  color: BrandColors.ink,
  fontFeatures: [FontFeature.tabularFigures()],
);

class CoinHomeScreen extends StatefulWidget {
  const CoinHomeScreen({super.key});

  @override
  State<CoinHomeScreen> createState() => _CoinHomeScreenState();
}

class _CoinHomeScreenState extends State<CoinHomeScreen> {
  CoinHomeScreenArgs? _args;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as CoinHomeScreenArgs?;
      _args = args;
      if (args != null && args.showTxSuccessToast) _showTxSuccessToast();
    });
  }

  String _coinSymbolFromRoute(BuildContext context) {
    final args = _args ?? ModalRoute.of(context)?.settings.arguments as CoinHomeScreenArgs?;
    return args?.coinSymbol ?? '';
  }

  void _showTxSuccessToast() {
    final i18n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(i18n.sendTransactionSuccessfullySent)));
  }

  void _openReceive(String coinSymbol) => Navigator.pushNamed(
    context,
    '/receive',
    arguments: ReceiveScreenArgs(coinSymbol: coinSymbol),
  );

  void _openSend(String coinSymbol) => Navigator.pushNamed(
    context,
    '/send',
    arguments: SendScreenArgs(coinSymbol: coinSymbol, destinationAddress: ''),
  );

  void _openSettings(String coinSymbol) => Navigator.pushNamed(
    context,
    '/coin_settings',
    arguments: CoinSettingsScreenArgs(coinSymbol: coinSymbol),
  );

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final walletManager = context.watch<WalletManager>();
    final fiatRate = context.watch<FiatRateModel>();

    final coinSymbol = _coinSymbolFromRoute(context);
    final entered = walletManager.getWallet(coinSymbol);

    if (entered == null) {
      return Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(
          child: Center(child: Text('Unknown coin: $coinSymbol', style: BrandText.body)),
        ),
      );
    }

    // Operate on the chain: entering as a token (e.g. DAI) shows its parent
    // chain (Ethereum), whose screen aggregates the balance, assets and activity
    // of every asset on it.
    final wallet = walletManager.getWallet(chainSymbolOf(entered)) ?? entered;
    final chainSymbol = wallet.coinSymbol;
    final assets = chainAssets(walletManager, wallet);
    final hasTokens = assets.length > 1;

    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';
    final totalFiat = aggregateUnlockedFiat(walletManager, wallet, fiatRate.rateFor);

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(wallet: wallet, onSettings: () => _openSettings(chainSymbol)),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BalanceHero(
                              wallet: wallet,
                              totalFiat: totalFiat,
                              fiatSymbol: fiatSymbol,
                              fiatRate: fiatRate,
                              hasTokens: hasTokens,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                              child: _ActionRow(
                                enabled: wallet.connectionAddress.isNotEmpty,
                                onReceive: () => _openReceive(chainSymbol),
                                onSend: () => _openSend(chainSymbol),
                                onSwap: () => ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(i18n.coinHomeSwapComingSoon)),
                                ),
                              ),
                            ),
                            if (hasTokens)
                              _AssetsSection(
                                assets: assets,
                                fiatRate: fiatRate,
                                fiatSymbol: fiatSymbol,
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
                        chain: wallet,
                        assets: assets,
                        i18n: i18n,
                        fiatRate: fiatRate,
                        fiatSymbol: fiatSymbol,
                        onTapTx: (asset, tx) => TxDetailsDialog.show(context, asset, tx),
                        onSetupExplorer: () => Navigator.pushNamed(
                          context,
                          '/explorer_setup',
                          arguments: ExplorerSetupScreenArgs(coinSymbol: chainSymbol),
                        ),
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

double? _ownFiat(CryptoWallet wallet, FiatRateModel fiatRate) {
  final rate = fiatRate.rateFor(wallet.coinSymbol);
  final balance = wallet.unlockedBalance;
  return rate != null && balance is double ? balance * rate : null;
}

/// Compact coin amount ("412.09041"), capped so long-decimal coins stay legible.
String _amountText(CryptoWallet wallet) {
  final b = wallet.unlockedBalance;
  return b is double ? formatAmount(b, wallet.decimals) : '—';
}

class _Header extends StatelessWidget {
  final CryptoWallet wallet;
  final VoidCallback onSettings;

  const _Header({required this.wallet, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: BrandScreenHeader(
        onBack: () => Navigator.pop(context),
        // Status dot on the header icon; the header sits on the paper ground.
        center: CoinBadge(
          wallet: wallet,
          statusColor: connectionDotColor(wallet),
          statusRingColor: BrandColors.paper,
          statusDotFactor: 0.46,
        ),
        action: IconCircleButton(icon: Icons.tune, onPressed: onSettings),
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  final CryptoWallet wallet;
  final double? totalFiat;
  final String fiatSymbol;
  final FiatRateModel fiatRate;
  final bool hasTokens;

  const _BalanceHero({
    required this.wallet,
    required this.totalFiat,
    required this.fiatSymbol,
    required this.fiatRate,
    required this.hasTokens,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final showFiat = !fiatRate.isDisabled && totalFiat != null;
    final blocks = wallet.syncBlocksRemaining;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showFiat)
            BalanceText.split(formatFiat(totalFiat!, fiatSymbol), style: _balanceStyle)
          else if (wallet.unlockedBalance == null)
            Skeletonizer(child: Text('0.0000', style: _balanceStyle))
          else
            Text('${_amountText(wallet)} ${wallet.coinSymbol}', style: _balanceStyle),
          const SizedBox(height: 10),
          // Non-token chains show the coin amount as the subtitle; token chains
          // replace what used to be the "N assets" line with the pills.
          if (!hasTokens && showFiat)
            Text(
              '${_amountText(wallet)} ${wallet.coinSymbol}',
              style: TextStyle(
                fontFamily: 'Ubuntu Mono',
                fontSize: 13.5,
                height: 1,
                color: BrandColors.inkMuted,
              ),
            ),
          if (wallet.connectionAddress.isNotEmpty) ...[
            if (!hasTokens && showFiat) const SizedBox(height: 12),
            // While syncing (Monero node behind), compact the pills to icons and
            // show "x blocks left" beside them; otherwise the full pills.
            if (blocks != null)
              Row(
                children: [
                  ConnectionPills(wallet: wallet, compact: true),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 14, color: BrandColors.borderStrong),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      i18n.homeBlocksRemaining(NumberFormat.decimalPattern().format(blocks)),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Ubuntu Mono',
                        fontSize: 13,
                        height: 1,
                        color: BrandColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              )
            else
              ConnectionPills(wallet: wallet),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool enabled;
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback onSwap;

  const _ActionRow({
    required this.enabled,
    required this.onReceive,
    required this.onSend,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: ActionButton(
            icon: Icons.arrow_downward,
            label: i18n.homeReceive,
            onPressed: enabled ? onReceive : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ActionButton(
            icon: Icons.arrow_upward,
            label: i18n.homeSend,
            onPressed: enabled ? onSend : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ActionButton(icon: Icons.swap_horiz, label: i18n.coinHomeSwap, onPressed: onSwap),
        ),
      ],
    );
  }
}

class _AssetsSection extends StatelessWidget {
  final List<CryptoWallet> assets;
  final FiatRateModel fiatRate;
  final String fiatSymbol;

  const _AssetsSection({required this.assets, required this.fiatRate, required this.fiatSymbol});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: SectionHeader(label: i18n.coinHomeAssetsTitle, padding: EdgeInsets.zero),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          child: Column(
            children: [
              for (var i = 0; i < assets.length; i++) ...[
                _AssetRow(wallet: assets[i], fiatRate: fiatRate, fiatSymbol: fiatSymbol),
                if (i != assets.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  final CryptoWallet wallet;
  final FiatRateModel fiatRate;
  final String fiatSymbol;

  const _AssetRow({required this.wallet, required this.fiatRate, required this.fiatSymbol});

  static TextStyle get _fiatStyle => TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 14,
    height: 1,
    fontWeight: FontWeight.w700,
    color: BrandColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextStyle get _amountStyle => TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 11.5,
    height: 1.3,
    color: BrandColors.inkMuted,
  );

  @override
  Widget build(BuildContext context) {
    // Tokens (DAI) start with a null balance until their first background sync
    // fetches `balanceOf`; show a skeleton, not an em-dash, while it's loading.
    final loading = wallet.unlockedBalance == null;
    final fiat = _ownFiat(wallet, fiatRate);
    return BrandCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 34),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.assetName,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    color: BrandColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Skeletonizer(
                  enabled: loading,
                  child: Text(
                    loading ? '0.000000' : '${_amountText(wallet)} ${wallet.coinSymbol}',
                    style: _amountStyle,
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            Skeletonizer(enabled: true, child: Text('\$0.00', style: _fiatStyle))
          else if (fiat != null && !fiatRate.isDisabled)
            BalanceText.split(formatFiat(fiat, fiatSymbol), style: _fiatStyle),
        ],
      ),
    );
  }
}

/// A transaction paired with the chain asset it belongs to (ETH or DAI, …).
class _ActivitySliver extends StatelessWidget {
  final CryptoWallet chain;
  final List<CryptoWallet> assets;
  final AppLocalizations i18n;
  final FiatRateModel fiatRate;
  final String fiatSymbol;
  final void Function(CryptoWallet asset, TxDetails tx) onTapTx;
  final VoidCallback onSetupExplorer;

  const _ActivitySliver({
    required this.chain,
    required this.assets,
    required this.i18n,
    required this.fiatRate,
    required this.fiatSymbol,
    required this.onTapTx,
    required this.onSetupExplorer,
  });

  @override
  Widget build(BuildContext context) {
    // Merge every chain asset's history into one timeline, newest first.
    final entries = <TxEntry>[
      for (final asset in assets)
        for (final tx in asset.txHistory) (tx: tx, asset: asset),
    ]..sort((a, b) => b.tx.timestamp.compareTo(a.tx.timestamp));

    if (entries.isEmpty) {
      final needsExplorer = chain.supportsExplorerUrl && chain.explorerAddress.isEmpty;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: needsExplorer
              ? _AddExplorerNudge(i18n: i18n, onSetup: onSetupExplorer)
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    i18n.homeNoTransactions,
                    textAlign: TextAlign.center,
                    style: BrandText.bodyMuted,
                  ),
                ),
        ),
      );
    }

    // Flatten into day-header strings interleaved with tx entries.
    final rows = <Object>[];
    DateTime? lastDay;
    for (final e in entries) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.tx.timestamp * 1000);
      final day = DateTime(d.year, d.month, d.day);
      if (day != lastDay) {
        rows.add(DateFormat('d MMMM').format(day).toUpperCase());
        lastDay = day;
      }
      rows.add(e);
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
          final e = row as TxEntry;
          // Divider between consecutive tx rows in the same day group only.
          final next = index + 1 < rows.length ? rows[index + 1] : null;
          return TxActivityRow(
            tx: e.tx,
            asset: e.asset,
            i18n: i18n,
            fiatRate: fiatRate,
            fiatSymbol: fiatSymbol,
            showDivider: next is TxEntry,
            onTap: () => onTapTx(e.asset, e.tx),
          );
        },
      ),
    );
  }
}

/// Tan nudge card shown under Activity when the coin needs a block explorer to
/// surface transaction history.
class _AddExplorerNudge extends StatelessWidget {
  final AppLocalizations i18n;
  final VoidCallback onSetup;

  const _AddExplorerNudge({required this.i18n, required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.surfaceAccent,
        border: Border.all(color: BrandColors.borderStrong),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.search, size: 19, color: BrandColors.cinnamon),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  i18n.coinHomeAddExplorerTitle,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: BrandColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSetup,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrandColors.cinnamonDeep,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                i18n.coinHomeAddExplorerButton,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: BrandColors.onCinnamon,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
