import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:monero_light_wallet/models/fiat_rate_model.dart';
import 'package:monero_light_wallet/services/tor_service.dart';
import 'package:monero_light_wallet/widgets/fiat_amount.dart';
import 'package:monero_light_wallet/widgets/monero_amount.dart';
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

enum LwsConnectionStatus { disconnected, connecting, connected }

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  @override
  void initState() {
    super.initState();

    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    _initNewTxsCheckIfNeeded();

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
    final unlockedBalanceFiat =
        fiatRate.rate is double && wallet.unlockedBalance is double
        ? wallet.unlockedBalance! * fiatRate.rate!
        : null;
    final lockedBalance =
        (wallet.totalBalance ?? 0) - (wallet.unlockedBalance ?? 0);
    final fiatSymbol = fiatRate.fiatCode == 'EUR' ? '€' : '\$';
    var connectionStatus = LwsConnectionStatus.disconnected;

    if (wallet.isConnected &&
        wallet.isSynced &&
        (wallet.syncedHeight ?? 0) > 0) {
      connectionStatus = LwsConnectionStatus.connected;
    } else if (wallet.usingTor &&
            TorService.sharedInstance.status ==
                TorConnectionStatus.connecting ||
        !wallet.hasAttemptedConnection ||
        wallet.isConnected && !wallet.isSynced ||
        wallet.isConnected &&
            wallet.isSynced &&
            (wallet.syncedHeight ?? 0) == 0) {
      connectionStatus = LwsConnectionStatus.connecting;
    }

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
                              if (connectionStatus ==
                                  LwsConnectionStatus.connected)
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: Icon(
                                    Icons.check_circle,
                                    size: 26,
                                    color: Colors.teal,
                                  ),
                                ),

                              if (connectionStatus ==
                                  LwsConnectionStatus.connecting)
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

                              if (connectionStatus ==
                                  LwsConnectionStatus.disconnected)
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: Icon(Icons.cancel, color: Colors.red),
                                ),

                              StatusIcon(
                                status:
                                    fiatRate.rate is double &&
                                        !fiatRate.hasFailed &&
                                        TorService.sharedInstance.status ==
                                            TorConnectionStatus.connected
                                    ? StatusIconStatus.complete
                                    : fiatRate.hasFailed
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
                                  MoneroAmount(
                                    amount: wallet.unlockedBalance ?? 0,
                                    maxFontSize: 30,
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
                                FiatAmount(
                                  prefix: fiatSymbol,
                                  amount: unlockedBalanceFiat,
                                  maxFontSize: 18,
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
            if (wallet.txHistory != null && wallet.txHistory!.isNotEmpty)
              Expanded(
                child: SizedBox(
                  child: ListView.separated(
                    separatorBuilder: (context, index) => Divider(),
                    itemCount: wallet.txHistory!.length,
                    itemBuilder: (BuildContext context, int index) {
                      final tx = wallet.txHistory![index];
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
                                    MoneroAmount(
                                      amount: tx.amount,
                                      maxFontSize: 16,
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
                                      FiatAmount(
                                        prefix: fiatSymbol,
                                        amount: amountFiat,
                                        maxFontSize: 14,
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
            if (wallet.txHistory != null && wallet.txHistory!.isEmpty)
              Text(i18n.homeNoTransactions),
            if (wallet.txHistory == null) CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
