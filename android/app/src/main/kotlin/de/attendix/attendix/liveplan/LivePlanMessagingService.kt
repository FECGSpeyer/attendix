package de.attendix.attendix.liveplan

import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import org.json.JSONException
import org.json.JSONObject

/**
 * DB_REVIEW_REST (F2): port of Ionic LivePlanMessagingService.java.
 *
 * Replaces the firebase_messaging plugin's service (see AndroidManifest.xml) so
 * silent "live_plan" data messages from the `live-activity-tick` Edge Function
 * update the plan notification even while the app is closed. Every other
 * message goes through the plugin exactly as before.
 */
class LivePlanMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        if (data["type"] != "live_plan") {
            super.onMessageReceived(remoteMessage)
            return
        }
        try {
            val attendanceId = data["attendanceId"]?.toInt() ?: return
            val planKey = data["planKey"] ?: return
            val event = data["event"]
            val title = data["title"] ?: ""
            val rawState = data["state"]
            if (event == "end" && rawState == null) {
                LivePlanNotifications.cancel(this, attendanceId, planKey)
                return
            }
            if (rawState == null) return
            val state = JSONObject(rawState)
            LivePlanTitles.put(this, attendanceId, planKey, title)
            LivePlanNotifications.show(this, attendanceId, planKey, title, state)
        } catch (e: NumberFormatException) {
            // Malformed message; ignore.
        } catch (e: JSONException) {
            // Malformed message; ignore.
        }
    }
}
