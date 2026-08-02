package io.github.evgeniuglinsky.storagecleaner

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Keeps a long run alive while the app is not on screen, and says so.
 *
 * Nothing in here does any work. The transcode runs where it always did, on
 * `MediaTranscoder`'s worker thread in this same process; what a foreground
 * service buys is that Android stops treating the process as idle. Without it,
 * a phone that has been put in a pocket freezes the app within minutes and the
 * encode simply stops — which is what a user who started an hour of work and
 * locked their screen actually experienced. Moving the encode into the service
 * would change nothing about that and would mean a second copy of the pipeline.
 *
 * `dataSync` is the service type, which is what Android calls processing the
 * user explicitly asked for. Android 15 caps it at six hours a day; a camera
 * roll does not come close, and the wake lock below carries the same ceiling so
 * that a run somehow left going cannot hold the CPU forever.
 *
 * Every string it displays arrives from Dart, already translated. The
 * alternative was a set of `strings.xml` resources, which would have followed
 * the *device* language — and this app has a language picker of its own, so a
 * Russian-speaking user on an English phone would have been reading English in
 * the shade while the app spoke Russian.
 */
class RunNoticeService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> show(intent)
            ACTION_CANCEL -> onStopPressed?.invoke()
            else -> stopEverything()
        }

        // Not restarted if the system kills us. The run died with the process,
        // and a notification that came back saying "compressing" over nothing
        // would be a lie with a Stop button on it.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    private fun show(intent: Intent) {
        val channelName = intent.getStringExtra(EXTRA_CHANNEL_NAME) ?: DEFAULT_CHANNEL_NAME
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        val text = intent.getStringExtra(EXTRA_TEXT).orEmpty()
        val stopLabel = intent.getStringExtra(EXTRA_STOP_LABEL).orEmpty()
        // Below zero means "no idea how far along", which is what an encode
        // reports before its first frame and what a photo reports throughout.
        val progress = intent.getIntExtra(EXTRA_PROGRESS, -1)

        createChannel(channelName)
        acquireWakeLock()

        val notification = build(title, text, stopLabel, progress)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopEverything() {
        releaseWakeLock()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }

        stopSelf()
    }

    private fun build(
        title: String,
        text: String,
        stopLabel: String,
        progress: Int,
    ): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_run_notice)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openTheApp())

        if (progress in 0..100) {
            builder.setProgress(100, progress, false)
        } else {
            builder.setProgress(0, 0, true)
        }

        if (stopLabel.isNotEmpty()) {
            builder.addAction(stopAction(stopLabel))
        }

        return builder.build()
    }

    /**
     * Tapping the notification brings the app back rather than starting it
     * again — the activity is `singleTop`, and the run is inside the process
     * already open.
     */
    private fun openTheApp(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java)
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)

        return PendingIntent.getActivity(this, 0, intent, immutable())
    }

    @Suppress("DEPRECATION")
    private fun stopAction(label: String): Notification.Action {
        val intent = Intent(this, RunNoticeService::class.java).setAction(ACTION_CANCEL)
        val pending = PendingIntent.getService(this, 1, intent, immutable())

        // The no-icon constructor is deprecated in favour of an `Icon`, which
        // needs API 23; the icon is not drawn on any modern Android anyway.
        return Notification.Action.Builder(0, label, pending).build()
    }

    private fun immutable(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

    /**
     * Created every time rather than once, because the name is the app's own
     * translation of it and the user can change the language mid-run. Calling
     * this again with the same id updates the name and nothing else.
     */
    private fun createChannel(name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            name,
            // Low: it is a progress bar, not news. Nothing here should ever
            // make a sound or push anything else out of the way.
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.setShowBadge(false)

        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) {
            return
        }

        val power = getSystemService(Context.POWER_SERVICE) as PowerManager

        wakeLock = power
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG)
            .apply { acquire(WAKE_LOCK_TIMEOUT_MS) }
    }

    private fun releaseWakeLock() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
    }

    companion object {
        const val ACTION_SHOW = "io.github.evgeniuglinsky.storagecleaner.RUN_NOTICE_SHOW"
        const val ACTION_HIDE = "io.github.evgeniuglinsky.storagecleaner.RUN_NOTICE_HIDE"
        const val ACTION_CANCEL = "io.github.evgeniuglinsky.storagecleaner.RUN_NOTICE_CANCEL"

        const val EXTRA_CHANNEL_NAME = "channelName"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_STOP_LABEL = "stopLabel"
        const val EXTRA_PROGRESS = "progress"

        /**
         * What the Stop button in the shade is wired to.
         *
         * A field on the companion rather than a broadcast, because there is
         * exactly one of each of these in one process: the service is not
         * declared with a `:process` of its own, and `RunNoticeChannel` is
         * built once per engine. `MainActivity` clears it on the way out.
         */
        var onStopPressed: (() -> Unit)? = null

        private const val CHANNEL_ID = "run_progress"
        private const val NOTIFICATION_ID = 1
        private const val DEFAULT_CHANNEL_NAME = "Progress"
        private const val WAKE_LOCK_TAG = "StorageCleaner:run"

        /**
         * Six hours, matching the daily ceiling Android 15 puts on a `dataSync`
         * service. A held-forever wake lock is the one way an app like this can
         * flatten a battery, and nothing it does legitimately runs this long.
         */
        private const val WAKE_LOCK_TIMEOUT_MS = 6L * 60L * 60L * 1000L
    }
}
