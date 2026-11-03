package de.attendix.attendix

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import de.attendix.attendix.ionic.IonicSessionPlugin
import de.attendix.attendix.liveplan.LiveActivityPlugin
import io.flutter.embedding.engine.FlutterEngine

// NATIVE_MISC: AudioServiceActivity (a FlutterActivity) shares its engine with
// audio_service so lock-screen / notification media controls work.
class MainActivity : AudioServiceActivity() {
    // DB_REVIEW_REST (F2): Ablaufplan notification channel (Ionic LiveActivityPlugin)
    private var liveActivityPlugin: LiveActivityPlugin? = null
    // IONIC_SESSION: keep the Ionic login after the store update
    private var ionicSessionPlugin: IonicSessionPlugin? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDefaultNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        liveActivityPlugin?.dispose()
        liveActivityPlugin = LiveActivityPlugin(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        ).also { it.setLaunchIntent(intent) }
        ionicSessionPlugin?.dispose()
        ionicSessionPlugin =
            IonicSessionPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        liveActivityPlugin?.dispose()
        liveActivityPlugin = null
        ionicSessionPlugin?.dispose()
        ionicSessionPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        liveActivityPlugin?.onNewIntent(intent)
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
