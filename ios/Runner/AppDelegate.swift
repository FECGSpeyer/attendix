import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // LIVE_ACTIVITY: Ablaufplan Live Activity channel (de.attendix/live_activity)
    // and push-token observer, also when iOS launches the app only in the background.
    if let registrar = self.registrar(forPlugin: "LiveActivityPlugin") {
      LiveActivityPlugin.register(with: registrar)
    }
    LiveActivityTokenReporter.shared.start()
    // LIVE_ACTIVITY end
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// SCENE: iOS 27 SDK requires UIScene lifecycle adoption (apps without it trap
// on launch in _UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption).
// Flutter < 3.38 has no FlutterSceneDelegate, so this minimal delegate loads
// Main.storyboard via the scene manifest and hands the window to the app
// delegate, which plugins still read.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    (UIApplication.shared.delegate as? FlutterAppDelegate)?.window = window
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
