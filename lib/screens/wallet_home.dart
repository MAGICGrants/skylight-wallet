import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:spice_wallet/consts.dart' as consts;
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/coin_home.dart';
import 'package:spice_wallet/screens/connection_setup.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/util/format.dart';
import 'package:spice_wallet/widgets/connection_status_indicator.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:spice_wallet/widgets/wallet_navigation_bar.dart';
import 'package:wallet_domain/wallet_domain.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapIfNeeded());
  }

  Future<void> _bootstrapIfNeeded() async {
    final manager = context.read<WalletManager>();
    if (manager.loadedWallets.isNotEmpty) {
      manager.syncInBackground();
      return;
    }
    if (manager.hasPassword) {
      manager.openWalletFilesAndSync();
      return;
    }
    unawaited(manager.bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    final walletManager = context.watch<WalletManager>();
    final fiatRate = context.watch<FiatRateModel>();
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';

    final ratesBySymbol = <String, double?>{
      for (final w in walletManager.allWallets) w.coinSymbol: fiatRate.rateFor(w.coinSymbol),
    };
    final totalFiat = walletManager.totalUnlockedFiat(ratesBySymbol);

    // Tokens (DAI/SDAI) don't get their own row — they live inside their parent
    // chain's assets list. The parent row shows the aggregate value instead.
    final wallets = walletManager.allWallets.where((w) => !isTokenWallet(w)).toList()
      ..sort((a, b) {
        final aConfigured = a.connectionAddress.isNotEmpty;
        final bConfigured = b.connectionAddress.isNotEmpty;
        if (aConfigured != bConfigured) return aConfigured ? -1 : 1;
        return 0;
      });

    return Scaffold(
      backgroundColor: BrandColors.paper,
      bottomNavigationBar: const WalletNavigationBar(selectedIndex: 0),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: BrandSpacing.lg),
                    children: [
                      _TotalBalanceHeader(
                        totalFiat: totalFiat,
                        fiatSymbol: fiatSymbol,
                        fiatRate: fiatRate,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          children: [
                            for (final wallet in wallets) ...[
                              _CoinCard(
                                wallet: wallet,
                                fiatRate: fiatRate,
                                fiatSymbol: fiatSymbol,
                                tokenCount: tokensOf(walletManager, wallet.coinSymbol).length,
                                fiatOverride: aggregateUnlockedFiat(
                                  walletManager,
                                  wallet,
                                  fiatRate.rateFor,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
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
          SvgPicture.asset('assets/spice-icon.svg', width: 30, height: 30),
          const SizedBox(width: 9),
          Text(
            'Spice Wallet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              height: 1,
              color: BrandColors.cinnamonDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBalanceHeader extends StatelessWidget {
  final double totalFiat;
  final String fiatSymbol;
  final FiatRateModel fiatRate;

  const _TotalBalanceHeader({
    required this.totalFiat,
    required this.fiatSymbol,
    required this.fiatRate,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(label: i18n.homeTotalBalanceLabel, padding: EdgeInsets.zero),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!fiatRate.isDisabled)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: BalanceText.split(formatFiat(totalFiat, fiatSymbol)),
                  ),
                )
              else
                Text('--', style: BrandText.balance),
              if (fiatRate.hasFailed && !fiatRate.isDisabled) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Tooltip(
                    message: i18n.homeFiatApiError,
                    child: Icon(Icons.warning_rounded, size: 18, color: BrandColors.warning),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CoinCard extends StatelessWidget {
  final CryptoWallet wallet;
  final FiatRateModel fiatRate;
  final String fiatSymbol;

  /// Number of tokens on this chain (>0 → the row shows "N assets" + aggregate).
  final int tokenCount;

  /// Aggregate fiat across the chain + its tokens; falls back to own fiat.
  final double? fiatOverride;

  const _CoinCard({
    required this.wallet,
    required this.fiatRate,
    required this.fiatSymbol,
    this.tokenCount = 0,
    this.fiatOverride,
  });

  static TextStyle get _cardBalanceStyle => TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    height: 1,
    color: BrandColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  void _open(BuildContext context) {
    if (wallet.connectionAddress.isEmpty) {
      Navigator.pushNamed(
        context,
        '/connection_setup',
        arguments: ConnectionSetupScreenArgs(coinSymbol: wallet.coinSymbol),
      );
    } else {
      Navigator.pushNamed(
        context,
        '/coin_home',
        arguments: CoinHomeScreenArgs(coinSymbol: wallet.coinSymbol),
      );
    }
  }

  Widget _leading() =>
      CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 40);

  /// (dot colour, status text). Dot is null for unconfigured coins; a chain with
  /// tokens prefixes the status with "N assets · ".
  (Color?, String) _status(AppLocalizations i18n) {
    final assets = tokenCount > 0 ? '${i18n.homeAssetsCount(tokenCount + 1)} · ' : '';
    if (wallet.connectionAddress.isEmpty) {
      return (null, '$assets${i18n.homeCoinNotConfigured}');
    }
    switch (connectionIndicatorStateFor(wallet)) {
      case ConnectionIndicatorState.ok:
        return (BrandColors.success, '$assets${i18n.homeSynced}');
      case ConnectionIndicatorState.loading:
        // Monero node syncing exposes a block count; show "x blocks left".
        final blocks = wallet.syncBlocksRemaining;
        final text = blocks != null
            ? i18n.homeBlocksRemaining(NumberFormat.decimalPattern().format(blocks))
            : i18n.homeSyncing;
        return (BrandColors.warning, '$assets$text');
      case ConnectionIndicatorState.error:
        return (BrandColors.error, '$assets${i18n.homeNoConnection}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final configured = wallet.connectionAddress.isNotEmpty;
    final balance = wallet.unlockedBalance;
    final coinRate = fiatRate.rateFor(wallet.coinSymbol);
    final ownFiat = coinRate != null && balance is double ? balance * coinRate : null;
    final balanceFiat = fiatOverride ?? ownFiat;
    final (dotColor, statusText) = _status(i18n);

    return Material(
      color: BrandColors.card,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: BrandColors.border),
        borderRadius: BorderRadius.circular(BrandRadii.field),
      ),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(BrandRadii.field),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              _leading(),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.blockchainName,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        color: BrandColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (dotColor != null) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                              color: BrandColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (configured) _trailingBalance(balance, balanceFiat),
              Icon(Icons.chevron_right, size: 20, color: BrandColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailingBalance(Object? balance, double? balanceFiat) {
    // Prefer the fiat value (design); fall back to the coin amount when fiat is
    // unavailable (disabled, no rate, or balance not yet loaded).
    if (balanceFiat != null && !fiatRate.isDisabled) {
      return Padding(
        padding: const EdgeInsets.only(right: 7),
        child: BalanceText.split(formatFiat(balanceFiat, fiatSymbol), style: _cardBalanceStyle),
      );
    }
    if (balance == null) {
      return Padding(
        padding: EdgeInsets.only(right: 7),
        child: Skeletonizer(child: Text('0.000000', style: _cardBalanceStyle)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Text(
        (balance is double ? balance : 0.0).toStringAsFixed(
          wallet.decimals > 6 ? 6 : wallet.decimals,
        ),
        style: _cardBalanceStyle,
      ),
    );
  }
}
