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

/**
 * Finds a song's tempo. Decodes ~45 s from the first part of the track,
 * turns it into an "onset" curve (where the beats hit), then looks for the
 * delay at which that curve repeats itself (autocorrelation).
 */
object BpmDetector {
    private const val ENV_RATE = 200 // onset curve samples per second
    private const val WINDOW_S = 45
    private const val MIN_BPM = 70.0
    private const val MAX_BPM = 180.0

    fun detect(path: String): Double? {
        val onset = onsetCurve(path) ?: return null
        if (onset.size < ENV_RATE * 10) return null // too short to judge
        return tempoFromOnsets(onset)
    }

    // ------------------------------------------------------------- decoding

    private fun onsetCurve(path: String): DoubleArray? {
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

            val durationUs =
                if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else 0L
            // Skip intros: start 30 s in, or a quarter of the way for short songs.
            val startUs = if (durationUs > 0) min(30_000_000L, durationUs / 4) else 0L
            if (startUs > 0) extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

            val mime = format.getString(MediaFormat.KEY_MIME)!!
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var hop = sampleRate / ENV_RATE

            val maxFrames = WINDOW_S * ENV_RATE
            val full = DoubleArray(maxFrames + 1) // energy of the sharp part
            val low = DoubleArray(maxFrames + 1) // energy of the bass part
            var frame = 0

            var prev = 0f
            var lp = 0f
            var accFull = 0.0
            var accLow = 0.0
            var count = 0

            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            while (!outputDone && frame < maxFrames) {
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
                    hop = sampleRate / ENV_RATE
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
                        count++
                        if (count >= hop) {
                            full[frame] = ln(1.0 + 1000.0 * accFull / count)
                            low[frame] = ln(1.0 + 1000.0 * accLow / count)
                            frame++
                            accFull = 0.0
                            accLow = 0.0
                            count = 0
                        }
                    }
                    codec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                }
            }

            // Onset = how much louder it just got, in either band.
            val onset = DoubleArray(frame)
            for (i in 1 until frame) {
                onset[i] = max(0.0, full[i] - full[i - 1]) + max(0.0, low[i] - low[i - 1])
            }
            return onset
        } finally {
            try {
                codec?.stop()
            } catch (_: Exception) {
            }
            codec?.release()
            extractor.release()
        }
    }

    // --------------------------------------------------------------- tempo

    private fun tempoFromOnsets(raw: DoubleArray): Double? {
        val n = raw.size

        // Remove the slow trend so only the beats stand out.
        val onset = DoubleArray(n)
        val w = ENV_RATE / 5
        var sum = 0.0
        for (i in 0 until n) {
            sum += raw[i]
            if (i >= 2 * w + 1) sum -= raw[i - 2 * w - 1]
            val mean = sum / min(i + 1, 2 * w + 1)
            onset[i] = max(0.0, raw[i] - mean)
        }

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

        // Sharpen the peak between samples (parabola through its neighbours).
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
        return (bpm * 10).roundToInt() / 10.0
    }

    private fun square(x: Double) = x * x
}
