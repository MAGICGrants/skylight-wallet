import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/models/contact_model.dart';
import 'package:skylight_wallet/screens/confirm_send.dart';
import 'package:skylight_wallet/screens/lws_details.dart';
import 'package:skylight_wallet/screens/lws_keys.dart';
import 'package:skylight_wallet/screens/scan_qr.dart';
import 'package:skylight_wallet/screens/secret_keys.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/models/language_model.dart';
import 'package:skylight_wallet/models/theme_model.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/screens/settings.dart';
import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/screens/connection_setup.dart';
import 'package:skylight_wallet/screens/generate_seed.dart';
import 'package:skylight_wallet/screens/receive.dart';
import 'package:skylight_wallet/screens/send.dart';
import 'package:skylight_wallet/screens/create_wallet.dart';
import 'package:skylight_wallet/screens/create_wallet_password.dart';
import 'package:skylight_wallet/screens/restore_wallet.dart';
import 'package:skylight_wallet/screens/restore_warning.dart';
import 'package:skylight_wallet/screens/wallet_home.dart';
import 'package:skylight_wallet/screens/welcome.dart';
import 'package:skylight_wallet/screens/address_book.dart';
import 'package:skylight_wallet/screens/privacy_policy.dart';
import 'package:skylight_wallet/screens/terms_of_service.dart';
import 'package:skylight_wallet/screens/unlock.dart';
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/periodic_tasks.dart';
import 'package:skylight_wallet/util/dirs.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/cacert.dart';

final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
final isMobile = Platform.isAndroid || Platform.isIOS;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  timeago.setLocaleMessages('pt', timeago.PtBrMessages());
  await createAppDir();
  copyCacertToAppDocumentsDir();
  TorService.sharedInstance.start();
  await registerPeriodicTasks();
  await NotificationService().init();
  cleanOldLogFiles();
  runApp(MyApp());
}

Future<bool> loadExistingWalletIfExists(WalletModel wallet) async {
  if (await wallet.hasExistingWallet()) {
    if (isMobile) {
      await wallet.openExisting();
      await wallet.loadPersistedConnection();
      wallet.load();
    }

    return true;
  }

  // No wallet exists, fetch and cache the blockchain height in the background for future wallet creation
  if (wallet.blockchainHeightCompleter == null) {
    wallet.fetchAndCacheBlockchainHeight();
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
        ChangeNotifierProvider(create: (context) => ThemeModel()),
        ChangeNotifierProvider(create: (context) => FiatRateModel()),
        ChangeNotifierProvider(create: (context) => ContactModel()),
      ],
      child: Consumer2<LanguageModel, ThemeModel>(
        builder: (context, languageProvider, themeProvider, child) {
          final wallet = Provider.of<WalletModel>(context, listen: false);

          return FutureBuilder(
            // We need to check for wallet existence to determine the correct initial route,
            // but we'll do this quickly without loading the wallet to avoid startup delay.
            future: Future.wait([
              SharedPreferences.getInstance(),
              loadExistingWalletIfExists(wallet),
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                final sharedPreferences = snapshot.data![0] as SharedPreferences;
                final walletExists = snapshot.data![1] as bool;

                final theme = sharedPreferences.getString(SharedPreferencesKeys.theme) ?? 'system';

                final appLockEnabled =
                    sharedPreferences.getBool(SharedPreferencesKeys.appLockEnabled) ?? false;

                final initialRoute = walletExists
                    ? appLockEnabled || isDesktop
                          ? '/unlock'
                          : '/wallet_home'
                    : '/welcome';

                return MaterialApp(
                  title: 'Skylight Monero Wallet',
                  localizationsDelegates: AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
                  darkTheme: ThemeData(
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: Colors.blue,
                      brightness: Brightness.dark,
                    ),
                  ),
                  themeMode: theme == 'dark'
                      ? ThemeMode.dark
                      : theme == 'light'
                      ? ThemeMode.light
                      : ThemeMode.system,
                  initialRoute: initialRoute,
                  locale: Locale.fromSubtags(languageCode: languageProvider.language),
                  routes: {
                    '/welcome': (context) => WelcomeScreen(),
                    '/connection_setup': (context) => ConnectionSetupScreen(),
                    '/create_wallet_password': (context) => CreateWalletPasswordScreen(),
                    '/create_wallet': (context) => CreateWalletScreen(),
                    '/generate_seed': (context) => GenerateSeedScreen(),
                    '/lws_details': (context) => LwsDetailsScreen(),
                    '/restore_warning': (context) => RestoreWarningScreen(),
                    '/restore_wallet': (context) => RestoreWalletScreen(),
                    '/unlock': (context) => UnlockScreen(),
                    '/wallet_home': (context) => WalletHomeScreen(),
                    '/settings': (context) => SettingsScreen(),
                    '/lws_keys': (context) => LwsKeysScreen(),
                    '/secret_keys': (context) => SecretKeysScreen(),
                    '/send': (context) => SendScreen(),
                    '/confirm_send': (context) => ConfirmSendScreen(),
                    '/scan_qr': (context) => ScanQrScreen(),
                    '/receive': (context) => ReceiveScreen(),
                    '/address_book': (context) => AddressBookScreen(),
                    '/terms_of_service': (context) => TermsOfService(),
                    '/privacy_policy': (context) => PrivacyPolicy(),
                  },
                );
              }

              if (snapshot.data == null) {
                log(LogLevel.error, 'Future builder snapshot data is null.');
                log(LogLevel.error, snapshot.error.toString());
              }

              return MaterialApp(
                title: 'Skylight Monero Wallet',
                theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
                darkTheme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.blue,
                    brightness: Brightness.dark,
                  ),
                ),
                themeMode: ThemeMode.system,
                builder: (context, child) => Scaffold(),
              );
            },
          );
        },
      ),
    );
  }
}
