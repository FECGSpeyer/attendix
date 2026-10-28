package de.attendix.attendix

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity

// NATIVE_MISC: AudioServiceActivity (a FlutterActivity) shares its engine with
// audio_service so lock-screen / notification media controls work.
class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDefaultNotificationChannel()
    }

    // PUSH: the Edge Function send-push.ts sends Android pushes with
    // channel_id "default" (high priority). Without the channel Android would
    // fall back to the FCM "Miscellaneous" channel.
    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val manager = getSystemService(NotificationManager::class.java) ?: return
            if (manager.getNotificationChannel("default") != null) return
            val channel = NotificationChannel(
                "default",
                getString(R.string.push_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            )
            channel.setShowBadge(true)
            manager.createNotificationChannel(channel)
        } catch (e: Exception) {
            // Never crash the app because of the notification channel.
        }
    }
}
