import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/models/contact_model.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/screens/coin_home.dart';
import 'package:skylight_wallet/screens/confirm_send.dart';
import 'package:skylight_wallet/screens/scan_qr.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/models/language_model.dart';
import 'package:skylight_wallet/models/theme_model.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/screens/settings.dart';
import 'package:skylight_wallet/screens/connection_setup.dart';
import 'package:skylight_wallet/screens/fiat_api_setup_screen.dart';
import 'package:skylight_wallet/screens/generate_seed.dart';
import 'package:skylight_wallet/screens/receive.dart';
import 'package:skylight_wallet/screens/send.dart';
import 'package:skylight_wallet/screens/create_wallet.dart';
import 'package:skylight_wallet/screens/create_wallet_password.dart';
import 'package:skylight_wallet/screens/restore_wallet.dart';
import 'package:skylight_wallet/screens/restore_warning.dart';
import 'package:skylight_wallet/screens/wallet_home.dart';
import 'package:skylight_wallet/screens/welcome.dart';
import 'package:skylight_wallet/screens/tor_info.dart';
import 'package:skylight_wallet/screens/tor_settings.dart';
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
import 'package:skylight_wallet/wallets/wallet_manager.dart';

final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
final isMobile = Platform.isAndroid || Platform.isIOS;

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        log(LogLevel.error, 'Flutter error: ${details.exception}');
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
      };

      timeago.setLocaleMessages('pt', timeago.PtBrMessages());

      if (Platform.isLinux) {
        await createAppDir();
        NotificationService().init();
      }

      if (Platform.isWindows) {
        NotificationService().init();
      }

      if (Platform.isAndroid) {
        copyCacertToAppDocumentsDir();
        registerPeriodicTasks();
        NotificationService().init();
      }

      if (Platform.isIOS) {
        await cleanTorDirectoriesOnIOS();
      }

      cleanOldLogFiles();
      runApp(MyApp());
    },
    (error, stackTrace) {
      log(LogLevel.error, 'Uncaught error: $error');
      if (kDebugMode) {
        debugPrint('Uncaught error: $error');
        debugPrint('Stack trace: $stackTrace');
      }
    },
  );
}

Future<bool> loadExistingWalletsIfAny(WalletManager walletManager) async {
  if (!await walletManager.hasAnyExistingWallet()) {
    return false;
  }

  if (isMobile) {
    await walletManager.openAll();
    walletManager.loadAll();
  }

  return true;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WalletManager()),
        ChangeNotifierProvider(create: (_) => LanguageModel()),
        ChangeNotifierProvider(create: (_) => ThemeModel()),
        ChangeNotifierProvider(create: (_) => FiatRateModel()),
        ChangeNotifierProvider(create: (_) => ContactModel()),
      ],
      child: Consumer2<LanguageModel, ThemeModel>(
        builder: (context, languageProvider, themeProvider, child) {
          final walletManager = Provider.of<WalletManager>(context, listen: false);
          final fiatRate = Provider.of<FiatRateModel>(context, listen: false);

          return FutureBuilder(
            future: Future.wait([
              SharedPreferences.getInstance(),
              loadExistingWalletsIfAny(walletManager),
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                TorSettingsService.sharedInstance.loadSettings();
                TorService.sharedInstance.start();

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

                if (walletExists) {
                  fiatRate.startService();
                }

                return MaterialApp(
                  title: 'Skylight Wallet',
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
                    '/tor_info': (context) => TorInfoScreen(),
                    '/tor_settings': (context) => TorSettingsScreen(),
                    '/connection_setup': (context) => ConnectionSetupScreen(),
                    '/fiat_api_setup': (context) => FiatApiSetupScreen(),
                    '/create_wallet_password': (context) => CreateWalletPasswordScreen(),
                    '/create_wallet': (context) => CreateWalletScreen(),
                    '/generate_seed': (context) => GenerateSeedScreen(),
                    '/restore_warning': (context) => RestoreWarningScreen(),
                    '/restore_wallet': (context) => RestoreWalletScreen(),
                    '/unlock': (context) => UnlockScreen(),
                    '/wallet_home': (context) => WalletHomeScreen(),
                    '/coin_home': (context) => CoinHomeScreen(),
                    '/settings': (context) => SettingsScreen(),
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
                title: 'Skylight Wallet',
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
