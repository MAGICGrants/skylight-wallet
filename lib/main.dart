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
import 'package:skylight_wallet/util/wallet.dart';
import 'package:skylight_wallet/util/wallet_file_crypto.dart';
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

/// Fast wallet-file probe for startup routing (no FFI / network).
Future<bool> _anyWalletFileExists() async {
  for (final symbol in ['XMR', 'BTC', 'TBTC']) {
    final path = await getWalletPath(symbol);
    final file = File(path);
    if (!await file.exists()) continue;
    if (symbol == 'XMR') return true;
    final length = await file.length();
    if (length >= WalletFileCrypto.minBlobLength) return true;
  }
  return false;
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
      child: _RootApp(),
    );
  }
}

/// Loads prefs and picks the initial route, then builds a single [MaterialApp].
class _RootApp extends StatefulWidget {
  const _RootApp();

  @override
  State<_RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<_RootApp> {
  String? _initialRoute;
  bool _startedServices = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final walletExists = await _anyWalletFileExists();

      if (mounted) {
        unawaited(context.read<WalletManager>().loadPreferences());
      }

      if (walletExists && mounted) {
        unawaited(context.read<WalletManager>().loadCachedDisplayState());
      }

      final appLockEnabled = prefs.getBool(SharedPreferencesKeys.appLockEnabled) ?? false;
      final initialRoute = walletExists
          ? appLockEnabled || isDesktop
                ? '/unlock'
                : '/wallet_home'
          : '/welcome';

      if (!mounted) return;
      setState(() {
        _initialRoute = initialRoute;
      });

      if (walletExists) {
        context.read<FiatRateModel>().startService(walletManager: context.read<WalletManager>());
      }
    } catch (e) {
      log(LogLevel.error, 'App bootstrap failed: $e');
      if (!mounted) return;
      setState(() {
        _initialRoute = '/welcome';
      });
    }
  }

  ThemeData get _themeData => ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue));

  ThemeData get _darkThemeData => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
  );

  Map<String, WidgetBuilder> get _routes => {
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
  };

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageModel>();
    final themeMode = context.watch<ThemeModel>().themeMode;
    final initialRoute = _initialRoute ?? '/loading';

    if (_initialRoute != null && !_startedServices) {
      _startedServices = true;
      TorSettingsService.sharedInstance.loadSettings();
      TorService.sharedInstance.start();
    }

    return MaterialApp(
      key: ValueKey(initialRoute),
      title: 'Skylight Wallet',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _themeData,
      darkTheme: _darkThemeData,
      themeMode: themeMode,
      initialRoute: initialRoute,
      locale: Locale.fromSubtags(languageCode: languageProvider.language),
      routes: {
        '/loading': (context) => Scaffold(body: Center(child: CircularProgressIndicator())),
        ..._routes,
      },
    );
  }
}
