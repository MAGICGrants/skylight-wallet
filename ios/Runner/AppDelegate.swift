import Flutter
import StoreKit
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var secureClipboardChannel: FlutterMethodChannel?
  private var storeReviewChannel: FlutterMethodChannel?
  private var hostPlatformChannel: FlutterMethodChannel?
  private var secureScreenChannel: FlutterMethodChannel?
  private var securityKeyChannel: SecurityKeyChannel?
  private var paymentLinks: PaymentLinks?
  private var sceneConnectObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The launch screen over the app whenever it is not active: the app
    // switcher, and the Face ID prompt on the way back (wallet_fhse's
    // apple/PrivacyCover.swift).
    PrivacyCover.shared.install()

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // Enable background fetch for workmanager
    UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

    // BGTaskScheduler requires every identifier to be registered before launch
    // finishes, and each must also appear in BGTaskSchedulerPermittedIdentifiers.
    // Whether either task is actually scheduled is decided in Dart, from the
    // connection the wallet is using.
    let bundleId = Bundle.main.bundleIdentifier ?? "org.magicgrants.skylightwallet"

    // Short opportunistic wake-up. iOS grants it roughly 30 seconds, so it is
    // only ever scheduled for an LWS connection on clearnet.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "\(bundleId).refresh",
      frequency: NSNumber(value: 15 * 60)
    )

    // Longer run, only while charging and idle. This is the one that can afford
    // a Tor bootstrap before syncing.
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "\(bundleId).processing")

    // On a Mac this build shows the desktop layout, which needs the same
    // minimum window as the macOS build (MainFlutterWindow.swift).
    if ProcessInfo.processInfo.isiOSAppOnMac {
      sceneConnectObserver = NotificationCenter.default.addObserver(
        forName: UIScene.willConnectNotification,
        object: nil,
        queue: .main
      ) { note in
        (note.object as? UIWindowScene)?.sizeRestrictions?.minimumSize =
          CGSize(width: 900, height: 640)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecureClipboard")
    if let messenger = registrar?.messenger() {
      // App-neutral name shared with wallet-core's SecureClipboard.
      let channel = FlutterMethodChannel(
        name: "org.magicgrants.wallet/secure_clipboard",
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { call, reply in
        guard call.method == "copySensitive" else {
          reply(FlutterMethodNotImplemented)
          return
        }
        let args = call.arguments as? [String: Any]
        let text = args?["text"] as? String ?? ""
        let seconds = (args?["clearAfterSeconds"] as? NSNumber)?.doubleValue ?? 60
        // localOnly keeps it off Universal Clipboard (Handoff); expirationDate
        // lets iOS clear it even if the app is no longer running.
        UIPasteboard.general.setItems(
          [["public.utf8-plain-text": text]],
          options: [
            .localOnly: true,
            .expirationDate: Date().addingTimeInterval(seconds),
          ]
        )
        reply(nil)
      }
      secureClipboardChannel = channel
    }

    let reviewRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "StoreReview")
    if let messenger = reviewRegistrar?.messenger() {
      // App-neutral name shared with wallet-core's StoreReview. iOS builds only
      // ship through App Store Connect, and in TestFlight the request is a
      // no-op by Apple's design, so there is no install source to check.
      let channel = FlutterMethodChannel(
        name: "org.magicgrants.wallet/store_review",
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { call, reply in
        switch call.method {
        case "isAvailable":
          reply(true)
        case "requestReview":
          reply(Self.requestReview())
        default:
          reply(FlutterMethodNotImplemented)
        }
      }
      storeReviewChannel = channel
    }

    let secureScreenRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecureScreen")
    if let messenger = secureScreenRegistrar?.messenger() {
      // App-neutral name shared with wallet-core's SecureScreenMixin. Keeps the
      // window out of screenshots and recordings while a secret is on screen
      // (wallet_fhse's apple/SecureScreen.swift).
      let channel = FlutterMethodChannel(
        name: "org.magicgrants.wallet/secure_screen",
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { call, reply in
        guard call.method == "setSecure" else {
          reply(FlutterMethodNotImplemented)
          return
        }
        let args = call.arguments as? [String: Any]
        SecureScreen.shared.setSecure(args?["secure"] as? Bool ?? false)
        reply(nil)
      }
      secureScreenChannel = channel
    }

    let hostRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "HostPlatform")
    if let messenger = hostRegistrar?.messenger() {
      // App-neutral name shared with wallet-core's HostPlatform. The App Store
      // offers this build on Apple silicon Macs, where Dart still reports iOS.
      let channel = FlutterMethodChannel(
        name: "org.magicgrants.wallet/host_platform",
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { call, reply in
        switch call.method {
        case "isIosAppOnMac":
          reply(ProcessInfo.processInfo.isiOSAppOnMac)
        default:
          reply(FlutterMethodNotImplemented)
        }
      }
      hostPlatformChannel = channel
    }

    let securityKeyRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecurityKey")
    if let messenger = securityKeyRegistrar?.messenger() {
      // FIDO2 security keys (YubiKit) for FHSE wallet-file encryption.
      securityKeyChannel = SecurityKeyChannel(messenger: messenger)
    }

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PaymentLinks") {
      // Payment links (monero:) for the Send form; see PaymentLinks.
      let links = PaymentLinks(messenger: registrar.messenger(), schemes: ["monero"])
      registrar.addSceneDelegate(links)
      registrar.addApplicationDelegate(links)
      paymentLinks = links
    }
  }

  /// Hands the request to StoreKit's own prompt, which decides whether to show
  /// it (at most three times a year) and never says whether it did.
  private static func requestReview() -> Bool {
    let scene = UIApplication.shared.connectedScenes
      .first { $0.activationState == .foregroundActive } as? UIWindowScene
    guard let scene else { return false }
    if #available(iOS 16.0, *) {
      AppStore.requestReview(in: scene)
    } else {
      SKStoreReviewController.requestReview(in: scene)
    }
    return true
  }
}

/// Payment links reach Dart over this channel and nowhere else; Dart holds them
/// until the user is past every lock (wallet_ui's PaymentLinkGate).
/// FlutterDeepLinkingEnabled is NO in Info.plist, so no URL can name a screen.
///
/// The link the app is launched with arrives with the scene's connection and
/// waits until Dart asks for it ("takeInitialLink"); later ones are sent as
/// they come.
final class PaymentLinks: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private static let channelName = "org.magicgrants.wallet/payment_links"
  /// Longer than any real payment link. Dart parses and checks it again.
  private static let maxLength = 2048

  private let schemes: Set<String>
  private let channel: FlutterMethodChannel
  private var pending: String?
  private var dartListening = false

  init(messenger: FlutterBinaryMessenger, schemes: Set<String>) {
    self.schemes = schemes
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, call.method == "takeInitialLink" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.dartListening = true
      result(self.pending)
      self.pending = nil
    }
  }

  /// Registered by AppDelegate, not by the plugin registrant.
  static func register(with registrar: FlutterPluginRegistrar) {}

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let context = connectionOptions?.urlContexts.first else { return false }
    return accept(context.url)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for context in URLContexts where accept(context.url) {
      handled = true
    }
    return handled
  }

  func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    accept(url)
  }

  /// Takes a link with one of [schemes], or refuses it.
  private func accept(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased(), schemes.contains(scheme) else { return false }
    let link = url.absoluteString
    guard link.count <= Self.maxLength else { return false }
    if dartListening {
      channel.invokeMethod("link", arguments: link)
    } else {
      pending = link
    }
    return true
  }
}
