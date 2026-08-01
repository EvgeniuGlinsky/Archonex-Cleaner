package com.archonex.cleaner

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * The one place this project registers native code of its own.
 *
 * Everything else the app talks to is a pub plugin and registers itself.
 * `MediaTranscoderChannel` does not, because it is not a plugin — it exists
 * only for this application, and the alternative was publishing a package to
 * hold two files. See `MediaTranscoder` for why they are written at all.
 */
class MainActivity : FlutterActivity() {
    private var transcoder: MediaTranscoderChannel? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        transcoder = MediaTranscoderChannel(engine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(engine: FlutterEngine) {
        // The encoder holds a worker thread and two `MediaCodec` instances. An
        // activity that goes away without releasing them leaves the codec
        // hardware claimed, and the next app to want it is refused.
        transcoder?.dispose()
        transcoder = null

        super.cleanUpFlutterEngine(engine)
    }
}
