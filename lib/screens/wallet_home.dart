import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/screens/coin_home.dart';
import 'package:skylight_wallet/screens/connection_setup.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';
import 'package:skylight_wallet/widgets/coin_amount.dart';
import 'package:skylight_wallet/widgets/fiat_amount.dart';
import 'package:skylight_wallet/widgets/connection_status_indicator.dart';
import 'package:skylight_wallet/widgets/wallet_navigation_bar.dart';

class WalletHomeScreen extends StatelessWidget {
  const WalletHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final walletManager = context.watch<WalletManager>();
    final fiatRate = context.watch<FiatRateModel>();
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';

    final ratesBySymbol = <String, double?>{
      for (final w in walletManager.allWallets) w.coinSymbol: fiatRate.rateFor(w.coinSymbol),
    };
    final totalFiat = walletManager.totalUnlockedFiat(ratesBySymbol);

    return Scaffold(
      appBar: AppBar(title: Text('Skylight Wallet')),
      bottomNavigationBar: WalletNavigationBar(selectedIndex: 0),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TotalBalanceHeader(
                  totalFiat: totalFiat,
                  fiatSymbol: fiatSymbol,
                  fiatRate: fiatRate,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    i18n.homeYourCoinsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    separatorBuilder: (context, _) => Container(
                      height: 1,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    itemCount: walletManager.allWallets.length,
                    itemBuilder: (context, index) {
                      final wallet = walletManager.allWallets[index];
                      return _CoinRow(wallet: wallet, fiatRate: fiatRate, fiatSymbol: fiatSymbol);
                    },
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

class _TotalBalanceHeader extends StatelessWidget {
  final double? totalFiat;
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Text(
            i18n.homeTotalBalanceLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: 6),
          if (totalFiat is double)
            FiatAmount(prefix: fiatSymbol, amount: totalFiat!, maxFontSize: 32)
          else if (!fiatRate.isDisabled)
            Skeletonizer(enabled: true, child: Text('Potato', style: TextStyle(fontSize: 32)))
          else
            Text('--', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
          if (fiatRate.hasFailed)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Tooltip(
                message: i18n.homeFiatApiError,
                child: Icon(Icons.warning_rounded, size: 18, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoinRow extends StatefulWidget {
  final CryptoWallet wallet;
  final FiatRateModel fiatRate;
  final String fiatSymbol;

  const _CoinRow({required this.wallet, required this.fiatRate, required this.fiatSymbol});

  @override
  State<_CoinRow> createState() => _CoinRowState();
}

class _CoinRowState extends State<_CoinRow> {
  bool _isHovered = false;

  ConnectionIndicatorState _connectionIndicatorState() {
    final wallet = widget.wallet;
    if (wallet.connectionAddress.isEmpty) return ConnectionIndicatorState.error;
    if (wallet.isConnected && wallet.isSynced && (wallet.syncedHeight ?? 0) > 0) {
      return ConnectionIndicatorState.ok;
    }
    if (wallet.usingTor && TorService.sharedInstance.status == TorConnectionStatus.connecting ||
        !wallet.hasAttemptedConnection ||
        wallet.isConnected && !wallet.isSynced ||
        wallet.isConnected && wallet.isSynced && (wallet.syncedHeight ?? 0) == 0) {
      return ConnectionIndicatorState.loading;
    }
    return ConnectionIndicatorState.error;
  }

  String _connectionRowTooltip(AppLocalizations i18n) {
    final wallet = widget.wallet;
    switch (_connectionIndicatorState()) {
      case ConnectionIndicatorState.ok:
        return '';
      case ConnectionIndicatorState.loading:
        return i18n.homeConnecting;
      case ConnectionIndicatorState.error:
        return wallet.connectionAddress.isEmpty
            ? i18n.homeCoinNotConfigured
            : i18n.homeConnectionErrorTooltip;
    }
  }

  void _openCoin() {
    final wallet = widget.wallet;
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

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = widget.wallet;
    final hasConnection = wallet.connectionAddress.isNotEmpty;
    final balance = wallet.unlockedBalance;
    final coinRate = widget.fiatRate.rateFor(wallet.coinSymbol);
    final balanceFiat = coinRate != null && balance is double ? balance * coinRate : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: _isHovered
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openCoin,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                SvgPicture.asset(wallet.iconAsset, width: 36, height: 36),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        spacing: 8,
                        children: [
                          Text(
                            wallet.coinName,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          ConnectionStatusIndicator(
                            state: _connectionIndicatorState(),
                            tooltipMessage: _connectionRowTooltip(i18n),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        hasConnection ? wallet.coinSymbol : i18n.homeCoinNotConfigured,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasConnection)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CoinAmount(
                        amount: balance ?? 0,
                        decimals: wallet.decimals,
                        smallerDigits: wallet.smallerDigits,
                        maxFontSize: 16,
                      ),
                      if (balanceFiat is double && !widget.fiatRate.isDisabled)
                        FiatAmount(prefix: widget.fiatSymbol, amount: balanceFiat, maxFontSize: 12),
                    ],
                  )
                else
                  TextButton.icon(
                    onPressed: _openCoin,
                    icon: Icon(Icons.settings, size: 16),
                    label: Text(i18n.homeCoinSetUp),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
