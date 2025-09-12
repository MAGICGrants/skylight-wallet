import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:monero_light_wallet/util/fiat_rate.dart';
import 'package:provider/provider.dart';
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
  double? _fiatRate;
  String? _fiatSymbol;

  @override
  void initState() {
    super.initState();

    _loadFiatRate();

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

  Future<void> _loadFiatRate() async {
    final fiatCode =
        await SharedPreferencesService.get<String>(
          SharedPreferencesKeys.fiatCurrency,
        ) ??
        'USD';

    final fiatSymbol = fiatCode == 'EUR' ? '€' : '\$';
    final rate = await getFiatRate(fiatCode);

    if (mounted) {
      setState(() {
        _fiatRate = rate;
        _fiatSymbol = fiatSymbol;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletModel>();
    final totalBalance = wallet.getTotalBalance();
    final unlockedBalance = wallet.getUnlockedBalance();
    final totalBalanceFiat = _fiatRate is double
        ? totalBalance * _fiatRate!
        : null;
    final lockedBalance = totalBalance - unlockedBalance;
    final connected = wallet.isConnected();
    final synced = wallet.isSynced();
    final height = wallet.getSyncedHeight();
    final currentLocale = Localizations.localeOf(context);

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
                  Chip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 12,
                      children: connected && synced && height != 0
                          ? [
                              Icon(Icons.check, color: Colors.teal),
                              Text('${i18n.homeHeight} $height'),
                            ]
                          : connected && (!synced || height == 0)
                          ? [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              Text(i18n.homeSyncing),
                            ]
                          : [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              Text(i18n.homeConnecting),
                            ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        totalBalance > 0 ? '$totalBalance XMR' : '0 XMR',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (totalBalanceFiat is double)
                        Text(
                          '$_fiatSymbol${totalBalanceFiat.toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (lockedBalance > 0)
                        Text(
                          '($lockedBalance XMR ${i18n.homeBalanceLocked})',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  Row(
                    spacing: 10,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
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

                      return Padding(
                        padding: EdgeInsetsDirectional.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: SizedBox(
                          height: 42,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${tx.amount} XMR',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (tx.confirmations < 10)
                                      Text(
                                        '${i18n.homeTransactionPending} - ${tx.confirmations}/10',
                                      ),
                                    if (tx.confirmations >= 10)
                                      Text(i18n.homeTransactionConfirmed),
                                  ],
                                ),
                                Spacer(),
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
