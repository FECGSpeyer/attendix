package de.attendix.attendix.liveplan

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * DB_REVIEW_REST (F2): port of Ionic android/.../liveplan/LiveActivityPlugin.java
 * as a MethodChannel with the same API as ios/Runner/LiveActivityPlugin.swift
 * (channel `de.attendix/live_activity`), backed by an ongoing notification.
 * Android has no push tokens per activity: the server reaches the device via
 * its normal FCM token (see LivePlanMessagingService).
 */
class LiveActivityPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "de.attendix/live_activity"

        /** attendix://live-plan link of a notification tap. */
        fun livePlanUrl(intent: Intent?): String? {
            val data = intent?.data ?: return null
            if (data.scheme != "attendix" || data.host != "live-plan") return null
            return data.toString()
        }
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    /** Link that launched the app before Dart asked for it (cold start). */
    private var pendingUrl: String? = null

    init {
        channel.setMethodCallHandler(this)
    }

    /** Cold start: remember the link until Dart calls takePendingUrl. */
    fun setLaunchIntent(intent: Intent?) {
        livePlanUrl(intent)?.let { pendingUrl = it }
    }

    /** Warm start (onNewIntent): hand the link to Dart right away. */
    fun onNewIntent(intent: Intent?) {
        val url = livePlanUrl(intent) ?: return
        try {
            channel.invokeMethod("openUrl", url)
        } catch (e: Exception) {
            pendingUrl = url
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isAvailable" -> result.success(
                    mapOf(
                        "available" to LivePlanNotifications.canPost(context),
                        "pushToStart" to true,
                    )
                )
                "start" -> show(call, result, true)
                "update" -> show(call, result, false)
                "end" -> end(call, result)
                "endAll" -> {
                    LivePlanNotifications.cancelAll(context)
                    result.success(null)
                }
                "list" -> result.success(mapOf("activities" to list()))
                "getTokens" -> result.success(mapOf("activityTokens" to emptyList<Any>()))
                // iOS only (background token upload); nothing to do on Android.
                "configure" -> result.success(null)
                "takePendingUrl" -> {
                    val url = pendingUrl
                    pendingUrl = null
                    result.success(url)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("live_activity", e.message, null)
        }
    }

    private fun stateOf(call: MethodCall): JSONObject? {
        val raw = call.argument<Map<String, Any?>>("state") ?: return null
        return JSONObject(raw)
    }

    private fun show(call: MethodCall, result: MethodChannel.Result, isStart: Boolean) {
        val attendanceId = call.argument<Number>("attendanceId")?.toInt()
        val planKey = call.argument<String>("planKey")
        val state = stateOf(call)
        if (attendanceId == null || planKey == null || state == null) {
            result.error("invalid_args", "attendanceId, planKey and state are required", null)
            return
        }
        var title = call.argument<String>("title") ?: ""
        val shown = LivePlanNotifications.isShown(context, attendanceId, planKey)
        if (!isStart && !shown) {
            result.success(mapOf("updated" to false))
            return
        }
        if (!isStart) {
            title = LivePlanTitles.get(context, attendanceId, planKey, title)
        } else {
            LivePlanTitles.put(context, attendanceId, planKey, title)
        }
        LivePlanNotifications.show(context, attendanceId, planKey, title, state)
        result.success(mapOf("id" to "$attendanceId:$planKey", "updated" to true))
    }

    private fun end(call: MethodCall, result: MethodChannel.Result) {
        val attendanceId = call.argument<Number>("attendanceId")?.toInt()
        val planKey = call.argument<String>("planKey")
        if (attendanceId == null || planKey == null) {
            result.error("invalid_args", "attendanceId and planKey are required", null)
            return
        }
        val state = stateOf(call)
        val immediate = call.argument<Boolean>("immediate") ?: false
        if (state != null && !immediate) {
            LivePlanNotifications.show(
                context,
                attendanceId,
                planKey,
                LivePlanTitles.get(context, attendanceId, planKey, ""),
                state,
            )
        } else {
            LivePlanNotifications.cancel(context, attendanceId, planKey)
            LivePlanTitles.remove(context, attendanceId, planKey)
        }
        result.success(null)
    }

    private fun list(): List<Map<String, Any>> =
        LivePlanTitles.all(context)
            .filter { LivePlanNotifications.isShown(context, it.attendanceId, it.planKey) }
            .map {
                mapOf(
                    "id" to "${it.attendanceId}:${it.planKey}",
                    "attendanceId" to it.attendanceId,
                    "planKey" to it.planKey,
                )
            }
}
