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

    if (!wallet.isConnected()) {
      wallet.refresh();
      wallet.connectToDaemon();
    }

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
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      setState(() {
        _trigger = !_trigger;
      });
    });
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

  void _showTxSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Transaction successfully sent!')),
    );
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) => {
          if (index == 1) {Navigator.pushNamed(context, '/settings')},
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.wallet),
            label: i18n.navigationBarWallet,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: i18n.navigationBarSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          spacing: 20,
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
                      children: connected && synced
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
                    // color: WidgetStateProperty.all(Colors.teal.shade100),
                    shadowColor: null,
                  ),
                  Text(
                    '$balance XMR',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  Row(
                    spacing: 10,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/receive'),
                        child: Text(i18n.homeReceive),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/send'),
                        child: Text(i18n.homeSend),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SizedBox(
                child: ListView.builder(
                  itemCount: txHistory.length,
                  itemBuilder: (BuildContext context, int index) {
                    final tx = txHistory[index];

                    return Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: SizedBox(
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
