import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'package:skylight_wallet/screens/verify_seed.dart';
import 'package:skylight_wallet/screens/wallet_home.dart';
import 'package:skylight_wallet/screens/welcome.dart';
import 'package:skylight_wallet/screens/tor_settings.dart';
import 'package:skylight_wallet/screens/address_book.dart';
import 'package:skylight_wallet/screens/history.dart';
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
import 'package:skylight_wallet/route_policy.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:wallet_backup_platform/backup_ui.dart';
import 'package:wallet_domain/wallet_domain.dart' show AppSession, WalletManager, parsePaymentUri;
import 'package:wallet_fhse/security_keys_ui.dart';
import 'package:wallet_infra/wallet_infra.dart' show HostPlatform;

void main() async {
  // Catch all uncaught async errors
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Before the first frame: the layout reads it synchronously.
      await HostPlatform.init();

      installWalletCore();
      installSecurityKeysUi();
      installMetadataBackup();
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

      if (Platform.isLinux) {
        await createAppDir();
        NotificationService().init();
      }

      if (Platform.isWindows) {
        NotificationService().init();
      }

      // Before anything reads Sync Frequency: the tasks, the service, a wallet open.
      await migrateSyncSettings();

      if (Platform.isAndroid) {
        registerPeriodicTasks();
        startForegroundSyncIfEnabled();
        NotificationService().init();
      }

      if (Platform.isIOS) {
        await cleanTorDirectoriesOnIOS();
        // BGTaskScheduler windows under Sync Frequency; see wallet_background's
        // README.
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

class _AppRootState extends State<_AppRoot>
    with WidgetsBindingObserver, AppLockLifecycle<_AppRoot> {
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
  Brightness? _lastBrightness;

  // Every route the platform pushes is dropped; payment links (monero:) come
  // over PaymentLinkChannel instead and wait in the gate until the user is past
  // every lock (AppSession) and on a screen behind them.
  final _routeLinkBlocker = RouteLinkBlocker();
  late final PaymentLinkGate _paymentLinks;
  static const _paymentUriSchemes = {'monero'};

  static void _markSubtreeDirty(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markSubtreeDirty);
  }

  // The bottom-nav destinations. Tapping a nav tab must not animate, so these
  // get a zero-duration route in _onGenerateRoute.
  static const _noTransitionRoutes = {'/wallet_home', '/history', '/address_book', '/settings'};

  static final Map<String, WidgetBuilder> _routes = {
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
    '/security_key_unlock': (context) => const SecurityKeyUnlockScreen(),
    // Re-authenticates every time it opens: it can turn security keys off.
    '/advanced_security': (context) => const GuardedAdvancedSecurityScreen(),
    '/metadata_backup': (context) => const MetadataBackupScreen(),
    '/verify_seed': (context) => const VerifySeedScreen(),
    '/wallet_home': (context) => WalletHomeScreen(),
    '/settings': (context) => SettingsScreen(),
    '/lws_keys': (context) => AppLockGate(
      reason: AppLocalizations.of(context)!.settingsAppLockUnlockReason,
      child: LwsKeysScreen(),
    ),
    '/secret_keys': (context) => AppLockGate(
      reason: AppLocalizations.of(context)!.revealSeedAuthReason,
      child: SecretKeysScreen(),
    ),
    '/send': (context) => SendScreen(),
    '/scan_qr': (context) => ScanQrScreen(),
    '/receive': (context) => ReceiveScreen(),
    '/address_book': (context) => AddressBookScreen(),
    '/history': (context) => const HistoryScreen(),
    '/terms_of_service': (context) => TermsOfService(),
    '/privacy_policy': (context) => PrivacyPolicy(),
  };

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    // Deny by default (route_policy.dart): an unlisted route, or one behind the
    // locks while the app is locked, shows nothing and removes itself.
    final builder = _routes[settings.name];
    if (builder == null || !routePolicy.allows(settings.name, unlocked: AppSession.isUnlocked)) {
      return RefusedRoute(settings, listed: routePolicy.access.containsKey(settings.name));
    }
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
    assert(() {
      final c = routePolicy.check(_routes.keys);
      return c.unlisted.isEmpty && c.stale.isEmpty;
    }(), 'route_policy.dart does not match the routes');
    // Android: the Continuous Sync service and this app take turns holding the
    // wallets, never both at once; installed before anything opens.
    ForegroundSyncLink.install(Provider.of<WalletManager>(context, listen: false));
    // First, so it is asked before WidgetsApp's own observer and drops every
    // pushed route before WidgetsApp could turn it into a screen.
    WidgetsBinding.instance.addObserver(_routeLinkBlocker);
    WidgetsBinding.instance.addObserver(this);
    _paymentLinks = PaymentLinkGate(
      schemes: _paymentUriSchemes,
      unlocked: AppSession.unlocked,
      landing: _routeObserver.current,
      canLand: () => routePolicy.requiresUnlock(_routeObserver.currentName),
      open: _openPaymentUri,
    );
    unawaited(PaymentLinkChannel.listen(_paymentLinks.offer));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.removeObserver(_routeLinkBlocker);
    _paymentLinks.dispose();
    _announceWallet?.removeListener(_announceNewTxsOnGrowth);
    super.dispose();
  }

  /// Opens the Send form for a payment link the gate let through: the user is
  /// past every lock and on a screen behind them. It only pre-fills the form,
  /// which reviews and confirms the payment as always.
  void _openPaymentUri(String raw) {
    if (!mounted || !AppSession.isUnlocked) return;
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
    // Over whatever screen the user was on, so its back link says just "Back".
    final overlayContext = _navigatorKey.currentState?.overlay?.context;
    _navigatorKey.currentState?.pushNamed(
      '/send',
      arguments: SendScreenArgs(
        destinationAddress: request.address,
        amount: request.amount,
        backLabel: overlayContext == null ? null : AppLocalizations.of(overlayContext)?.back,
      ),
    );
  }

  // App Lock and the full locks (AppLockLifecycle) run on this navigator.
  @override
  NavigatorState? get appLockNavigator => _navigatorKey.currentState;

  @override
  String? get appLockTopRouteName => _routeObserver.currentName;

  @override
  Route<dynamic>? get appLockTopRoute => _routeObserver.top;

  /// Leaving the app marks everything on screen as seen so a background
  /// isolate won't re-notify a tx the user just watched arrive. Desktop has
  /// no background isolate — and doing this would pre-empt its foreground
  /// announce. Marks only synced history (hash-based), so an unsynced
  /// receipt is still announced later.
  @override
  void onMobilePaused() {
    unawaited(appWalletOf(context, listen: false).notifyNewIncomingTxs(announce: false));
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

              // App Lock at every launch (always on; the typed password on
              // Linux and Windows). With security keys on, a key comes next.
              final initialRoute = walletExists ? '/unlock' : '/welcome';

              if (!_startedServices) {
                _startedServices = true;
                // Only the built-in Tor is ours to start; external/disabled must
                // not spin up an embedded Tor, whose status would then misreport
                // the external proxy.
                unawaited(() async {
                  await TorSettingsService.sharedInstance.loadSettings();
                  if (TorSettingsService.sharedInstance.torMode == TorMode.builtIn) {
                    await TorService.sharedInstance.start();
                  }
                }());

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
                localizationsDelegates: const [
                  ...AppLocalizations.localizationsDelegates,
                  FhseLocalizations.delegate,
                  BackupLocalizations.delegate,
                ],
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
                  // App Lock's cover above the navigator; on a desktop OS,
                  // input anywhere counts as use for "Lock after".
                  return buildAppLock(
                    cover: (_) => UnlockScreen(
                      onUnlocked: hideAppLockCover,
                      onKeyNeeded: appLockCoverNeedsKey,
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                initialRoute: initialRoute,
                // Always boot through the resolved initial route. Whatever the
                // platform offers as a deep link is ignored: payment links
                // arrive over PaymentLinkChannel, and nothing else is taken.
                onGenerateInitialRoutes: (_) => [
                  _onGenerateRoute(RouteSettings(name: initialRoute))!,
                ],
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

  /// The top route itself.
  Route<dynamic>? top;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = route;
    current.value = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = previousRoute;
    current.value = previousRoute?.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    top = newRoute;
    current.value = newRoute?.settings.name;
  }

  /// A route taken out from under the top (a refused one removes itself).
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!identical(route, top)) return;
    top = previousRoute;
    current.value = previousRoute?.settings.name;
  }
}

/// Every route name the app defines, for test/route_policy_test.dart.
@visibleForTesting
Iterable<String> get appRouteNames => _AppRootState._routes.keys;
