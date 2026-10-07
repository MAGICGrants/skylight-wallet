import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/models/contact_model.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/screens/lws_details.dart';
import 'package:skylight_wallet/screens/lws_keys.dart';
import 'package:skylight_wallet/screens/scan_qr.dart';
import 'package:skylight_wallet/screens/secret_keys.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/models/language_model.dart';
import 'package:skylight_wallet/models/theme_model.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/screens/settings.dart';
import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/screens/connection_setup.dart';
import 'package:skylight_wallet/screens/fiat_api_setup_screen.dart';
import 'package:skylight_wallet/screens/generate_seed.dart';
import 'package:skylight_wallet/screens/receive.dart';
import 'package:skylight_wallet/screens/send.dart';
import 'package:skylight_wallet/screens/create_wallet.dart';
import 'package:skylight_wallet/screens/create_wallet_password.dart';
import 'package:skylight_wallet/screens/restore_wallet.dart';
import 'package:skylight_wallet/screens/wallet_home.dart';
import 'package:skylight_wallet/screens/welcome.dart';
import 'package:skylight_wallet/screens/tor_settings.dart';
import 'package:skylight_wallet/screens/address_book.dart';
import 'package:skylight_wallet/screens/privacy_policy.dart';
import 'package:skylight_wallet/screens/terms_of_service.dart';
import 'package:skylight_wallet/screens/unlock.dart';
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/theme/palette.dart';
import 'package:wallet_ui/wallet_ui.dart';
import 'package:skylight_wallet/periodic_tasks.dart';
import 'package:skylight_wallet/services/foreground_sync_service.dart';
import 'package:skylight_wallet/util/dirs.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:wallet_domain/wallet_domain.dart' show WalletManager, parsePaymentUri;
import 'package:wallet_infra/wallet_infra.dart' show HostPlatform;

void main() async {
  // Catch all uncaught async errors
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Before the first frame: the layout reads it synchronously.
      await HostPlatform.init();

      installWalletCore();
      BrandColors.install(skylightPalette);
      // Selected onboarding option cards stay white — only the accent border
      // marks the selection (no tinted fill).
      OnboardingRadioCard.selectedFill = () => BrandColors.card;

      // Catch Flutter framework errors
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
        registerPeriodicTasks();
        startForegroundSyncIfEnabled();
        NotificationService().init();
      }

      if (Platform.isIOS) {
        await cleanTorDirectoriesOnIOS();
        // Background sync here is LWS-only and decided by the connection; see
        // periodic_tasks._applyIosBackgroundTasks.
        registerPeriodicTasks();
        NotificationService().init();
      }

      cleanOldLogFiles();
      runApp(MyApp());
    },
    (error, stackTrace) {
      // Handle uncaught async errors (like socket disconnections)
      log(LogLevel.error, 'Uncaught error: $error');
      if (kDebugMode) {
        debugPrint('Uncaught error: $error');
        debugPrint('Stack trace: $stackTrace');
      }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        walletManagerProvider(),
        ChangeNotifierProvider(create: (context) => LanguageModel()),
        ChangeNotifierProvider(create: (context) => ThemeModel()),
        ChangeNotifierProvider(create: (context) => FiatRateModel()),
        ChangeNotifierProvider(create: (context) => ContactModel()),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> with WidgetsBindingObserver {
  // Started once, on the first build. Building it inside the builder would
  // re-run it on every theme/language change, opening the wallet again — a
  // second wallet on the same file, with its own sync loop, while the first is
  // left running.
  Future<List<Object>>? _startup;
  // Services that must fire once the startup work is done, not on every build.
  var _startedServices = false;
  // Desktop-only foreground announce: listens for tx-history growth (see below).
  AppWallet? _announceWallet;
  int _lastAnnouncedTxCount = 0;

  // Brightness-flip repaint: screens read BrandColors globally (not via
  // Theme.of), so a theme change doesn't dirty cached routes on its own. On an
  // actual flip we force an in-place rebuild of the navigator subtree.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _CurrentRouteObserver _routeObserver = _CurrentRouteObserver();
  bool _relockPending = false;
  bool _walletExists = false;
  Brightness? _lastBrightness;

  // A payment deep link (monero:) awaiting replay. Held until the app is past the
  // lock, then opened on the send form — see _onRouteChanged.
  String? _pendingPaymentUri;
  static const _paymentUriSchemes = {'monero'};

  static void _markSubtreeDirty(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markSubtreeDirty);
  }

  // The bottom-nav destinations. Tapping a nav tab must not animate, so these
  // get a zero-duration route in _onGenerateRoute.
  static const _noTransitionRoutes = {'/wallet_home', '/address_book', '/settings'};

  Map<String, WidgetBuilder> get _routes => {
    '/welcome': (context) => WelcomeScreen(),
    '/tor_settings': (context) => TorSettingsScreen(),
    '/connection_setup': (context) => ConnectionSetupScreen(),
    '/fiat_api_setup': (context) => FiatApiSetupScreen(),
    '/create_wallet_password': (context) => CreateWalletPasswordScreen(),
    '/create_wallet': (context) => CreateWalletScreen(),
    '/generate_seed': (context) => GenerateSeedScreen(),
    '/lws_details': (context) => LwsDetailsScreen(),
    '/restore_wallet': (context) => RestoreWalletScreen(),
    '/unlock': (context) => UnlockScreen(),
    '/wallet_home': (context) => WalletHomeScreen(),
    '/settings': (context) => SettingsScreen(),
    '/lws_keys': (context) =>
        ReauthGate(reason: AppLocalizations.of(context)!.settingsAppLockUnlockReason, child: LwsKeysScreen()),
    '/secret_keys': (context) =>
        ReauthGate(reason: AppLocalizations.of(context)!.revealSeedAuthReason, child: SecretKeysScreen()),
    '/send': (context) => SendScreen(),
    '/scan_qr': (context) => ScanQrScreen(),
    '/receive': (context) => ReceiveScreen(),
    '/address_book': (context) => AddressBookScreen(),
    '/terms_of_service': (context) => TermsOfService(),
    '/privacy_policy': (context) => PrivacyPolicy(),
  };

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final builder = _routes[settings.name];
    if (builder == null) return null;
    // Desktop: no transition anywhere. Mobile: only between the nav-bar screens;
    // every other push/pop keeps its normal animation.
    if (isDesktop || _noTransitionRoutes.contains(settings.name)) {
      return _NoTransitionPageRoute(builder: builder, settings: settings);
    }
    return MaterialPageRoute(builder: builder, settings: settings);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routeObserver.current.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeObserver.current.removeListener(_onRouteChanged);
    _announceWallet?.removeListener(_announceNewTxsOnGrowth);
    super.dispose();
  }

  // A deep link that arrives while the app is running (warm start). Payment links
  // open the send form; anything else is left to the default handling.
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    if (_handleDeepLink(routeInformation.uri.toString())) return true;
    return super.didPushRouteInformation(routeInformation);
  }

  bool _isPaymentUri(String raw) {
    final scheme = Uri.tryParse(raw.trim())?.scheme.toLowerCase();
    return scheme != null && _paymentUriSchemes.contains(scheme);
  }

  // Open a payment link now if the app is past the lock, else hold it for replay.
  bool _handleDeepLink(String raw) {
    if (!_isPaymentUri(raw)) return false;
    final current = _routeObserver.currentName;
    if (!_walletExists || current == null || current == '/unlock') {
      _pendingPaymentUri = raw;
    } else {
      _openPaymentUri(raw);
    }
    return true;
  }

  // Replay a held payment link the first time the app reaches home — after boot
  // (no lock) or after unlock. The send form still reviews and authenticates the
  // spend; the link only prefills it.
  void _onRouteChanged() {
    final raw = _pendingPaymentUri;
    if (raw == null || _routeObserver.currentName != '/wallet_home') return;
    _pendingPaymentUri = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPaymentUri(raw));
  }

  void _openPaymentUri(String raw) {
    if (!mounted) return;
    final manager = Provider.of<WalletManager>(context, listen: false);
    final request = parsePaymentUri(raw, manager.allWallets);
    if (request == null) return;
    final wallet = manager.getWallet(request.coinSymbol);
    // A coin with no connection set up can't send; warn instead of opening a form
    // that can't complete. The toast + l10n need a context below the MaterialApp,
    // so they go through the navigator's overlay rather than this (root) context.
    if (wallet == null || wallet.connectionAddress.isEmpty) {
      final overlay = _navigatorKey.currentState?.overlay;
      if (overlay == null) return;
      final name = wallet?.blockchainName ?? request.coinSymbol;
      showBrandToastOnOverlay(
        overlay,
        AppLocalizations.of(overlay.context)!.deepLinkCoinNotConfigured(name),
      );
      return;
    }
    _navigatorKey.currentState?.pushNamed(
      '/send',
      arguments: SendScreenArgs(destinationAddress: request.address, amount: request.amount),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isMobile) return;

    if (state == AppLifecycleState.paused) {
      // App Lock has to cover backgrounding, not just a cold start. Without
      // this, resuming walked straight back into an unlocked wallet with the
      // password still in memory, and the seed was reachable from there.
      unawaited(_maybeArmRelock());

      // Leaving the app marks everything on screen as seen so a background
      // isolate won't re-notify a tx the user just watched arrive. Desktop has
      // no background isolate — and doing this would pre-empt its foreground
      // announce. Marks only synced history (hash-based), so an unsynced
      // receipt is still announced later.
      unawaited(appWalletOf(context, listen: false).notifyNewIncomingTxs(announce: false));
    } else if (state == AppLifecycleState.resumed && _relockPending) {
      _relockPending = false;
      // Pushed ON TOP of the current stack rather than replacing it, so
      // unlocking pops straight back to the screen the user left. Skipped when
      // one is already showing, which would stack duplicates.
      if (_routeObserver.currentName != '/unlock') {
        _navigatorKey.currentState?.pushNamed('/unlock');
      }
    }
  }

  /// On background: with App Lock on and a wallet present, drop the in-memory
  /// password and arm a re-lock so the next resume returns to the lock screen.
  Future<void> _maybeArmRelock() async {
    _relockPending = await armAppLockRelock(context);
  }

  // Desktop has no background isolate to announce incoming txs, so the
  // foreground announces when the wallet's history grows. notifyNewIncomingTxs
  // is the decider (hash-based, net-receipt only, respects the notifications
  // toggle); the count is a cheap gate so unrelated notifications (connectivity,
  // balance) don't hit the keystore.
  void _announceNewTxsOnGrowth() {
    final wallet = _announceWallet;
    if (wallet == null) return;
    final count = wallet.txHistory.length;
    if (count <= _lastAnnouncedTxCount) return;
    _lastAnnouncedTxCount = count;
    unawaited(wallet.notifyNewIncomingTxs());
  }

  Future<List<Object>> _runStartup() {
    // Wallet existence drives the initial route; done quickly without a full load.
    final walletExists = startupWalletManager(context);
    return Future.wait([SharedPreferences.getInstance(), walletExists]);
  }

  @override
  Widget build(BuildContext context) {
    _startup ??= _runStartup();

    return Consumer2<LanguageModel, ThemeModel>(
      builder: (context, languageProvider, themeProvider, child) {
        final fiatRate = Provider.of<FiatRateModel>(context, listen: false);

        return FutureBuilder(
          future: _startup,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
              final sharedPreferences = snapshot.data![0] as SharedPreferences;
              final walletExists = snapshot.data![1] as bool;

              final theme = sharedPreferences.getString(SharedPreferencesKeys.theme) ?? 'system';

              final appLockEnabled =
                  sharedPreferences.getBool(SharedPreferencesKeys.appLockEnabled) ?? false;

              // A desktop OS asks for the typed password at every launch.
              final initialRoute = walletExists
                  ? appLockEnabled || isDesktopOS
                        ? '/unlock'
                        : '/wallet_home'
                  : '/welcome';

              if (!_startedServices) {
                _startedServices = true;
                _walletExists = walletExists;
                TorSettingsService.sharedInstance.loadSettings();
                TorService.sharedInstance.start();

                // Attach the manager once so the (multicoin) fiat model knows to
                // fetch XMR; every startService() afterwards can stay argless.
                attachFiatWalletManager(context);
                if (walletExists) {
                  fiatRate.startService();
                }

                // Desktop has no background isolate to announce incoming txs, so
                // the foreground announces on tx-history growth. Mobile announces
                // from its background isolates.
                if (isDesktopOS) {
                  _announceWallet = appWalletOf(context, listen: false)
                    ..addListener(_announceNewTxsOnGrowth);
                }
              }

              return MaterialApp(
                navigatorKey: _navigatorKey,
                navigatorObservers: [_routeObserver],
                title: 'Skylight Monero Wallet',
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: brandLightTheme(),
                darkTheme: brandDarkTheme(),
                themeMode: theme == 'dark'
                    ? ThemeMode.dark
                    : theme == 'light'
                    ? ThemeMode.light
                    : ThemeMode.system,
                // Pin brand tokens to the resolved brightness before any screen
                // builds; rebuild the navigator subtree in place on a real flip.
                builder: (context, child) {
                  final brightness = Theme.of(context).brightness;
                  BrandColors.setBrightness(brightness);
                  if (_lastBrightness != null && _lastBrightness != brightness) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final navContext = _navigatorKey.currentContext;
                      if (navContext is Element) navContext.visitChildElements(_markSubtreeDirty);
                    });
                  }
                  _lastBrightness = brightness;
                  // Brand-tone skeletons (the default grey clashes with the
                  // navy/orange scheme); tokens resolve to the current theme.
                  return SkeletonizerConfig(
                    data: SkeletonizerConfigData(
                      effect: SoldColorEffect(color: BrandColors.surfaceMuted),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                initialRoute: initialRoute,
                // Always boot through the resolved initial route; a cold-start deep
                // link arrives here, so capture a payment link for replay past the
                // lock and never let it become the initial route (which would race
                // boot/unlock and skip the lock). The `route` extra is ignored.
                onGenerateInitialRoutes: (deepLink) {
                  if (_isPaymentUri(deepLink)) _pendingPaymentUri = deepLink;
                  return [_onGenerateRoute(RouteSettings(name: initialRoute))!];
                },
                locale: Locale.fromSubtags(languageCode: languageProvider.language),
                onGenerateRoute: _onGenerateRoute,
              );
            }

            if (snapshot.hasError) {
              log(LogLevel.error, 'Startup failed: ${snapshot.error}');
            }

            return MaterialApp(
              title: 'Skylight Monero Wallet',
              theme: brandLightTheme(),
              darkTheme: brandDarkTheme(),
              themeMode: ThemeMode.system,
              builder: (context, child) {
                BrandColors.setBrightness(Theme.of(context).brightness);
                return Scaffold(backgroundColor: BrandColors.paper);
              },
            );
          },
        );
      },
    );
  }
}

/// A [MaterialPageRoute] whose own push/pop is instant — used for the bottom-nav
/// destinations so tapping a tab doesn't animate. Subclassing (rather than a bare
/// PageRouteBuilder) keeps Material's transition machinery, so the *secondary*
/// transition still plays when another screen is pushed over a nav screen.
class _NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  _NoTransitionPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;
}

/// Tracks the name of the route currently on top, so the re-lock does not stack
/// a second `/unlock` on one that is already showing.
class _CurrentRouteObserver extends NavigatorObserver {
  final ValueNotifier<String?> current = ValueNotifier<String?>(null);

  String? get currentName => current.value;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      current.value = route.settings.name;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      current.value = previousRoute?.settings.name;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      current.value = newRoute?.settings.name;
}
