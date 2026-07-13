import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var secureClipboardChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // Enable background fetch for workmanager
    UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecureClipboard")
    if let messenger = registrar?.messenger() {
      let channel = FlutterMethodChannel(
        name: "org.magicgrants.skylight/secure_clipboard",
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
  }
}
