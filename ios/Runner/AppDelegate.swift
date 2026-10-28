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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

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
