import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // SCENE: with the UIScene lifecycle the app delegate has no window during
  // didFinishLaunching, so plugins registered via `self` would get no engine
  // (MissingPluginException in main() -> white screen). Run one explicit
  // engine here, register all plugins on it, and let SceneDelegate show it.
  lazy var flutterEngine = FlutterEngine(name: "attendix")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    // LIVE_ACTIVITY: Ablaufplan Live Activity channel (de.attendix/live_activity)
    // and push-token observer, also when iOS launches the app only in the background.
    if let registrar = flutterEngine.registrar(forPlugin: "LiveActivityPlugin") {
      LiveActivityPlugin.register(with: registrar)
    }
    LiveActivityTokenReporter.shared.start()
    // LIVE_ACTIVITY end
    // APP_ICON: home screen icon in the Farbwelt of the new design
    if let registrar = flutterEngine.registrar(forPlugin: "AppIconPlugin") {
      AppIconPlugin.register(with: registrar)
    }
    // MAC_FILES: iPhone/iPad app on an Apple silicon Mac (Ionic 4.17.20)
    if let registrar = flutterEngine.registrar(forPlugin: "PlatformInfoPlugin") {
      PlatformInfoPlugin.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// APP_ICON: switches the home screen icon (de.attendix/app_icon). The icons
// are alternate App Icon sets in Assets.xcassets (AppIconKonzertsaal …, build
// setting ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES); nil is the default
// icon. Dart side: lib/core/services/app_icon_service.dart.
public class AppIconPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "de.attendix/app_icon", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(AppIconPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "set" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let name = call.arguments as? String
    let app = UIApplication.shared
    guard app.supportsAlternateIcons else {
      result(false)
      return
    }
    // iOS shows a notice after every change: skip when nothing changes.
    if app.alternateIconName == name {
      result(true)
      return
    }
    app.setAlternateIconName(name) { error in
      DispatchQueue.main.async { result(error == nil) }
    }
  }
}
// APP_ICON end

// MAC_FILES: tells Dart whether the iPhone/iPad app runs on an Apple silicon
// Mac (de.attendix/platform_info), where the native file preview
// (UIDocumentInteractionController) shows nothing. Dart side:
// lib/core/services/native/native_platform.dart (isIosAppOnMac).
public class PlatformInfoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "de.attendix/platform_info", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(PlatformInfoPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "isiOSAppOnMac" else {
      result(FlutterMethodNotImplemented)
      return
    }
    result(ProcessInfo.processInfo.isiOSAppOnMac)
  }
}
// MAC_FILES end

// SCENE: iOS 27 SDK requires UIScene lifecycle adoption (apps without it trap
// on launch in _UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption).
// Flutter < 3.38 has no FlutterSceneDelegate, so this minimal delegate creates
// the window with a FlutterViewController on the app delegate's engine and
// hands the window to the app delegate, which plugins still read.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene,
      let appDelegate = UIApplication.shared.delegate as? AppDelegate
    else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = FlutterViewController(
      engine: appDelegate.flutterEngine, nibName: nil, bundle: nil)
    self.window = window
    appDelegate.window = window
    window.makeKeyAndVisible()
    if !connectionOptions.urlContexts.isEmpty {
      self.scene(scene, openURLContexts: connectionOptions.urlContexts)
    }
    for activity in connectionOptions.userActivities {
      self.scene(scene, continue: activity)
    }
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate else { return }
    for context in URLContexts {
      _ = appDelegate.application(UIApplication.shared, open: context.url, options: [:])
    }
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate else { return }
    _ = appDelegate.application(
      UIApplication.shared, continue: userActivity, restorationHandler: { _ in })
  }
}
// SCENE end
