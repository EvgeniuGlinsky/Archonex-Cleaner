package io.github.evgeniuglinsky.storagecleaner

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Dart side's handle on [RunNoticeService].
 *
 * The same two-channel shape as `MediaTranscoderChannel` and for the same
 * reason: a method channel answers once, and the Stop button in the shade can
 * be pressed at any point in an hour.
 *
 * Everything shown to the user is passed in from Dart, already translated —
 * see the service for why it is not in `res/values-*`.
 */
class RunNoticeChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private var events: EventChannel.EventSink? = null

    private val methods = MethodChannel(messenger, "$NAMESPACE/run_notice")
    private val actions = EventChannel(messenger, "$NAMESPACE/run_notice/actions")

    init {
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    show(call)
                    result.success(null)
                }

                "hide" -> {
                    send(Intent(context, RunNoticeService::class.java).setAction(HIDE))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        actions.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                events = sink
                RunNoticeService.onStopPressed = { events?.success(STOP) }
            }

            override fun onCancel(arguments: Any?) {
                events = null
                RunNoticeService.onStopPressed = null
            }
        })
    }

    private fun show(call: MethodCall) {
        val intent = Intent(context, RunNoticeService::class.java)
            .setAction(RunNoticeService.ACTION_SHOW)
            .putExtra(RunNoticeService.EXTRA_CHANNEL_NAME, call.argument<String>("channelName"))
            .putExtra(RunNoticeService.EXTRA_TITLE, call.argument<String>("title"))
            .putExtra(RunNoticeService.EXTRA_TEXT, call.argument<String>("text"))
            .putExtra(RunNoticeService.EXTRA_STOP_LABEL, call.argument<String>("stopLabel"))
            .putExtra(RunNoticeService.EXTRA_PROGRESS, call.argument<Int>("progress") ?: -1)

        send(intent)
    }

    /**
     * `startForegroundService` from Android 8, and the service has five seconds
     * to call `startForeground` or the system kills the app. It does so on the
     * first thing it handles, which is this.
     */
    private fun send(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    fun dispose() {
        methods.setMethodCallHandler(null)
        actions.setStreamHandler(null)
        RunNoticeService.onStopPressed = null
        // The engine is going away, so nothing is left to report progress or to
        // answer a Stop. Leaving a notification on the shade over a dead run
        // would be a lie with a button on it.
        send(Intent(context, RunNoticeService::class.java).setAction(HIDE))
    }

    private companion object {
        const val NAMESPACE = "io.github.evgeniuglinsky.storagecleaner"
        const val HIDE = RunNoticeService.ACTION_HIDE
        const val STOP = "stop"
    }
}
