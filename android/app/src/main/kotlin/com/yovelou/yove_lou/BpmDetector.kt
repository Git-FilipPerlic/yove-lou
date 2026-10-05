package com.yovelou.yove_lou

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.nio.ByteOrder
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** What we learn about a song: tempo, where the first beat is, and its loudness curve. */
class Analysis(
    val bpm: Double?,
    /** Seconds from the start of the song to the first beat. */
    val firstBeat: Double?,
    /** Loudness 0..1, [BpmDetector.ENV_RATE] values per second. */
    val env: FloatArray,
)

/**
 * Decodes up to 12 minutes of a song and works out:
 *  - a loudness curve (for the waveform),
 *  - the tempo and first-beat position, fitted against the first 4 minutes.
 */
object BpmDetector {
    const val ENV_RATE = 200 // curve samples per second
    private const val MAX_SECONDS = 720
    private const val FIT_SECONDS = 240
    private const val MAX_WALL_MS = 45_000L // stop decoding after this long, use what we have
    private const val MIN_BPM = 70.0
    private const val MAX_BPM = 180.0

    private class Curves(
        val full: DoubleArray,
        val low: DoubleArray,
        val loud: DoubleArray,
        val frames: Int,
    )

    fun analyze(path: String): Analysis? {
        val c = decode(path) ?: return null
        val env = normalise(c.loud, c.frames)
        if (c.frames < ENV_RATE * 10) return Analysis(null, null, env) // too short to judge

        // Onset = how much louder it just got, in either band.
        val n = min(c.frames, FIT_SECONDS * ENV_RATE)
        val raw = DoubleArray(n)
        for (i in 1 until n) {
            raw[i] = max(0.0, c.full[i] - c.full[i - 1]) + max(0.0, c.low[i] - c.low[i - 1])
        }
        val onset = detrend(raw)
        val rough = tempoFromOnsets(onset) ?: return Analysis(null, null, env)
        val (bpm, phase) = fitGrid(onset, rough)
        return Analysis((bpm * 10).roundToInt() / 10.0, phase / ENV_RATE, env)
    }

    // ------------------------------------------------------------- decoding

    private fun decode(path: String): Curves? {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(path)
            var format: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                    extractor.selectTrack(i)
                    format = f
                    break
                }
            }
            if (format == null) return null

            val mime = format.getString(MediaFormat.KEY_MIME)!!
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var hop = sampleRate / ENV_RATE.toDouble() // samples per curve frame (fractional)
            var samples = 0L

            val started = System.currentTimeMillis()
            val maxFrames = MAX_SECONDS * ENV_RATE
            val full = DoubleArray(maxFrames + 1) // energy of the sharp part
            val low = DoubleArray(maxFrames + 1) // energy of the bass part
            val loud = DoubleArray(maxFrames + 1) // plain loudness
            var frame = 0

            var prev = 0f
            var lp = 0f
            var accFull = 0.0
            var accLow = 0.0
            var accLoud = 0.0
            var count = 0

            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            while (!outputDone && frame < maxFrames &&
                System.currentTimeMillis() - started < MAX_WALL_MS
            ) {
                if (!inputDone) {
                    val i = codec.dequeueInputBuffer(10_000)
                    if (i >= 0) {
                        val buf = codec.getInputBuffer(i)!!
                        val n = extractor.readSampleData(buf, 0)
                        if (n < 0) {
                            codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(i, 0, n, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val o = codec.dequeueOutputBuffer(info, 10_000)
                if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val nf = codec.outputFormat
                    sampleRate = nf.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = nf.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    hop = sampleRate / ENV_RATE.toDouble()
                } else if (o >= 0) {
                    val out = codec.getOutputBuffer(o)!!
                    out.position(info.offset)
                    out.limit(info.offset + info.size)
                    val pcm = out.order(ByteOrder.nativeOrder()).asShortBuffer()
                    while (pcm.remaining() >= channels && frame < maxFrames) {
                        var x = 0f
                        for (c in 0 until channels) x += pcm.get()
                        x /= channels * 32768f
                        val d = x - prev // high-pass: keeps the sharp hits
                        prev = x
                        lp += 0.02f * (x - lp) // low-pass: keeps the kick
                        accFull += d * d
                        accLow += lp * lp
                        accLoud += x * x
                        count++
                        samples++
                        if (samples >= (frame + 1) * hop) {
                            full[frame] = ln(1.0 + 1000.0 * accFull / count)
                            low[frame] = ln(1.0 + 1000.0 * accLow / count)
                            loud[frame] = sqrt(accLoud / count)
                            frame++
                            accFull = 0.0
                            accLow = 0.0
                            accLoud = 0.0
                            count = 0
                        }
                    }
                    codec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                }
            }
            return Curves(full, low, loud, frame)
        } finally {
            try {
                codec?.stop()
            } catch (_: Exception) {
            }
            codec?.release()
            extractor.release()
        }
    }

    /** Scale loudness to 0..1 so the loud parts of the song fill the waveform. */
    private fun normalise(loud: DoubleArray, frames: Int): FloatArray {
        if (frames == 0) return FloatArray(0)
        val sorted = loud.copyOf(frames)
        sorted.sort()
        val top = max(sorted[(frames * 0.98).toInt().coerceAtMost(frames - 1)], 1e-6)
        return FloatArray(frames) { i -> min(1.0, sqrt(loud[i] / top)).toFloat() }
    }

    // --------------------------------------------------------------- tempo

    /** Remove the slow trend so only the beats stand out. */
    private fun detrend(raw: DoubleArray): DoubleArray {
        val n = raw.size
        val onset = DoubleArray(n)
        val w = ENV_RATE / 5
        var sum = 0.0
        for (i in 0 until n) {
            sum += raw[i]
            if (i >= 2 * w + 1) sum -= raw[i - 2 * w - 1]
            val mean = sum / min(i + 1, 2 * w + 1)
            onset[i] = max(0.0, raw[i] - mean)
        }
        return onset
    }

    /** Rough tempo: the delay at which the onset curve repeats itself. */
    private fun tempoFromOnsets(onset: DoubleArray): Double? {
        val n = onset.size
        val minLag = (ENV_RATE * 60.0 / MAX_BPM).toInt()
        val maxLag = (ENV_RATE * 60.0 / MIN_BPM).toInt()
        val acLen = maxLag * 2 + 2
        if (n < acLen * 2) return null
        val ac = DoubleArray(acLen)
        for (lag in minLag - 1 until acLen) {
            var s = 0.0
            for (i in 0 until n - lag) s += onset[i] * onset[i + lag]
            ac[lag] = s / (n - lag)
        }

        // Score each tempo: it should repeat at 1x and 2x the beat length.
        // A gentle bias toward 120 BPM settles ties between halves/doubles.
        var best = -1.0
        var bestLag = -1
        val score = DoubleArray(maxLag + 2)
        for (lag in minLag..maxLag) {
            val bpm = 60.0 * ENV_RATE / lag
            val prior = exp(-0.5 * square(ln(bpm / 120.0) / ln(2.0) / 0.9))
            score[lag] = (ac[lag] + 0.5 * ac[min(lag * 2, acLen - 1)]) * prior
            if (score[lag] > best) {
                best = score[lag]
                bestLag = lag
            }
        }
        if (bestLag < 0 || best <= 0.0) return null

        var lagF = bestLag.toDouble()
        if (bestLag > minLag && bestLag < maxLag) {
            val a = score[bestLag - 1]
            val b = score[bestLag]
            val c = score[bestLag + 1]
            val denom = a - 2 * b + c
            if (denom != 0.0) lagF += 0.5 * (a - c) / denom
        }

        var bpm = 60.0 * ENV_RATE / lagF
        while (bpm < MIN_BPM) bpm *= 2
        while (bpm > MAX_BPM) bpm /= 2
        return bpm
    }

    /**
     * Lays a grid of evenly spaced beats over the whole analysed stretch and
     * slides it (a little faster/slower, and earlier/later) until the beats
     * land on the loudest hits. Returns (bpm, first beat in curve frames).
     */
    private fun fitGrid(onset: DoubleArray, bpm0: Double): Pair<Double, Double> {
        val n = onset.size
        // Let a beat be off by one frame (5 ms) without penalty.
        val sm = DoubleArray(n) { i ->
            max(onset[i], max(if (i > 0) onset[i - 1] else 0.0, if (i < n - 1) onset[i + 1] else 0.0))
        }
        var bestScore = -1.0
        var bestBpm = bpm0
        var bestPhase = 0.0
        for (step in -40..40) { // +-2 % in 0.05 % steps
            val bpm = bpm0 * (1 + step * 0.0005)
            val period = 60.0 * ENV_RATE / bpm
            var phase = 0.0
            while (phase < period) {
                var s = 0.0
                var beats = 0
                var t = phase
                while (t < n) {
                    s += sm[t.toInt()]
                    beats++
                    t += period
                }
                val mean = if (beats > 0) s / beats else 0.0
                if (mean > bestScore) {
                    bestScore = mean
                    bestBpm = bpm
                    bestPhase = phase
                }
                phase += 1.0
            }
        }
        return Pair(bestBpm, bestPhase)
    }

    private fun square(x: Double) = x * x
}
