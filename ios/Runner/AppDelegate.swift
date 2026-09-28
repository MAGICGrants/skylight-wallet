import Flutter
import StoreKit
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var secureClipboardChannel: FlutterMethodChannel?
  private var storeReviewChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecureClipboard")
    if let messenger = registrar?.messenger() {
      // App-neutral name shared with wallet-core's SecureClipboard (D10).
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
