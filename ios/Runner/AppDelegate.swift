import Flutter
import UIKit
import WebKit

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
    // IONIC_SESSION: keep the Ionic login after the store update
    if let registrar = flutterEngine.registrar(forPlugin: "IonicSessionPlugin") {
      IonicSessionPlugin.register(with: registrar)
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
    switch call.method {
    case "isiOSAppOnMac":
      result(ProcessInfo.processInfo.isiOSAppOnMac)
    case "appVersion":
      // STORE_UPDATE: installed version (--build-name) for the update check
      result(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
    default:
      result(FlutterMethodNotImplemented)
    }
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


// IONIC_SESSION: one-time takeover of the Ionic login after the store update
// to the Flutter app (same bundle id io.stephanus.attendix). The Ionic app
// (Capacitor) kept the Supabase session in the WebView localStorage of
// capacitor://localhost. A hidden WKWebView on the same (default) data store
// opens that origin through its own scheme handler and reads the keys
// `sb-<ref>-auth-token` and `currentTenantId`. Channel de.attendix/ionic_session,
// method "read" -> JSON string of those keys (or nil). Dart side:
// lib/core/services/native/ionic_session_takeover.dart.
public class IonicSessionPlugin: NSObject, FlutterPlugin {
  private var reader: IonicStorageReader?
  // IONIC_QUEUE: separate reader (own hidden WebView), never shared with the
  // session read above.
  private var queueReader: IonicOfflineQueueReader?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "de.attendix/ionic_session", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(IonicSessionPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "readOfflineQueue" {
      readOfflineQueue(result: result)
      return
    }
    guard call.method == "read" else {
      result(FlutterMethodNotImplemented)
      return
    }
    // A second read while one is running: an error, not "empty" (Dart would
    // end the takeover for good on nil).
    guard reader == nil else {
      result(FlutterError(code: "busy", message: "read already running", details: nil))
      return
    }
    let reader = IonicStorageReader()
    self.reader = reader
    reader.read { [weak self] value in
      self?.reader = nil
      result(value)
    }
  }

  private func readOfflineQueue(result: @escaping FlutterResult) {
    guard queueReader == nil else {
      result(FlutterError(code: "busy", message: "read already running", details: nil))
      return
    }
    let reader = IonicOfflineQueueReader()
    queueReader = reader
    reader.read { [weak self] value in
      self?.queueReader = nil
      result(value)
    }
  }
}

final class IonicStorageReader: NSObject, WKNavigationDelegate, WKURLSchemeHandler {
  private static let script = """
    (function () {
      var out = {};
      for (var i = 0; i < localStorage.length; i++) {
        var k = localStorage.key(i);
        if ((k.indexOf('sb-') === 0 && k.slice(-11) === '-auth-token') || k === 'currentTenantId') {
          out[k] = localStorage.getItem(k);
        }
      }
      return JSON.stringify(out);
    })();
    """

  private var webView: WKWebView?
  // String (the keys as JSON) or FlutterError when the origin could not be read.
  private var completion: ((Any?) -> Void)?

  func read(completion: @escaping (Any?) -> Void) {
    self.completion = completion
    let config = WKWebViewConfiguration()
    // Same store as Capacitor's WKWebView (WKWebsiteDataStore.default()).
    config.websiteDataStore = WKWebsiteDataStore.default()
    config.setURLSchemeHandler(self, forURLScheme: "capacitor")
    let webView = WKWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = self
    self.webView = webView
    webView.load(URLRequest(url: URL(string: "capacitor://localhost/")!))
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
      self?.finish(Self.unavailable("timeout"))
    }
  }

  private static func unavailable(_ reason: String) -> FlutterError {
    FlutterError(code: "unavailable", message: reason, details: nil)
  }

  private func finish(_ value: Any?) {
    guard let completion = completion else { return }
    self.completion = nil
    webView?.navigationDelegate = nil
    webView?.stopLoading()
    webView = nil
    completion(value)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    webView.evaluateJavaScript(Self.script) { [weak self] value, _ in
      self?.finish((value as? String) ?? Self.unavailable("script"))
    }
  }

  func webView(
    _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
  ) {
    finish(Self.unavailable(error.localizedDescription))
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    finish(Self.unavailable(error.localizedDescription))
  }

  // Empty page for capacitor://localhost/ – only the origin matters.
  func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    let data = Data("<!doctype html><html><body></body></html>".utf8)
    let response = URLResponse(
      url: urlSchemeTask.request.url ?? URL(string: "capacitor://localhost/")!,
      mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8")
    urlSchemeTask.didReceive(response)
    urlSchemeTask.didReceive(data)
    urlSchemeTask.didFinish()
  }

  func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
// IONIC_SESSION end

// IONIC_QUEUE: the Ionic app's unsent offline writes (OfflineQueueService,
// @ionic/storage-angular via localforage: IndexedDB `_ionicstorage`, object
// store `_ionickv`, key `offline_writes_v1`). Read once in a hidden WKWebView
// of its own on capacitor://localhost, after (and independent of) the session
// read. Channel de.attendix/ionic_session, method "readOfflineQueue" -> JSON
// string `{"value": <stored value or null>}`; a missing database or key is
// `null`, not an error. The Ionic data is only read, never changed. Dart
// side: lib/core/services/native/ionic_offline_queue_takeover.dart.
final class IonicOfflineQueueReader: NSObject, WKNavigationDelegate, WKURLSchemeHandler {
  // Body of an async function (callAsyncJavaScript awaits the promise).
  private static let script = "return (\(ionicOfflineQueueReadFunction))();"

  private var webView: WKWebView?
  private var completion: ((Any?) -> Void)?

  func read(completion: @escaping (Any?) -> Void) {
    self.completion = completion
    let config = WKWebViewConfiguration()
    config.websiteDataStore = WKWebsiteDataStore.default()
    config.setURLSchemeHandler(self, forURLScheme: "capacitor")
    let webView = WKWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = self
    self.webView = webView
    webView.load(URLRequest(url: URL(string: "capacitor://localhost/")!))
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
      self?.finish(Self.unavailable("timeout"))
    }
  }

  private static func unavailable(_ reason: String) -> FlutterError {
    FlutterError(code: "unavailable", message: reason, details: nil)
  }

  private func finish(_ value: Any?) {
    guard let completion = completion else { return }
    self.completion = nil
    webView?.navigationDelegate = nil
    webView?.stopLoading()
    webView = nil
    completion(value)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    webView.callAsyncJavaScript(Self.script, arguments: [:], in: nil, in: .page) {
      [weak self] result in
      switch result {
      case .success(let value):
        self?.finish((value as? String) ?? Self.unavailable("script"))
      case .failure(let error):
        self?.finish(Self.unavailable(error.localizedDescription))
      }
    }
  }

  func webView(
    _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
  ) {
    finish(Self.unavailable(error.localizedDescription))
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    finish(Self.unavailable(error.localizedDescription))
  }

  func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    let data = Data("<!doctype html><html><body></body></html>".utf8)
    let response = URLResponse(
      url: urlSchemeTask.request.url ?? URL(string: "capacitor://localhost/")!,
      mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8")
    urlSchemeTask.didReceive(response)
    urlSchemeTask.didReceive(data)
    urlSchemeTask.didFinish()
  }

  func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

// JS function returning a promise of the JSON string. Opening a database that
// does not exist would create it: the upgrade is aborted instead (nothing is
// created, the result is null). Falls back to localforage's localStorage
// driver key.
let ionicOfflineQueueReadFunction = """
  function () {
    var KEY = 'offline_writes_v1';
    function local() {
      try { return localStorage.getItem('_ionicstorage/_ionickv/' + KEY); } catch (e) { return null; }
    }
    function idb() {
      return new Promise(function (resolve, reject) {
        if (!window.indexedDB) { resolve(null); return; }
        var created = false;
        var req = indexedDB.open('_ionicstorage');
        req.onupgradeneeded = function () { created = true; req.transaction.abort(); };
        req.onerror = function (event) {
          if (event && event.preventDefault) event.preventDefault();
          if (created) resolve(null); else reject(new Error('open: ' + req.error));
        };
        req.onsuccess = function () {
          var db = req.result;
          try {
            if (!db.objectStoreNames.contains('_ionickv')) { db.close(); resolve(null); return; }
            var get = db.transaction('_ionickv', 'readonly').objectStore('_ionickv').get(KEY);
            get.onsuccess = function () { db.close(); resolve(get.result === undefined ? null : get.result); };
            get.onerror = function () { db.close(); reject(new Error('get: ' + get.error)); };
          } catch (e) { db.close(); reject(e); }
        };
      });
    }
    return idb().then(function (value) {
      if (value === null || value === undefined) value = local();
      return JSON.stringify({ value: value === undefined ? null : value });
    });
  }
  """
// IONIC_QUEUE end
