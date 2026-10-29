import Flutter
import Foundation
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif

// LIVE_ACTIVITY: Flutter port of Ionic ios/App/App/LiveActivityPlugin.swift.
//
/// Starts, updates and ends the Ablaufplan Live Activity and reports the push
/// tokens the server needs (push-to-start per device, update token per activity).
/// Dart side: lib/core/services/live_activity_service.dart
/// (MethodChannel `de.attendix/live_activity`).
///
/// Dart → native: isAvailable, start, update, end, endAll, list, getTokens,
/// configure, setRegistrationOpen, takePendingUrl.
/// Native → Dart: pushToStartToken, activityToken, openUrl.
public class LiveActivityPlugin: NSObject, FlutterPlugin {
    static let channelName = "de.attendix/live_activity"

    private let channel: FlutterMethodChannel
    /// attendix://live-plan links that arrived before Dart asked for them (cold start).
    private var pendingUrl: String?
    private var dartReady = false

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = LiveActivityPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
        // Receives application(_:open:options:) for the widget's deep link.
        registrar.addApplicationDelegate(instance)
        instance.load()
    }

    private func load() {
        DispatchQueue.main.async {
            let reporter = LiveActivityTokenReporter.shared
            reporter.onPushToStartToken = { [weak self] token in
                self?.channel.invokeMethod("pushToStartToken", arguments: ["token": token])
            }
            reporter.onActivityToken = { [weak self] payload in
                self?.channel.invokeMethod("activityToken", arguments: payload)
            }
            reporter.start()
        }
    }

    // MARK: - Deep link from the Live Activity (attendix://live-plan?attendance=…&plan=…)

    public func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard url.scheme == "attendix", url.host == "live-plan" else { return false }
        if dartReady {
            channel.invokeMethod("openUrl", arguments: url.absoluteString)
        } else {
            pendingUrl = url.absoluteString
        }
        return true
    }

    // MARK: - Method calls

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "takePendingUrl":
            dartReady = true
            let url = pendingUrl
            pendingUrl = nil
            result(url)
        case "configure": configure(args, result)
        case "setRegistrationOpen": setRegistrationOpen(args, result)
        case "isAvailable": isAvailable(result)
        case "start": start(args, result)
        case "update": update(args, result)
        case "end": end(args, result)
        case "endAll": endAll(result)
        case "list": list(result)
        case "getTokens": getTokens(result)
        default: result(FlutterMethodNotImplemented)
        }
    }

    /// Results go back on the main thread (Task bodies run elsewhere).
    private func reply(_ result: @escaping FlutterResult, _ value: Any?) {
        DispatchQueue.main.async { result(value) }
    }

    private func reject(_ result: @escaping FlutterResult, _ message: String) {
        reply(result, FlutterError(code: "LIVE_ACTIVITY", message: message, details: nil))
    }

    /// Where the reporter sends update tokens while the app runs in the background.
    private func configure(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let url = args["url"] as? String, let key = args["key"] as? String else {
            return reject(result, "url and key are required")
        }
        LiveActivityTokenReporter.shared.configure(url: url, key: key)
        reply(result, nil)
    }

    /// SOL_FIX18: Dart's endSession (logout) closes the reporter's own token
    /// uploads and gets its reply only after the uploads already running have
    /// finished, so it can delete the token rows afterwards; init re-opens.
    private func setRegistrationOpen(_ args: [String: Any], _ result: @escaping FlutterResult) {
        let open = args["open"] as? Bool ?? true
        DispatchQueue.main.async {
            LiveActivityTokenReporter.shared.setUploadsOpen(open) {
                result(nil)
            }
        }
    }

    private func isAvailable(_ result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            var pushToStart = false
            if #available(iOS 17.2, *) { pushToStart = true }
            reply(result, [
                "available": ActivityAuthorizationInfo().areActivitiesEnabled,
                "pushToStart": pushToStart,
            ])
        } else {
            reply(result, ["available": false, "pushToStart": false])
        }
    }

    private func start(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else { return reject(result, "Live Activities need iOS 16.2") }
        guard let attendanceId = intArg(args["attendanceId"]),
              let planKey = args["planKey"] as? String,
              let title = args["title"] as? String,
              let state = decodeState(args) else {
            return reject(result, "attendanceId, planKey, title and state are required")
        }
        Task {
            if let existing = findActivity(attendanceId: attendanceId, planKey: planKey) {
                await existing.update(content(for: state))
                return reply(result, ["id": existing.id])
            }
            do {
                let attributes = PlanActivityAttributes(attendanceId: attendanceId, planKey: planKey, title: title)
                let activity = try Activity.request(attributes: attributes, content: content(for: state), pushType: .token)
                LiveActivityTokenReporter.shared.observeTokens(of: activity)
                reply(result, ["id": activity.id])
            } catch {
                reject(result, "Could not start Live Activity: \(error.localizedDescription)")
            }
        }
    }

    private func update(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else { return reject(result, "Live Activities need iOS 16.2") }
        guard let attendanceId = intArg(args["attendanceId"]),
              let planKey = args["planKey"] as? String,
              let state = decodeState(args) else {
            return reject(result, "attendanceId, planKey and state are required")
        }
        Task {
            guard let activity = findActivity(attendanceId: attendanceId, planKey: planKey) else {
                return reply(result, ["updated": false])
            }
            await activity.update(content(for: state))
            reply(result, ["updated": true])
        }
    }

    private func end(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else { return reply(result, nil) }
        guard let attendanceId = intArg(args["attendanceId"]),
              let planKey = args["planKey"] as? String else {
            return reject(result, "attendanceId and planKey are required")
        }
        let state = decodeState(args)
        let immediate = args["immediate"] as? Bool ?? false
        Task {
            if let activity = findActivity(attendanceId: attendanceId, planKey: planKey) {
                await activity.end(state.map { content(for: $0) }, dismissalPolicy: immediate ? .immediate : .default)
            }
            reply(result, nil)
        }
    }

    private func endAll(_ result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else { return reply(result, nil) }
        Task {
            for activity in Activity<PlanActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            reply(result, nil)
        }
    }

    private func list(_ result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else { return reply(result, ["activities": []]) }
        let items = Activity<PlanActivityAttributes>.activities
            .filter { $0.activityState == .active || $0.activityState == .stale }
            .map { ["id": $0.id, "attendanceId": $0.attributes.attendanceId, "planKey": $0.attributes.planKey] as [String: Any] }
        reply(result, ["activities": items])
    }

    private func getTokens(_ result: @escaping FlutterResult) {
        // The reporter's tokens are only touched on main.
        DispatchQueue.main.async {
            let reporter = LiveActivityTokenReporter.shared
            var value: [String: Any] = ["activityTokens": Array(reporter.activityTokens.values)]
            if let token = reporter.pushToStartToken { value["pushToStartToken"] = token }
            result(value)
        }
    }

    // MARK: - Helpers

    private func intArg(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    @available(iOS 16.2, *)
    private func findActivity(attendanceId: Int, planKey: String) -> Activity<PlanActivityAttributes>? {
        Activity<PlanActivityAttributes>.activities.first {
            $0.attributes.attendanceId == attendanceId && $0.attributes.planKey == planKey
                && ($0.activityState == .active || $0.activityState == .stale)
        }
    }

    @available(iOS 16.2, *)
    private func decodeState(_ args: [String: Any]) -> PlanActivityAttributes.ContentState? {
        guard let raw = args["state"] as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: raw) else { return nil }
        return try? JSONDecoder().decode(PlanActivityAttributes.ContentState.self, from: data)
    }

    /// Stale one minute after the current item should have ended; the widget then shows the overrun.
    @available(iOS 16.2, *)
    private func content(for state: PlanActivityAttributes.ContentState) -> ActivityContent<PlanActivityAttributes.ContentState> {
        let stale: Date?
        switch state.phase {
        case "before": stale = Date(timeIntervalSince1970: state.planStart + 60)
        case "running": stale = Date(timeIntervalSince1970: state.endsAt + 60)
        default: stale = nil
        }
        return ActivityContent(state: state, staleDate: stale)
    }
}

/// Observes Live Activity push tokens from app launch on, also when iOS only
/// wakes the app in the background after a push-to-start (no Flutter UI then).
/// Update tokens are sent straight to the `live-activity-token` Edge Function,
/// so the server can move the activity on without the app being opened.
/// All state is only read and written on the main thread.
/// (Unchanged from Ionic ios/App/App/LiveActivityPlugin.swift.)
final class LiveActivityTokenReporter {
    static let shared = LiveActivityTokenReporter()

    private static let urlKey = "liveActivity.apiUrl"
    private static let apiKeyKey = "liveActivity.apiKey"
    private static let startTokenKey = "liveActivity.pushToStartToken"
    private static let uploadsClosedKey = "liveActivity.uploadsClosed"

    /// Last known tokens, so Dart can read them after it attached its handler.
    private(set) var pushToStartToken: String?
    private(set) var activityTokens: [String: [String: Any]] = [:]
    var onPushToStartToken: ((String) -> Void)?
    var onActivityToken: (([String: Any]) -> Void)?
    private var observing = false
    private var observedActivities = Set<String>()
    /// SOL_FIX18: false after a logout until the next session's init (kept
    /// across launches, so a background wake after the logout uploads nothing).
    private var uploadsOpen: Bool
    /// SOL_FIX18: uploads that are still running.
    private let uploads = DispatchGroup()

    private init() {
        pushToStartToken = UserDefaults.standard.string(forKey: Self.startTokenKey)
        uploadsOpen = !UserDefaults.standard.bool(forKey: Self.uploadsClosedKey)
    }

    /// SOL_FIX18: called on main. Closing stops new uploads at once and calls
    /// `completion` (on main) when the running ones have finished.
    func setUploadsOpen(_ open: Bool, completion: @escaping () -> Void) {
        uploadsOpen = open
        UserDefaults.standard.set(!open, forKey: Self.uploadsClosedKey)
        if open {
            completion()
        } else {
            uploads.notify(queue: .main, execute: completion)
        }
    }

    func configure(url: String, key: String) {
        UserDefaults.standard.set(url, forKey: Self.urlKey)
        UserDefaults.standard.set(key, forKey: Self.apiKeyKey)
    }

    /// Called from AppDelegate on every launch and again by the plugin; runs once.
    func start() {
        guard #available(iOS 16.2, *) else { return }
        DispatchQueue.main.async { self.startObserving() }
    }

    @available(iOS 16.2, *)
    private func startObserving() {
        guard !observing else { return }
        observing = true
        for activity in Activity<PlanActivityAttributes>.activities {
            observeTokens(of: activity)
        }
        // Activities started by a push-to-start notification show up here.
        Task { @MainActor in
            for await activity in Activity<PlanActivityAttributes>.activityUpdates {
                // A push-to-start can race with a start from the open app: keep only the newest.
                for other in Activity<PlanActivityAttributes>.activities where other.id != activity.id
                    && other.attributes.attendanceId == activity.attributes.attendanceId
                    && other.attributes.planKey == activity.attributes.planKey {
                    await other.end(nil, dismissalPolicy: .immediate)
                }
                observeTokens(of: activity)
            }
        }
        if #available(iOS 17.2, *) {
            Task { @MainActor in
                for await data in Activity<PlanActivityAttributes>.pushToStartTokenUpdates {
                    let token = Self.hex(data)
                    pushToStartToken = token
                    UserDefaults.standard.set(token, forKey: Self.startTokenKey)
                    onPushToStartToken?(token)
                }
            }
        }
    }

    @available(iOS 16.2, *)
    func observeTokens(of activity: Activity<PlanActivityAttributes>) {
        DispatchQueue.main.async {
            guard self.observedActivities.insert(activity.id).inserted else { return }
            Task { @MainActor in
                for await data in activity.pushTokenUpdates {
                    let payload: [String: Any] = [
                        "attendanceId": activity.attributes.attendanceId,
                        "planKey": activity.attributes.planKey,
                        "token": Self.hex(data),
                    ]
                    self.activityTokens[activity.id] = payload
                    self.onActivityToken?(payload)
                    self.upload(payload)
                }
            }
        }
    }

    /// The server finds the user by this device's push-to-start token.
    private func upload(_ payload: [String: Any]) {
        guard uploadsOpen,
              let base = UserDefaults.standard.string(forKey: Self.urlKey),
              let key = UserDefaults.standard.string(forKey: Self.apiKeyKey),
              let startToken = pushToStartToken,
              let url = URL(string: "\(base)/functions/v1/live-activity-token") else { return }
        var body = payload
        body["startToken"] = startToken
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // Finish the request even if iOS only woke the app for this; end the task exactly once.
        var task: UIBackgroundTaskIdentifier = .invalid
        let finish = {
            guard task != .invalid else { return }
            UIApplication.shared.endBackgroundTask(task)
            task = .invalid
        }
        task = UIApplication.shared.beginBackgroundTask(expirationHandler: finish)
        let group = uploads
        group.enter()
        URLSession.shared.dataTask(with: request) { _, _, _ in
            group.leave()
            DispatchQueue.main.async(execute: finish)
        }.resume()
    }

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
