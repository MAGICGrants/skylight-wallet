import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monero/monero.dart' as monero;
import 'package:dart_date/dart_date.dart';

import 'package:monero_light_wallet/models/wallet_model.dart';

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
    _startTimer();
    final wallet = Provider.of<WalletModel>(context, listen: false);
    wallet.connectToDaemon();
    wallet.refresh();
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

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletModel>();
    final balance = wallet.getBalance();
    final connected = wallet.isConnected();
    final synced = wallet.isSynced();
    final height = wallet.getHeight();
    List<TxDetails> txHistory = [];

    if (synced) {
      wallet.refresh();
      txHistory = wallet.getTransactionHistory();
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
              'Connected: $connected',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Synced: $synced',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Height: $height',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Balance: $balance',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/receive'),
                  child: const Text('Receive'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/send'),
                  child: const Text('Send'),
                ),
                TextButton(
                  onPressed: _deleteWallet,
                  child: const Text('Delete'),
                ),
                TextButton(
                  onPressed: wallet.refresh,
                  child: const Text('Sync'),
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
                            if (tx.direction ==
                                monero.TransactionInfo_Direction.Out)
                              Icon(
                                Icons.arrow_outward_rounded,
                                color: Colors.red,
                                size: 20,
                                semanticLabel: 'Outgoing transaction',
                              ),
                            if (tx.direction ==
                                monero.TransactionInfo_Direction.In)
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
                              DateTime.fromMillisecondsSinceEpoch(
                                tx.timestamp * 1000,
                              ).timeago(),
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
