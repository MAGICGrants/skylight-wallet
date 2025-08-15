import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/services/shared_preferences_service.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:monero_light_wallet/periodic_tasks.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/consts.dart' as consts;

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  // ignore: unused_field
  bool _trigger = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    _initNewTxsCheckIfNeeded();
    _startTimer();
    final wallet = Provider.of<WalletModel>(context, listen: false);
    wallet.refresh();
    wallet.connectToDaemon();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      setState(() {
        _trigger = !_trigger;
      });
    });
  }

  void _deleteWallet() {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    wallet.delete();
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  void _showTxDetails(int txIndex) {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    final txDetails = wallet.getTxDetails(txIndex);
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

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletModel>();
    final balance = wallet.getBalance();
    final connected = wallet.isConnected();
    final synced = wallet.isSynced();
    final height = wallet.getSyncedHeight();
    List<TxDetails> txHistory = [];

    final currentLocale = Localizations.localeOf(context);

    if (synced) {
      wallet.refresh();
      txHistory = wallet.getTransactionHistory();
      wallet.persistTxHistoryCount();
    }

    if (txHistory.isNotEmpty) {
      wallet.store();
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          spacing: 10,
          children: [
            Text(
              '${i18n.homeConnected}: $connected',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${i18n.homeSynced}: $synced',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${i18n.homeHeight}: $height',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${i18n.homeBalance}: $balance XMR',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              spacing: 10,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/receive'),
                  child: Text(i18n.homeReceive),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/send'),
                  child: Text(i18n.homeSend),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  child: Text(i18n.homeSettings),
                ),
                TextButton(
                  onPressed: _deleteWallet,
                  child: Text(i18n.homeDelete),
                ),
              ],
            ),
            Expanded(
              child: SizedBox(
                child: ListView.builder(
                  itemCount: txHistory.length,
                  itemBuilder: (BuildContext context, int index) {
                    final tx = txHistory[index];

                    return SizedBox(
                      height: 32,
                      child: GestureDetector(
                        onTap: () => _showTxDetails(tx.index),
                        child: Row(
                          spacing: 20,
                          children: [
                            if (tx.direction == consts.txDirectionOutgoing)
                              Icon(
                                Icons.arrow_outward_rounded,
                                color: Colors.red,
                                size: 20,
                                semanticLabel: 'Outgoing transaction',
                              ),
                            if (tx.direction == consts.txDirectionIncoming)
                              Transform.rotate(
                                angle: 90 * math.pi / 180,
                                child: const Icon(
                                  Icons.arrow_outward_rounded,
                                  color: Colors.teal,
                                  size: 20,
                                  semanticLabel: 'Incoming transaction',
                                ),
                              ),
                            Text(tx.amount.toString()),
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
