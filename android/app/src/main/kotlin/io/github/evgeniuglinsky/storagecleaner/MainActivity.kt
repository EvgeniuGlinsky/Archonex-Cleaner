package io.github.evgeniuglinsky.storagecleaner

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * The one place this project registers native code of its own.
 *
 * Everything else the app talks to is a pub plugin and registers itself. These
 * two do not, because they are not plugins — they exist only for this
 * application, and the alternative was publishing a package to hold four files.
 * See `MediaTranscoder` for why the encoder is written at all, and
 * `RunNoticeService` for why the notification is.
 */
class MainActivity : FlutterActivity() {
    private var transcoder: MediaTranscoderChannel? = null
    private var notice: RunNoticeChannel? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        transcoder = MediaTranscoderChannel(engine.dartExecutor.binaryMessenger)
        notice = RunNoticeChannel(applicationContext, engine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(engine: FlutterEngine) {
        // The encoder holds a worker thread and two `MediaCodec` instances. An
        // activity that goes away without releasing them leaves the codec
        // hardware claimed, and the next app to want it is refused. The notice
        // holds a foreground service and a wake lock, which is worse.
        transcoder?.dispose()
        transcoder = null
        notice?.dispose()
        notice = null

        super.cleanUpFlutterEngine(engine)
    }
}
