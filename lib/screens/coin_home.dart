import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:spice_wallet/consts.dart' as consts;
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/connection_setup.dart';
import 'package:spice_wallet/screens/explorer_setup.dart';
import 'package:spice_wallet/screens/receive.dart';
import 'package:spice_wallet/screens/send.dart';
import 'package:spice_wallet/wallets/crypto_wallet.dart';
import 'package:spice_wallet/wallets/wallet_manager.dart';
import 'package:spice_wallet/widgets/coin_amount.dart';
import 'package:spice_wallet/widgets/fiat_amount.dart';
import 'package:spice_wallet/widgets/connection_status_indicator.dart';
import 'package:spice_wallet/widgets/tx_details.dart';
import 'package:spice_wallet/widgets/wallet_navigation_bar.dart';

class CoinHomeScreenArgs {
  final String coinSymbol;
  final bool showTxSuccessToast;

  CoinHomeScreenArgs({required this.coinSymbol, this.showTxSuccessToast = false});
}

enum _DeviceType { phone, tablet, desktop }

class CoinHomeScreen extends StatefulWidget {
  const CoinHomeScreen({super.key});

  @override
  State<CoinHomeScreen> createState() => _CoinHomeScreenState();
}

class _CoinHomeScreenState extends State<CoinHomeScreen> {
  static const double _phoneMaxWidth = 700;
  static const double _tabletMaxWidth = 1024;

  CoinHomeScreenArgs? _args;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as CoinHomeScreenArgs?;
      _args = args;
      if (args != null && args.showTxSuccessToast) {
        _showTxSuccessToast();
      }
    });
  }

  _DeviceType _getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < _phoneMaxWidth) return _DeviceType.phone;
    if (width < _tabletMaxWidth) return _DeviceType.tablet;
    return _DeviceType.desktop;
  }

  void _showTxDetails(CryptoWallet wallet, TxDetails tx) {
    TxDetailsDialog.show(context, wallet, tx);
  }

  void _showTxSuccessToast() {
    final i18n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(i18n.sendTransactionSuccessfullySent)));
  }

  String _coinSymbolFromRoute(BuildContext context) {
    final args = _args ?? ModalRoute.of(context)?.settings.arguments as CoinHomeScreenArgs?;
    return args?.coinSymbol ?? '';
  }

  Widget _buildConnectionStatusCorner(AppLocalizations i18n, CryptoWallet wallet) {
    final state = _connectionIndicatorState(wallet);
    final message = _connectionHeaderTooltip(i18n, wallet, state);
    return ConnectionStatusIndicator(state: state, tooltipMessage: message);
  }

  String _connectionHeaderTooltip(
    AppLocalizations i18n,
    CryptoWallet wallet,
    ConnectionIndicatorState state,
  ) {
    if (state == ConnectionIndicatorState.ok) return '';

    final remaining = wallet.syncBlocksRemaining;
    if (remaining != null) {
      return i18n.homeBlocksRemaining(NumberFormat.decimalPattern().format(remaining));
    }

    if (wallet.connectionAddress.isEmpty) return i18n.homeCoinNotConfigured;

    final scheme = wallet.connectionUseSsl ? 'https' : 'http';
    String msg = state == ConnectionIndicatorState.loading
        ? '${i18n.homeConnecting}: $scheme://${wallet.connectionAddress}'
        : '${i18n.homeConnectionErrorTooltip}: $scheme://${wallet.connectionAddress}';

    if (wallet.connectionUseTor) msg += ' via Tor';
    if (wallet.connectionProxyPort.isNotEmpty) {
      msg += ' via proxy port ${wallet.connectionProxyPort}';
    }

    return msg.trim();
  }

  Widget _buildBalanceDisplay({
    required BuildContext context,
    required AppLocalizations i18n,
    required CryptoWallet wallet,
    required double? unlockedBalanceFiat,
    required double lockedBalance,
    required String fiatSymbol,
    required FiatRateModel fiatRate,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 10,
          children: [
            SvgPicture.asset(wallet.iconAsset, width: 22, height: 22),
            if (wallet.unlockedBalance == null)
              Skeletonizer(enabled: true, child: Text('0.000000', style: TextStyle(fontSize: 30)))
            else
              CoinAmount(
                amount: wallet.unlockedBalance!,
                decimals: wallet.decimals,
                smallerDigits: wallet.smallerDigits,
                maxFontSize: 30,
              ),
          ],
        ),
        if (lockedBalance > 0)
          Text(
            '+${lockedBalance.toStringAsFixed(wallet.decimals)} ${i18n.pending.toLowerCase()}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 4,
          children: [
            if (fiatRate.isSupported(wallet.coinSymbol) && fiatRate.hasFailed)
              Tooltip(
                message: i18n.homeFiatApiError,
                child: Icon(Icons.warning_rounded, size: 18, color: Colors.red),
              ),
            if (fiatRate.isSupported(wallet.coinSymbol) &&
                unlockedBalanceFiat == null &&
                !fiatRate.isDisabled)
              Skeletonizer(enabled: true, child: Text('Potato', style: TextStyle(fontSize: 18))),
            if (fiatRate.isSupported(wallet.coinSymbol) &&
                unlockedBalanceFiat is double &&
                !fiatRate.isDisabled)
              FiatAmount(prefix: fiatSymbol, amount: unlockedBalanceFiat, maxFontSize: 18),
          ],
        ),
      ],
    );
  }

  void _openConnectionSetup(CryptoWallet wallet) {
    Navigator.pushNamed(
      context,
      '/connection_setup',
      arguments: ConnectionSetupScreenArgs(coinSymbol: wallet.coinSymbol),
    );
  }

  void _openExplorerSetup(CryptoWallet wallet) {
    Navigator.pushNamed(
      context,
      '/explorer_setup',
      arguments: ExplorerSetupScreenArgs(coinSymbol: wallet.coinSymbol),
    );
  }

  Widget _buildActionButtons(AppLocalizations i18n, CryptoWallet wallet) {
    final coinSymbol = wallet.coinSymbol;
    final hasConnection = wallet.connectionAddress.isNotEmpty;

    return Row(
      spacing: 10,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton.icon(
          label: Text(i18n.homeReceive),
          icon: Transform.rotate(
            angle: 90 * math.pi / 180,
            child: Icon(Icons.arrow_outward_rounded),
          ),
          onPressed: hasConnection
              ? () => Navigator.pushNamed(
                  context,
                  '/receive',
                  arguments: ReceiveScreenArgs(coinSymbol: coinSymbol),
                )
              : null,
        ),
        FilledButton.icon(
          label: Text(i18n.homeSend),
          icon: Icon(Icons.arrow_outward_rounded),
          onPressed: hasConnection
              ? () => Navigator.pushNamed(
                  context,
                  '/send',
                  arguments: SendScreenArgs(coinSymbol: coinSymbol, destinationAddress: ''),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildTransactionList({
    required BuildContext context,
    required AppLocalizations i18n,
    required Locale currentLocale,
    required CryptoWallet wallet,
    required FiatRateModel fiatRate,
    required String fiatSymbol,
  }) {
    if (wallet.txHistory.isEmpty) {
      final needsExplorer = wallet.supportsExplorerUrl && wallet.explorerAddress.isEmpty;
      if (!needsExplorer) {
        return Text(i18n.homeNoTransactions);
      }
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(i18n.homeNoTransactions, textAlign: TextAlign.center),
            SizedBox(height: 12),
            Text(
              i18n.explorerSetupHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openExplorerSetup(wallet),
              icon: Icon(Icons.travel_explore),
              label: Text(i18n.explorerSetupButton),
            ),
          ],
        ),
      );
    }

    return Expanded(
      child: ListView.separated(
        separatorBuilder: (context, index) =>
            Container(height: 1, color: Theme.of(context).colorScheme.surfaceContainerHighest),
        itemCount: wallet.txHistory.length,
        itemBuilder: (BuildContext context, int index) {
          final tx = wallet.txHistory[index];
          return _TransactionListItem(
            tx: tx,
            wallet: wallet,
            i18n: i18n,
            currentLocale: currentLocale,
            fiatRate: fiatRate,
            fiatSymbol: fiatSymbol,
            onTap: () => _showTxDetails(wallet, tx),
          );
        },
      ),
    );
  }

  ConnectionIndicatorState _connectionIndicatorState(CryptoWallet wallet) =>
      connectionIndicatorStateFor(wallet);

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context);
    final walletManager = context.watch<WalletManager>();
    final fiatRate = context.watch<FiatRateModel>();

    final coinSymbol = _coinSymbolFromRoute(context);
    final wallet = walletManager.getWallet(coinSymbol);

    if (wallet == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Unknown coin: $coinSymbol')),
      );
    }

    final coinRate = fiatRate.rateFor(wallet.coinSymbol);
    final unlockedBalanceFiat = coinRate != null && wallet.unlockedBalance is double
        ? wallet.unlockedBalance! * coinRate
        : null;
    final lockedBalance = wallet.canSpendPendingBalance
        ? 0.0
        : (wallet.totalBalance ?? 0) - (wallet.unlockedBalance ?? 0);
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';

    return Scaffold(
      appBar: AppBar(
        title: Text(wallet.coinName),
        actions: [
          if (wallet.coinSymbol == 'XMR')
            IconButton(
              icon: Icon(Icons.vpn_key_outlined),
              tooltip: i18n.lwsKeysTitle,
              onPressed: () => Navigator.pushNamed(context, '/lws_keys'),
            ),
          if (wallet.supportsExplorerUrl)
            IconButton(
              icon: Icon(Icons.travel_explore),
              tooltip: i18n.explorerSetupTitle,
              onPressed: () => _openExplorerSetup(wallet),
            ),
          IconButton(
            icon: Icon(Icons.dns_outlined),
            tooltip: i18n.coinHomeServerConnectionButton,
            onPressed: () => _openConnectionSetup(wallet),
          ),
        ],
      ),
      bottomNavigationBar: WalletNavigationBar(selectedIndex: 0),
      body: SafeArea(
        child: _buildResponsiveLayout(
          context: context,
          deviceType: _getDeviceType(context),
          i18n: i18n,
          currentLocale: currentLocale,
          wallet: wallet,
          fiatRate: fiatRate,
          unlockedBalanceFiat: unlockedBalanceFiat,
          lockedBalance: lockedBalance,
          fiatSymbol: fiatSymbol,
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout({
    required BuildContext context,
    required _DeviceType deviceType,
    required AppLocalizations i18n,
    required Locale currentLocale,
    required CryptoWallet wallet,
    required FiatRateModel fiatRate,
    required double? unlockedBalanceFiat,
    required double lockedBalance,
    required String fiatSymbol,
  }) {
    final balanceDisplay = _buildBalanceDisplay(
      context: context,
      i18n: i18n,
      wallet: wallet,
      unlockedBalanceFiat: unlockedBalanceFiat,
      lockedBalance: lockedBalance,
      fiatSymbol: fiatSymbol,
      fiatRate: fiatRate,
    );
    final actionButtons = _buildActionButtons(i18n, wallet);
    final statusCorner = _buildConnectionStatusCorner(i18n, wallet);
    final txList = _buildTransactionList(
      context: context,
      i18n: i18n,
      currentLocale: currentLocale,
      wallet: wallet,
      fiatRate: fiatRate,
      fiatSymbol: fiatSymbol,
    );

    if (deviceType == _DeviceType.phone) {
      return Column(
        spacing: 20,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsetsGeometry.all(20),
            child: Column(
              spacing: 20,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 86,
                  child: Stack(
                    children: [
                      Positioned(top: 0, right: 0, child: statusCorner),
                      Center(child: balanceDisplay),
                    ],
                  ),
                ),
                actionButtons,
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
              child: Text(
                i18n.homeTransactionsTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.start,
              ),
            ),
          ),
          txList,
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        spacing: 20,
        children: [
          SizedBox(
            width: 340,
            child: Stack(
              children: [
                Positioned(top: 0, left: 0, child: statusCorner),
                Column(children: [balanceDisplay, SizedBox(height: 10), actionButtons]),
              ],
            ),
          ),
          Expanded(
            child: Column(
              spacing: 20,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
                    child: Text(
                      i18n.homeTransactionsTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.start,
                    ),
                  ),
                ),
                txList,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionListItem extends StatefulWidget {
  final TxDetails tx;
  final CryptoWallet wallet;
  final AppLocalizations i18n;
  final Locale currentLocale;
  final FiatRateModel fiatRate;
  final String fiatSymbol;
  final VoidCallback onTap;

  const _TransactionListItem({
    required this.tx,
    required this.wallet,
    required this.i18n,
    required this.currentLocale,
    required this.fiatRate,
    required this.fiatSymbol,
    required this.onTap,
  });

  @override
  State<_TransactionListItem> createState() => _TransactionListItemState();
}

class _TransactionListItemState extends State<_TransactionListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final coinRate = widget.fiatRate.rateFor(widget.wallet.coinSymbol);
    final amountFiat = coinRate != null ? widget.tx.amount * coinRate : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: _isHovered
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(vertical: 10, horizontal: 20),
            child: Row(
              spacing: 20,
              children: [
                if (widget.tx.direction == consts.txDirectionOutgoing)
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: Colors.red,
                    size: 20,
                    semanticLabel: widget.i18n.homeOutgoingTxSemanticLabel,
                  ),
                if (widget.tx.direction == consts.txDirectionIncoming)
                  Transform.rotate(
                    angle: 90 * math.pi / 180,
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      color: Colors.teal,
                      size: 20,
                      semanticLabel: widget.i18n.homeIncomingTxSemanticLabel,
                    ),
                  ),
                Column(
                  mainAxisAlignment: widget.fiatRate.isDisabled
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CoinAmount(
                      amount: widget.tx.amount,
                      decimals: widget.wallet.decimals,
                      smallerDigits: widget.wallet.smallerDigits,
                      maxFontSize: 16,
                    ),
                    if (widget.fiatRate.isSupported(widget.wallet.coinSymbol) &&
                        amountFiat == null &&
                        !widget.fiatRate.isDisabled)
                      Skeletonizer(
                        enabled: true,
                        child: Text('Potato', style: TextStyle(fontSize: 14)),
                      ),
                    if (widget.fiatRate.isSupported(widget.wallet.coinSymbol) &&
                        amountFiat is double &&
                        !widget.fiatRate.isDisabled)
                      FiatAmount(prefix: widget.fiatSymbol, amount: amountFiat, maxFontSize: 14),
                  ],
                ),
                Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!widget.wallet.isTxConfirmed(widget.tx))
                      Row(
                        children: [
                          Text(
                            '${widget.tx.height == -1 ? '0' : widget.tx.confirmations}/${widget.wallet.requiredConfirmations}',
                            style: TextStyle(color: Colors.amber.shade700),
                          ),
                          Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade700, size: 20),
                        ],
                      ),
                    Text(
                      timeago.format(
                        DateTime.fromMillisecondsSinceEpoch(widget.tx.timestamp * 1000),
                        locale: widget.currentLocale.languageCode,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
