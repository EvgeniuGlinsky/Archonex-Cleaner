package io.github.evgeniuglinsky.storagecleaner

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import android.view.Surface
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Re-encodes a video as HEVC through Android's own media stack.
 *
 * The first native code in this project, and it is here because nothing on pub
 * does this job. Every video-compression package available reduces the
 * *resolution* to get its savings, which is exactly the quality loss this
 * feature exists to avoid, and none of them will write HEVC — which is where
 * the forty per cent actually comes from. FFmpegKit, which would have, was
 * retired in January 2025.
 *
 * What it does and nothing more: extract, decode onto a surface, encode as
 * HEVC, mux. Same width, same height, same frame rate, audio and any other
 * track copied through byte for byte. It is handed two paths and asked for a
 * file; whether a file is worth encoding was settled in `SavingsEstimator`, and
 * what happens to the original is `IoMediaOptimizeRepo`'s and nothing to do
 * with this.
 *
 * A surface between the decoder and the encoder rather than byte buffers,
 * because it keeps the frames in graphics memory the whole way through. Copying
 * them out to YUV arrays and back would work and would also be slower than the
 * encode itself on most devices, and it would mean handling every colour format
 * a vendor decoder might choose to emit.
 */
class MediaTranscoder(
    private val onProgress: (Double) -> Unit,
) {
    /**
     * Set from the platform thread and read from the worker.
     *
     * Cooperative, checked once per frame: tearing a `MediaCodec` down from
     * another thread is undefined, and the loop notices within one frame
     * anyway.
     */
    private val cancelled = AtomicBoolean(false)

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun cancel() {
        cancelled.set(true)
    }

    /**
     * Stops whatever is running and gives the worker thread back.
     *
     * The cancel is not optional. `shutdownNow` interrupts the thread, and the
     * encode loop's only exit is `cancelled`, checked once per frame around
     * `MediaCodec.dequeue*` calls that do not answer to an interrupt. Without
     * the flag an activity being torn down could leave an encode running
     * against a muxer nobody is going to close.
     */
    fun release() {
        cancel()
        worker.shutdownNow()
    }

    /** Whether this device's chip offers an HEVC encoder at all. */
    fun hasHevcEncoder(): Boolean {
        val codecs = MediaCodecList(MediaCodecList.REGULAR_CODECS)

        return codecs.codecInfos.any { info ->
            info.isEncoder && info.supportedTypes.any { it.equals(HEVC, ignoreCase = true) }
        }
    }

    /**
     * Runs one transcode off the platform thread and answers [result] on it.
     *
     * Flutter's method channels must be replied to from the main thread, and
     * an hour-long encode on it would freeze the application for an hour.
     */
    fun transcode(
        input: String,
        output: String,
        targetBitsPerPixelPerFrame: Double,
        result: MethodChannel.Result,
    ) {
        worker.execute {
            // Reset here rather than in the calling thread. A `cancel()` that
            // arrives between the method call and the worker picking the job up
            // used to be wiped by a reset that ran after it, and the encode then
            // started with the flag it was told to stop by already cleared.
            cancelled.set(false)

            try {
                run(input, output, targetBitsPerPixelPerFrame)
                main.post { result.success(null) }
            } catch (error: Throwable) {
                // The partial output is deleted here rather than left for the
                // Dart side: the ladder above treats a thrown encode as "no
                // usable file exists", and leaving one would make that a lie.
                File(output).delete()
                main.post {
                    result.error("transcode_failed", error.message, null)
                }
            }
        }
    }

    private fun run(input: String, output: String, bitsPerPixelPerFrame: Double) {
        val extractor = MediaExtractor()
        extractor.setDataSource(input)

        val videoTrack = extractor.selectFirstTrack { it.startsWith("video/") }
            ?: throw IllegalStateException("No video track.")

        val sourceFormat = extractor.getTrackFormat(videoTrack)
        val width = sourceFormat.getInteger(MediaFormat.KEY_WIDTH)
        val height = sourceFormat.getInteger(MediaFormat.KEY_HEIGHT)
        val durationUs = sourceFormat.getLong(MediaFormat.KEY_DURATION)

        val muxer = MediaMuxer(output, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        // The display matrix, which is how a phone records a portrait video: the
        // frames are landscape and the container says to turn them. Dropped, and
        // every clip shot vertically comes back on its side.
        sourceFormat.optionalInteger(MediaFormat.KEY_ROTATION)?.let(muxer::setOrientationHint)

        var encoder: MediaCodec? = null
        var decoder: MediaCodec? = null
        var surface: Surface? = null

        try {
            val targetFormat = MediaFormat.createVideoFormat(HEVC, width, height).apply {
                setInteger(
                    MediaFormat.KEY_BIT_RATE,
                    targetBitRate(sourceFormat, width, height, bitsPerPixelPerFrame),
                )
                setInteger(MediaFormat.KEY_FRAME_RATE, sourceFormat.frameRateOrDefault())
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, KEYFRAME_SECONDS)
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
                )
            }

            encoder = MediaCodec.createEncoderByType(HEVC)
            encoder.configure(targetFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            surface = encoder.createInputSurface()
            encoder.start()

            decoder = MediaCodec.createDecoderByType(sourceFormat.getString(MediaFormat.KEY_MIME)!!)
            decoder.configure(sourceFormat, surface, null, 0)
            decoder.start()

            val videoOut = transcodeVideo(extractor, decoder, encoder, muxer, durationUs)

            // Every other track — audio, subtitles, timed metadata — copied
            // through without being touched. Re-encoding audio saves single
            // digits of megabytes on a file whose video is measured in
            // hundreds, and it is the one part of a recording where a loss is
            // heard rather than seen.
            copyOtherTracks(input, videoTrack, muxer)

            muxer.stop()
            require(videoOut > 0) { "No frames were written." }
        } finally {
            decoder?.runCatching { stop() }
            decoder?.release()
            encoder?.runCatching { stop() }
            encoder?.release()
            surface?.release()
            extractor.release()
            muxer.runCatching { release() }
        }
    }

    private fun transcodeVideo(
        extractor: MediaExtractor,
        decoder: MediaCodec,
        encoder: MediaCodec,
        muxer: MediaMuxer,
        durationUs: Long,
    ): Int {
        val info = MediaCodec.BufferInfo()
        var muxerTrack = -1
        var muxerStarted = false
        var written = 0
        var inputDone = false
        var decoderDone = false
        var lastReported = -1.0

        while (!cancelled.get()) {
            if (!inputDone) {
                val index = decoder.dequeueInputBuffer(TIMEOUT_US)

                if (index >= 0) {
                    val buffer = decoder.getInputBuffer(index)!!
                    val size = extractor.readSampleData(buffer, 0)

                    if (size < 0) {
                        decoder.queueInputBuffer(
                            index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                        )
                        inputDone = true
                    } else {
                        decoder.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
            }

            if (!decoderDone) {
                val index = decoder.dequeueOutputBuffer(info, TIMEOUT_US)

                if (index >= 0) {
                    val render = info.size > 0
                    decoder.releaseOutputBuffer(index, render)

                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        decoder.runCatching { signalEndOfInputStream() }
                        encoder.signalEndOfInputStream()
                        decoderDone = true
                    }
                }
            }

            val index = encoder.dequeueOutputBuffer(info, TIMEOUT_US)

            when {
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    // The real format arrives only once the encoder has seen a
                    // frame, and the muxer cannot be started before it has it.
                    muxerTrack = muxer.addTrack(encoder.outputFormat)
                    muxer.start()
                    muxerStarted = true
                }

                index >= 0 -> {
                    val buffer = encoder.getOutputBuffer(index)!!
                    val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0

                    if (!isConfig && info.size > 0 && muxerStarted) {
                        muxer.writeSampleData(muxerTrack, buffer, info)
                        written++

                        if (durationUs > 0) {
                            val fraction = (info.presentationTimeUs.toDouble() / durationUs)
                                .coerceIn(0.0, 1.0)

                            // One update per per cent. A callback per frame is
                            // thirty channel messages a second for an hour.
                            if (fraction - lastReported >= PROGRESS_STEP) {
                                lastReported = fraction
                                main.post { onProgress(fraction) }
                            }
                        }
                    }

                    encoder.releaseOutputBuffer(index, false)

                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        return written
                    }
                }
            }
        }

        throw InterruptedException("Cancelled.")
    }

    /**
     * Copies every track but the video one, sample for sample.
     *
     * A second extractor rather than rewinding the first: seeking one back to
     * the start after it has been read to the end is not something every
     * device's implementation does reliably, and a fresh one costs nothing.
     */
    private fun copyOtherTracks(input: String, videoTrack: Int, muxer: MediaMuxer) {
        val extractor = MediaExtractor()
        extractor.setDataSource(input)

        try {
            val buffer = ByteBuffer.allocate(COPY_BUFFER_BYTES)
            val info = MediaCodec.BufferInfo()

            for (track in 0 until extractor.trackCount) {
                if (track == videoTrack) {
                    continue
                }

                val format = extractor.getTrackFormat(track)
                val target = muxer.addTrack(format)

                extractor.selectTrack(track)

                while (!cancelled.get()) {
                    val size = extractor.readSampleData(buffer, 0)

                    if (size < 0) {
                        break
                    }

                    info.offset = 0
                    info.size = size
                    info.presentationTimeUs = extractor.sampleTime
                    info.flags = extractor.sampleFlags

                    muxer.writeSampleData(target, buffer, info)
                    extractor.advance()
                }

                extractor.unselectTrack(track)
            }
        } finally {
            extractor.release()
        }
    }

    /**
     * The bitrate to aim at, from the same figure the Dart side estimates with.
     *
     * `AppOptimizerPolicy.targetBitsPerPixelPerFrame` restated here rather than
     * passed across the channel, because the channel carries two paths and
     * nothing else — and a number that arrived as an argument would be one more
     * thing a caller could get wrong. The two are checked against each other by
     * the round trip in `integration_test/optimize_probe_test.dart`, which is
     * the only place either can be verified anyway.
     */
    private fun targetBitRate(
        source: MediaFormat,
        width: Int,
        height: Int,
        bitsPerPixelPerFrame: Double,
    ): Int {
        val frameRate = source.frameRateOrDefault()
        val target = (bitsPerPixelPerFrame * width * height * frameRate).toInt()

        return target.coerceAtLeast(MINIMUM_BIT_RATE)
    }

    private fun MediaFormat.frameRateOrDefault(): Int =
        optionalInteger(MediaFormat.KEY_FRAME_RATE) ?: DEFAULT_FRAME_RATE

    /**
     * `getInteger` throws on a key a vendor left out, and several of these are
     * genuinely optional.
     */
    private fun MediaFormat.optionalInteger(key: String): Int? =
        if (containsKey(key)) runCatching { getInteger(key) }.getOrNull() else null

    private fun MediaExtractor.selectFirstTrack(matches: (String) -> Boolean): Int? {
        for (track in 0 until trackCount) {
            val mime = getTrackFormat(track).getString(MediaFormat.KEY_MIME) ?: continue

            if (matches(mime)) {
                selectTrack(track)

                return track
            }
        }

        return null
    }

    // Not private any more: `DEFAULT_BITS_PER_PIXEL_PER_FRAME` is what the
    // channel below substitutes when Dart omits the target, so the channel has
    // to be able to read it.
    companion object {
        const val HEVC = MediaFormat.MIMETYPE_VIDEO_HEVC
        const val TIMEOUT_US = 10_000L
        const val COPY_BUFFER_BYTES = 1 shl 20
        const val KEYFRAME_SECONDS = 2
        const val DEFAULT_FRAME_RATE = 30
        const val PROGRESS_STEP = 0.01
        /**
         * What to aim at when Dart does not say.
         *
         * It used to be the only answer, restated here and in
         * `AppOptimizerPolicy` with an integration test comparing the two. The
         * user picks it now — see `OptimizeQuality` — so it arrives with the
         * call, and this is what a caller that omits it gets. Kept equal to the
         * balanced preset so that the fallback is the default rather than a
         * third setting nobody chose.
         */
        const val DEFAULT_BITS_PER_PIXEL_PER_FRAME = 0.05
        const val MINIMUM_BIT_RATE = 200_000
    }
}

/**
 * Wires [MediaTranscoder] to the two channels the Dart side talks over.
 *
 * A method channel for the work and an event channel for the progress, because
 * a method channel replies once and an encode wants to report for an hour.
 */
class MediaTranscoderChannel(
    messenger: io.flutter.plugin.common.BinaryMessenger,
) {
    private var events: EventChannel.EventSink? = null

    private val transcoder = MediaTranscoder { fraction -> events?.success(fraction) }

    private val methods = MethodChannel(
        messenger,
        "io.github.evgeniuglinsky.storagecleaner/transcoder",
    )
    private val progress = EventChannel(
        messenger,
        "io.github.evgeniuglinsky.storagecleaner/transcoder/progress",
    )

    init {
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasHevcEncoder" -> result.success(transcoder.hasHevcEncoder())

                "transcode" -> {
                    val input = call.argument<String>("input")
                    val output = call.argument<String>("output")
                    val target = call.argument<Double>("targetBitsPerPixelPerFrame")
                        ?: MediaTranscoder.DEFAULT_BITS_PER_PIXEL_PER_FRAME

                    if (input == null || output == null) {
                        result.error("bad_arguments", "input and output are required", null)
                    } else {
                        transcoder.transcode(input, output, target, result)
                    }
                }

                "cancel" -> {
                    transcoder.cancel()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        progress.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                events = sink
            }

            override fun onCancel(arguments: Any?) {
                events = null
            }
        })
    }

    fun dispose() {
        methods.setMethodCallHandler(null)
        progress.setStreamHandler(null)
        transcoder.release()
    }
}
