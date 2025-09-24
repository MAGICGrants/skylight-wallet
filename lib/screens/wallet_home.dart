import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:monero_light_wallet/models/fiat_rate_model.dart';
import 'package:monero_light_wallet/widgets/status_icon.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/services/shared_preferences_service.dart';
import 'package:monero_light_wallet/periodic_tasks.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/consts.dart' as consts;
import 'package:monero_light_wallet/widgets/wallet_navigation_bar.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  Timer? _timer;
  List<TxDetails>? _txHistory;

  @override
  void initState() {
    super.initState();

    final wallet = Provider.of<WalletModel>(context, listen: false);
    wallet.refresh();

    if (!wallet.isConnected()) {
      wallet.connectToDaemon();
    }

    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    _initNewTxsCheckIfNeeded();
    _startTimer();
    _loadTxHistory();

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
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 30), (timer) {
      final wallet = Provider.of<WalletModel>(context, listen: false);
      wallet.refresh();
      wallet.store();
      _loadTxHistory();
    });
  }

  Future<void> _loadTxHistory() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    final newTxHistory = await wallet.getFullTxHistory();

    setState(() {
      _txHistory = newTxHistory;
    });

    await wallet.persistTxHistoryCount();
  }

  void _showTxDetails(TxDetails txDetails) {
    Navigator.pushNamed(context, '/tx_details', arguments: txDetails);
  }

  Future<void> _initNewTxsCheckIfNeeded() async {
    final notificationsEnabled =
        await SharedPreferencesService.get<bool>(
          SharedPreferencesKeys.notificationsEnabled,
        ) ??
        false;

    final taskIsRunning = await Workmanager().isScheduledByUniqueName(
      PeriodicTasks.newTransactionsCheck,
    );

    if (notificationsEnabled && !taskIsRunning) {
      await startNewTransactionsCheckTask();
    }
  }

  void _showTxSuccessToast() {
    final i18n = AppLocalizations.of(context)!;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(i18n.sendTransactionSuccessfullySent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context);
    final wallet = context.watch<WalletModel>();
    final fiatRate = context.watch<FiatRateModel>();
    final connected = wallet.isConnected();
    final synced = wallet.isSynced();
    final height = wallet.getSyncedHeight();
    final totalBalance = wallet.getTotalBalance();
    final unlockedBalance = wallet.getUnlockedBalance();
    final unlockedBalanceFiat = fiatRate.rate is double
        ? unlockedBalance * fiatRate.rate!
        : null;
    final lockedBalance = totalBalance - unlockedBalance;
    final unlockedBalanceStr = unlockedBalance.toStringAsFixed(12);
    final unlockedBalanceSmallerSlice = unlockedBalanceStr.substring(
      unlockedBalanceStr.length - 8,
    );
    final unlockedBalanceBiggerSlice = unlockedBalanceStr.substring(
      0,
      unlockedBalanceStr.length - 8,
    );

    final fiatSymbol = fiatRate.fiatCode == 'EUR' ? '€' : '\$';

    return Scaffold(
      bottomNavigationBar: WalletNavigationBar(selectedIndex: 0),
      body: SafeArea(
        child: Column(
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
                          child: Column(
                            spacing: 10,
                            children: [
                              if (connected && synced && height != 0)
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: Icon(
                                    Icons.check_circle,
                                    size: 26,
                                    color: Colors.teal,
                                  ),
                                ),

                              if (connected && (!synced || height == 0))
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    constraints: BoxConstraints(
                                      maxWidth: 22,
                                      maxHeight: 22,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                ),

                              if (!connected)
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: Icon(Icons.cancel, color: Colors.red),
                                ),

                              StatusIcon(
                                status:
                                    fiatRate.rate is double &&
                                        !fiatRate.hasFailed
                                    ? StatusIconStatus.complete
                                    : fiatRate.rate == null &&
                                          fiatRate.hasFailed
                                    ? StatusIconStatus.fail
                                    : StatusIconStatus.loading,
                                child: SvgPicture.asset(
                                  'assets/icons/tor.svg',
                                  width: 22,
                                  height: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                spacing: 10,
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/monero.svg',
                                    width: 22,
                                    height: 22,
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        unlockedBalanceBiggerSlice,
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Container(
                                        margin: EdgeInsetsGeometry.only(top: 5),
                                        child: Text(
                                          unlockedBalanceSmallerSlice,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (lockedBalance > 0)
                                Text(
                                  '+${lockedBalance.toStringAsFixed(12)} ${i18n.pending.toLowerCase()}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (unlockedBalanceFiat == null)
                                Skeletonizer(
                                  enabled: true,
                                  child: Text(
                                    'Potato',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              if (unlockedBalanceFiat is double)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$fiatSymbol${unlockedBalanceFiat.toInt()}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    Container(
                                      margin: EdgeInsets.only(top: 2),
                                      child: Text(
                                        (unlockedBalanceFiat % 1)
                                            .toStringAsFixed(2)
                                            .substring(2),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    spacing: 10,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ButtonStyle(),
                        label: Text(i18n.homeReceive),
                        icon: Transform.rotate(
                          angle: 90 * math.pi / 180,
                          child: Icon(Icons.arrow_outward_rounded),
                        ),
                        onPressed: () =>
                            Navigator.pushNamed(context, '/receive'),
                      ),
                      ElevatedButton.icon(
                        label: Text(i18n.homeSend),
                        icon: Icon(Icons.arrow_outward_rounded),
                        onPressed: () => Navigator.pushNamed(context, '/send'),
                      ),
                    ],
                  ),
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
            if (_txHistory != null && _txHistory!.isNotEmpty)
              Expanded(
                child: SizedBox(
                  child: ListView.separated(
                    separatorBuilder: (context, index) => Divider(),
                    itemCount: _txHistory!.length,
                    itemBuilder: (BuildContext context, int index) {
                      final tx = _txHistory![index];
                      final amountStr = tx.amount.toStringAsFixed(12);
                      final amountSmallerSlice = amountStr.substring(
                        amountStr.length - 8,
                      );
                      final amountBiggerSlice = amountStr.substring(
                        0,
                        amountStr.length - 8,
                      );
                      final amountFiat = fiatRate.rate is double
                          ? tx.amount * fiatRate.rate!
                          : null;

                      return Padding(
                        padding: EdgeInsetsDirectional.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: SizedBox(
                          height: 44,
                          child: GestureDetector(
                            onTap: () => _showTxDetails(tx),
                            child: Row(
                              spacing: 20,
                              children: [
                                if (tx.direction == consts.txDirectionOutgoing)
                                  Icon(
                                    Icons.arrow_outward_rounded,
                                    color: Colors.red,
                                    size: 20,
                                    semanticLabel:
                                        i18n.homeOutgoingTxSemanticLabel,
                                  ),
                                if (tx.direction == consts.txDirectionIncoming)
                                  Transform.rotate(
                                    angle: 90 * math.pi / 180,
                                    child: Icon(
                                      Icons.arrow_outward_rounded,
                                      color: Colors.teal,
                                      size: 20,
                                      semanticLabel:
                                          i18n.homeIncomingTxSemanticLabel,
                                    ),
                                  ),
                                Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          amountBiggerSlice,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Container(
                                          margin: EdgeInsets.only(top: 2),
                                          child: Text(
                                            amountSmallerSlice,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (amountFiat == null)
                                      Skeletonizer(
                                        enabled: true,
                                        child: Text(
                                          'Potato',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    if (amountFiat is double)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$fiatSymbol${amountFiat.toInt()}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          Container(
                                            margin: EdgeInsets.only(top: 3),
                                            child: Text(
                                              (amountFiat % 1)
                                                  .toStringAsFixed(2)
                                                  .substring(2),
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w300,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                Spacer(),
                                Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (tx.confirmations < 10)
                                      Row(
                                        children: [
                                          Text(
                                            '${tx.confirmations}/10',
                                            style: TextStyle(
                                              color: Colors.amber.shade700,
                                            ),
                                          ),
                                          Icon(
                                            Icons.hourglass_top_rounded,
                                            color: Colors.amber.shade700,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    if (tx.confirmations >= 10) Text(''),
                                    Text(
                                      timeago.format(
                                        DateTime.fromMillisecondsSinceEpoch(
                                          tx.timestamp * 1000,
                                        ),
                                        locale: currentLocale.languageCode,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (_txHistory != null && _txHistory!.isEmpty)
              Text(i18n.homeNoTransactions),
            if (_txHistory == null) CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
