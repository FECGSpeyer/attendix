package de.attendix.attendix.liveplan

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import de.attendix.attendix.R
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * DB_REVIEW_REST (F2): port of Ionic android/.../liveplan/LivePlanNotifications.java.
 *
 * Ongoing notification of a running Ablaufplan, the Android counterpart of the
 * iOS Live Activity. On Android 16 it is requested as a promoted "Live Update"
 * (status bar chip). The state JSON matches LivePlanState in
 * supabase/functions/_shared/live-plan-state.ts (lib/core/utils/live_plan.dart).
 */
object LivePlanNotifications {

    const val CHANNEL_ID = "live_plan"
    const val TAG = "live-plan"

    /** Notification.EXTRA_REQUEST_PROMOTED_ONGOING (API 36), as a literal so older compile SDKs work. */
    private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"
    private const val TAIL_MS = 15L * 60L * 1000L
    private const val PROGRESS_MAX = 1000

    fun canPost(context: Context): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled()

    /** Same id as Ionic: Java String.hashCode of "attendanceId:planKey". */
    fun notificationId(attendanceId: Int, planKey: String): Int =
        "$attendanceId:$planKey".hashCode()

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.live_plan_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        channel.description = context.getString(R.string.live_plan_channel_description)
        channel.setSound(null, null)
        channel.enableVibration(false)
        channel.setShowBadge(false)
        manager.createNotificationChannel(channel)
    }

    private fun clock(epochSeconds: Double): String =
        SimpleDateFormat("HH:mm", Locale.GERMANY).format(Date((epochSeconds * 1000).toLong()))

    /** Posts or replaces the notification for one plan. */
    fun show(context: Context, attendanceId: Int, planKey: String, title: String, state: JSONObject) {
        if (!canPost(context)) return
        ensureChannel(context)
        val phase = state.optString("phase", "running")
        val index = state.optInt("index", 1)
        val total = state.optInt("total", 1)
        val next = state.optJSONArray("next")
        val planEnd = state.optDouble("planEnd", 0.0)
        val planStart = state.optDouble("planStart", 0.0)

        val first = if (next != null && next.length() > 0) next.optJSONObject(0) else null
        val nextLine = if (first != null) {
            context.getString(R.string.live_plan_next, first.optString("name"), clock(first.optDouble("at")))
        } else {
            context.getString(R.string.live_plan_next_end, clock(planEnd))
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_live_plan)
            .setSubText(title)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openIntent(context, attendanceId, planKey))

        when (phase) {
            "before" -> builder
                .setContentTitle(context.getString(R.string.live_plan_starts_at, clock(planStart)))
                .setContentText(context.getString(R.string.live_plan_first, state.optString("title")))
                .setOngoing(true)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
                .setShowWhen(true)
                .setWhen((planStart * 1000).toLong())
            "ended" -> builder
                .setContentTitle(context.getString(R.string.live_plan_ended))
                .setContentText(clock(planStart) + " – " + clock(planEnd))
                .setOngoing(false)
                .setAutoCancel(true)
                .setTimeoutAfter(TAIL_MS)
            else -> {
                val subtitle = state.optString("subtitle", "")
                val endsAt = state.optDouble("endsAt", 0.0)
                // Header: plan name and position, followed by the countdown.
                val position = context.getString(R.string.live_plan_position, index, maxOf(total, index))
                builder.setSubText(if (title.isEmpty()) position else "$title · $position")
                // Collapsed: what follows. Expanded: until when, then what follows.
                val body = context.getString(R.string.live_plan_until, clock(endsAt)) +
                    (if (subtitle.isEmpty()) "" else " · $subtitle")
                builder
                    .setContentTitle(state.optString("title"))
                    .setContentText(nextLine)
                    .setStyle(NotificationCompat.BigTextStyle().bigText(body + "\n" + nextLine))
                    .setOngoing(true)
                    .setUsesChronometer(true)
                    .setChronometerCountDown(true)
                    .setShowWhen(true)
                    .setWhen((endsAt * 1000).toLong())
                // Progress over the plan's time span, filled through the current item.
                val span = planEnd - planStart
                if (span > 0) {
                    val ratio = ((endsAt - planStart) / span).coerceIn(0.0, 1.0)
                    builder.setProgress(PROGRESS_MAX, Math.round(ratio * PROGRESS_MAX).toInt(), false)
                }
            }
        }
        if (phase != "ended") {
            // Drop it on its own if no "end" arrives (app killed, no network).
            builder.setTimeoutAfter(
                maxOf(60_000L, (planEnd * 1000).toLong() + TAIL_MS - System.currentTimeMillis())
            )
            builder.extras.putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
        }

        try {
            NotificationManagerCompat.from(context)
                .notify(TAG, notificationId(attendanceId, planKey), builder.build())
        } catch (e: SecurityException) {
            // Notification permission revoked meanwhile.
        }
    }

    fun cancel(context: Context, attendanceId: Int, planKey: String) {
        NotificationManagerCompat.from(context).cancel(TAG, notificationId(attendanceId, planKey))
    }

    fun cancelAll(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            for (entry in LivePlanTitles.all(context)) cancel(context, entry.attendanceId, entry.planKey)
            return
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        for (n in manager.activeNotifications) {
            if (TAG == n.tag) manager.cancel(TAG, n.id)
        }
    }

    /** Ids of the plan notifications currently shown (null below API 23: unknown). */
    fun activeIds(context: Context): Set<Int>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.activeNotifications.filter { TAG == it.tag }.map { it.id }.toSet()
    }

    /** Whether the notification of this plan is shown (below API 23: remembered titles). */
    fun isShown(context: Context, attendanceId: Int, planKey: String): Boolean {
        val ids = activeIds(context) ?: return LivePlanTitles.has(context, attendanceId, planKey)
        return ids.contains(notificationId(attendanceId, planKey))
    }

    private fun openIntent(context: Context, attendanceId: Int, planKey: String): PendingIntent {
        val intent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("attendix://live-plan?attendance=$attendanceId&plan=" + Uri.encode(planKey)),
        )
        intent.setPackage(context.packageName)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            notificationId(attendanceId, planKey),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
