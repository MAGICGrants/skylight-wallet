import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/widgets/fiat_amount.dart';
import 'package:skylight_wallet/widgets/monero_amount.dart';
import 'package:skylight_wallet/widgets/status_icon.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/widgets/wallet_navigation_bar.dart';
import 'package:skylight_wallet/widgets/tx_details.dart';

enum LwsConnectionStatus { disconnected, connecting, connected }

enum DeviceType { phone, tablet, desktop }

class _TransactionListItem extends StatefulWidget {
  final TxDetails tx;
  final AppLocalizations i18n;
  final Locale currentLocale;
  final FiatRateModel fiatRate;
  final String fiatSymbol;
  final VoidCallback onTap;

  const _TransactionListItem({
    required this.tx,
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
    final amountFiat = widget.fiatRate.rate is double
        ? widget.tx.amount * widget.fiatRate.rate!
        : null;

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
                    MoneroAmount(amount: widget.tx.amount, maxFontSize: 16),
                    if (amountFiat == null && !widget.fiatRate.isDisabled)
                      Skeletonizer(
                        enabled: true,
                        child: Text('Potato', style: TextStyle(fontSize: 14)),
                      ),
                    if (amountFiat is double && !widget.fiatRate.isDisabled)
                      FiatAmount(prefix: widget.fiatSymbol, amount: amountFiat, maxFontSize: 14),
                  ],
                ),
                Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.tx.confirmations < 10 || widget.tx.height == -1)
                      Row(
                        children: [
                          Text(
                            '${widget.tx.height == -1 ? '0' : widget.tx.confirmations}/10',
                            style: TextStyle(color: Colors.amber.shade700),
                          ),
                          Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade700, size: 20),
                        ],
                      ),
                    if (widget.tx.confirmations >= 10 && widget.tx.height != -1) Text(''),
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

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  // Breakpoints for responsive design
  static const double _phoneMaxWidth = 700;
  static const double _tabletMaxWidth = 1024;

  DeviceType _getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < _phoneMaxWidth) {
      return DeviceType.phone;
    } else if (width < _tabletMaxWidth) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  @override
  void initState() {
    super.initState();

    NotificationService().showIncomingTxNotification(1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final Map<String, dynamic>? args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null && args['showTxSuccessToast']) {
        _showTxSuccessToast();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _showTxDetails(TxDetails txDetails) {
    TxDetailsDialog.show(context, txDetails);
  }

  void _showTxSuccessToast() {
    final i18n = AppLocalizations.of(context)!;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(i18n.sendTransactionSuccessfullySent)));
  }

  Widget _buildStatusIcons(
    WalletModel wallet,
    StatusIconStatus lwsConnectionIconStatus,
    StatusIconStatus fiatApiIconStatus,
    FiatRateModel fiatRate,
  ) {
    return Column(
      spacing: 10,
      children: [
        if (!wallet.usingTor && lwsConnectionIconStatus == StatusIconStatus.complete)
          SizedBox(
            width: 26,
            height: 26,
            child: Icon(Icons.check_circle, size: 26, color: Colors.teal),
          ),
        if (!wallet.usingTor && lwsConnectionIconStatus == StatusIconStatus.loading)
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              constraints: BoxConstraints(maxWidth: 22, maxHeight: 22),
              strokeWidth: 2,
            ),
          ),
        if (!wallet.usingTor && lwsConnectionIconStatus == StatusIconStatus.fail)
          SizedBox(width: 26, height: 26, child: Icon(Icons.cancel, color: Colors.red)),
        if (wallet.usingTor)
          StatusIcon(
            status: lwsConnectionIconStatus,
            child: SvgPicture.asset('assets/icons/tor.svg', width: 22, height: 22),
          ),
        if (!fiatRate.isDisabled)
          StatusIcon(
            status: fiatApiIconStatus,
            child: SvgPicture.asset('assets/icons/tor.svg', width: 22, height: 22),
          ),
      ],
    );
  }

  Widget _buildBalanceDisplay(
    BuildContext context,
    AppLocalizations i18n,
    WalletModel wallet,
    double? unlockedBalanceFiat,
    double lockedBalance,
    String fiatSymbol,
    FiatRateModel fiatRate,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 10,
          children: [
            SvgPicture.asset('assets/icons/monero.svg', width: 22, height: 22),
            MoneroAmount(amount: wallet.unlockedBalance ?? 0, maxFontSize: 30),
          ],
        ),
        if (lockedBalance > 0)
          Text(
            '+${lockedBalance.toStringAsFixed(12)} ${i18n.pending.toLowerCase()}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (unlockedBalanceFiat == null && !fiatRate.isDisabled)
          Skeletonizer(enabled: true, child: Text('Potato', style: TextStyle(fontSize: 18))),
        if (unlockedBalanceFiat is double && !fiatRate.isDisabled)
          FiatAmount(prefix: fiatSymbol, amount: unlockedBalanceFiat, maxFontSize: 18),
      ],
    );
  }

  Widget _buildActionButtons(AppLocalizations i18n) {
    return Row(
      spacing: 10,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton.icon(
          style: ButtonStyle(),
          label: Text(i18n.homeReceive),
          icon: Transform.rotate(
            angle: 90 * math.pi / 180,
            child: Icon(Icons.arrow_outward_rounded),
          ),
          onPressed: () => Navigator.pushNamed(context, '/receive'),
        ),
        FilledButton.icon(
          label: Text(i18n.homeSend),
          icon: Icon(Icons.arrow_outward_rounded),
          onPressed: () => Navigator.pushNamed(context, '/send'),
        ),
      ],
    );
  }

  Widget _buildTransactionListItem(
    BuildContext context,
    AppLocalizations i18n,
    Locale currentLocale,
    TxDetails tx,
    FiatRateModel fiatRate,
    String fiatSymbol,
  ) {
    return _TransactionListItem(
      tx: tx,
      i18n: i18n,
      currentLocale: currentLocale,
      fiatRate: fiatRate,
      fiatSymbol: fiatSymbol,
      onTap: () => _showTxDetails(tx),
    );
  }

  Widget _buildTransactionList(
    BuildContext context,
    AppLocalizations i18n,
    Locale currentLocale,
    WalletModel wallet,
    FiatRateModel fiatRate,
    String fiatSymbol,
  ) {
    if (wallet.txHistory.isEmpty) {
      return Text(i18n.homeNoTransactions);
    }

    return Expanded(
      child: ListView.separated(
        separatorBuilder: (context, index) =>
            Container(height: 1, color: Theme.of(context).colorScheme.surfaceContainerHighest),
        itemCount: wallet.txHistory.length,
        itemBuilder: (BuildContext context, int index) {
          final tx = wallet.txHistory[index];
          return _buildTransactionListItem(context, i18n, currentLocale, tx, fiatRate, fiatSymbol);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context);
    final wallet = context.watch<WalletModel>();
    final fiatRate = context.watch<FiatRateModel>();
    final deviceType = _getDeviceType(context);
    final unlockedBalanceFiat = fiatRate.rate is double && wallet.unlockedBalance is double
        ? wallet.unlockedBalance! * fiatRate.rate!
        : null;
    final lockedBalance = (wallet.totalBalance ?? 0) - (wallet.unlockedBalance ?? 0);
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';
    var lwsConnectionIconStatus = StatusIconStatus.fail;
    var fiatApiIconStatus = StatusIconStatus.loading;

    if (wallet.isConnected && wallet.isSynced && (wallet.syncedHeight ?? 0) > 0) {
      lwsConnectionIconStatus = StatusIconStatus.complete;
    } else if (wallet.usingTor &&
            TorService.sharedInstance.status == TorConnectionStatus.connecting ||
        !wallet.hasAttemptedConnection ||
        wallet.isConnected && !wallet.isSynced ||
        wallet.isConnected && wallet.isSynced && (wallet.syncedHeight ?? 0) == 0) {
      lwsConnectionIconStatus = StatusIconStatus.loading;
    }

    if (fiatRate.rate is double &&
        !fiatRate.hasFailed &&
        TorService.sharedInstance.status == TorConnectionStatus.connected) {
      fiatApiIconStatus = StatusIconStatus.complete;
    } else if (fiatRate.isLoading) {
      fiatApiIconStatus = StatusIconStatus.loading;
    } else if (fiatRate.hasFailed) {
      fiatApiIconStatus = StatusIconStatus.fail;
    }

    return Scaffold(
      bottomNavigationBar: WalletNavigationBar(selectedIndex: 0),
      body: SafeArea(
        child: _buildResponsiveLayout(
          context,
          deviceType,
          i18n,
          currentLocale,
          wallet,
          fiatRate,
          lwsConnectionIconStatus,
          fiatApiIconStatus,
          unlockedBalanceFiat,
          lockedBalance,
          fiatSymbol,
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(
    BuildContext context,
    DeviceType deviceType,
    AppLocalizations i18n,
    Locale currentLocale,
    WalletModel wallet,
    FiatRateModel fiatRate,
    StatusIconStatus lwsConnectionIconStatus,
    StatusIconStatus fiatApiIconStatus,
    double? unlockedBalanceFiat,
    double lockedBalance,
    String fiatSymbol,
  ) {
    switch (deviceType) {
      case DeviceType.phone:
        return _buildPhoneLayout(
          context,
          i18n,
          currentLocale,
          wallet,
          fiatRate,
          lwsConnectionIconStatus,
          fiatApiIconStatus,
          unlockedBalanceFiat,
          lockedBalance,
          fiatSymbol,
        );
      case DeviceType.tablet:
        return _buildTabletLayout(
          context,
          i18n,
          currentLocale,
          wallet,
          fiatRate,
          lwsConnectionIconStatus,
          fiatApiIconStatus,
          unlockedBalanceFiat,
          lockedBalance,
          fiatSymbol,
        );
      case DeviceType.desktop:
        return _buildDesktopLayout(
          context,
          i18n,
          currentLocale,
          wallet,
          fiatRate,
          lwsConnectionIconStatus,
          fiatApiIconStatus,
          unlockedBalanceFiat,
          lockedBalance,
          fiatSymbol,
        );
    }
  }

  Widget _buildPhoneLayout(
    BuildContext context,
    AppLocalizations i18n,
    Locale currentLocale,
    WalletModel wallet,
    FiatRateModel fiatRate,
    StatusIconStatus lwsConnectionIconStatus,
    StatusIconStatus fiatApiIconStatus,
    double? unlockedBalanceFiat,
    double lockedBalance,
    String fiatSymbol,
  ) {
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
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildStatusIcons(
                        wallet,
                        lwsConnectionIconStatus,
                        fiatApiIconStatus,
                        fiatRate,
                      ),
                    ),
                    Center(
                      child: _buildBalanceDisplay(
                        context,
                        i18n,
                        wallet,
                        unlockedBalanceFiat,
                        lockedBalance,
                        fiatSymbol,
                        fiatRate,
                      ),
                    ),
                  ],
                ),
              ),
              _buildActionButtons(i18n),
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
        _buildTransactionList(context, i18n, currentLocale, wallet, fiatRate, fiatSymbol),
      ],
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    AppLocalizations i18n,
    Locale currentLocale,
    WalletModel wallet,
    FiatRateModel fiatRate,
    StatusIconStatus lwsConnectionIconStatus,
    StatusIconStatus fiatApiIconStatus,
    double? unlockedBalanceFiat,
    double lockedBalance,
    String fiatSymbol,
  ) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        spacing: 20,
        children: [
          SizedBox(
            width: 340,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  child: _buildStatusIcons(
                    wallet,
                    lwsConnectionIconStatus,
                    fiatApiIconStatus,
                    fiatRate,
                  ),
                ),
                Column(
                  children: [
                    _buildBalanceDisplay(
                      context,
                      i18n,
                      wallet,
                      unlockedBalanceFiat,
                      lockedBalance,
                      fiatSymbol,
                      fiatRate,
                    ),
                    SizedBox(height: 10),
                    _buildActionButtons(i18n),
                  ],
                ),
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
                _buildTransactionList(context, i18n, currentLocale, wallet, fiatRate, fiatSymbol),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    AppLocalizations i18n,
    Locale currentLocale,
    WalletModel wallet,
    FiatRateModel fiatRate,
    StatusIconStatus lwsConnectionIconStatus,
    StatusIconStatus fiatApiIconStatus,
    double? unlockedBalanceFiat,
    double lockedBalance,
    String fiatSymbol,
  ) {
    return _buildTabletLayout(
      context,
      i18n,
      currentLocale,
      wallet,
      fiatRate,
      lwsConnectionIconStatus,
      fiatApiIconStatus,
      unlockedBalanceFiat,
      lockedBalance,
      fiatSymbol,
    );
  }
}
