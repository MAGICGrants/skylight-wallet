import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:monero_light_wallet/models/fiat_rate_model.dart';
import 'package:monero_light_wallet/screens/confirm_send.dart';
import 'package:monero_light_wallet/screens/lws_details.dart';
import 'package:monero_light_wallet/screens/lws_keys.dart';
import 'package:monero_light_wallet/screens/scan_qr.dart';
import 'package:monero_light_wallet/screens/secret_keys.dart';
import 'package:monero_light_wallet/services/tor_service.dart';
import 'package:monero_light_wallet/models/language_model.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/services/notifications_service.dart';
import 'package:monero_light_wallet/screens/settings.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/screens/connection_setup.dart';
import 'package:monero_light_wallet/screens/generate_seed.dart';
import 'package:monero_light_wallet/screens/receive.dart';
import 'package:monero_light_wallet/screens/send.dart';
import 'package:monero_light_wallet/screens/tx_details.dart';
import 'package:monero_light_wallet/screens/create_wallet.dart';
import 'package:monero_light_wallet/screens/restore_wallet.dart';
import 'package:monero_light_wallet/screens/restore_warning.dart';
import 'package:monero_light_wallet/screens/wallet_home.dart';
import 'package:monero_light_wallet/screens/welcome.dart';
import 'package:monero_light_wallet/util/logging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  timeago.setLocaleMessages('pt', timeago.PtBrMessages());

  runApp(MyApp());
}

Future<bool> loadExistingWalletIfExists(WalletModel wallet) async {
  if (await wallet.hasExistingWallet()) {
    await wallet.openExisting();
    await wallet.loadPersistedConnection();
    return true;
  }

  return false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => WalletModel()),
        ChangeNotifierProvider(create: (context) => LanguageModel()),
        ChangeNotifierProvider(create: (context) => FiatRateModel()),
      ],
      child: Consumer<LanguageModel>(
        builder: (context, languageProvider, child) {
          final wallet = Provider.of<WalletModel>(context, listen: false);

          return FutureBuilder(
            // Since LanguageModel loads the user's language from
            // SharedPreferences, we need to wait until an instance is loaded.
            // We also need to wait until it is determined whether or not a
            // wallet already exists, so we know which screen to send the user
            // to initially.
            future: Future.wait([
              SharedPreferences.getInstance(),
              loadExistingWalletIfExists(wallet),
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.data != null) {
                final walletExists = snapshot.data![1] as bool;
                final initialRoute = walletExists ? '/wallet_home' : '/welcome';
                TorService.sharedInstance.start();

                if (walletExists) {
                  (() async {
                    await wallet.refresh();
                    await wallet.loadAllStats();
                    wallet.notifyListenersFromOutside();
                    await wallet.connectToDaemon();
                    wallet.notifyListenersFromOutside();
                  })();
                }

                return MaterialApp(
                  title: 'Monero Light Wallet',
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: ThemeData(
                    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                  ),
                  initialRoute: initialRoute,
                  locale: Locale.fromSubtags(
                    languageCode: languageProvider.language,
                  ),
                  routes: {
                    '/welcome': (context) => WelcomeScreen(),
                    '/connection_setup': (context) => ConnectionSetupScreen(),
                    '/create_wallet': (context) => CreateWalletScreen(),
                    '/generate_seed': (context) => GenerateSeedScreen(),
                    '/lws_details': (context) => LwsDetailsScreen(),
                    '/restore_warning': (context) => RestoreWarningScreen(),
                    '/restore_wallet': (context) => RestoreWalletScreen(),
                    '/wallet_home': (context) => WalletHomeScreen(),
                    '/settings': (context) => SettingsScreen(),
                    '/lws_keys': (context) => LwsKeysScreen(),
                    '/secret_keys': (context) => SecretKeysScreen(),
                    '/send': (context) => SendScreen(),
                    '/confirm_send': (context) => ConfirmSendScreen(),
                    '/scan_qr': (context) => ScanQrScreen(),
                    '/receive': (context) => ReceiveScreen(),
                    '/tx_details': (context) => TxDetailsScreen(),
                  },
                );
              }

              if (snapshot.data == null) {
                log(LogLevel.error, 'Future builder snapshot data is null.');
                log(LogLevel.error, snapshot.error.toString());
              }

              return MaterialApp(
                title: 'Monero Light Wallet',
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                ),
                builder: (context, child) => Scaffold(),
              );
            },
          );
        },
      ),
    );
  }
}
