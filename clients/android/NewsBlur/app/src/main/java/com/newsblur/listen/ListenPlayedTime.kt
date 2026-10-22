package com.newsblur.listen

import java.math.BigDecimal

/**
 * ListenPlayedTime.kt counts how much of a story's audio timeline actually played, for POST /listen/progress.
 * ListenManager.kt samples the timeline position while a story is loaded. The advance between two samples counts
 * only when playing could have covered it in the wall time between them at the current speed, so seeks, skips
 * and scrubbing never count, and paused or buffering time adds nothing because the position holds still.
 */
class ListenPlayedTime {
    private var lastPositionMs = NO_POSITION
    private var lastRealtimeMs = 0L
    private var playedMs = 0L

    /** Milliseconds of the timeline played since the last report. */
    val pendingMs: Long
        get() = playedMs

    fun sample(
        positionMs: Long,
        realtimeMs: Long,
        speed: Double,
    ) {
        if (lastPositionMs != NO_POSITION) {
            val advance = positionMs - lastPositionMs
            val elapsedMs = (realtimeMs - lastRealtimeMs).coerceAtLeast(0L)
            val rate = speed.coerceIn(ListenSpeed.MIN, ListenSpeed.MAX)
            val reachableMs = (elapsedMs * rate * RATE_TOLERANCE).toLong() + SAMPLE_SLACK_MS
            if (advance in 1..reachableMs) playedMs += advance
        }
        lastPositionMs = positionMs
        lastRealtimeMs = realtimeMs
    }

    /** A seek, skip or new timeline: counting picks up again from wherever playback lands. */
    fun jumped() {
        lastPositionMs = NO_POSITION
    }

    /**
     * The milliseconds to report, which then start over. Under a second waits for the next report, unless the
     * story just finished, which is always worth sending.
     */
    fun take(finished: Boolean): Long? {
        if (playedMs < MIN_REPORT_MS && !finished) return null
        val reported = playedMs
        playedMs = 0L
        return reported
    }

    /** A new story starts with nothing played and no position to count from. */
    fun reset() {
        playedMs = 0L
        lastPositionMs = NO_POSITION
    }

    companion object {
        const val MIN_REPORT_MS = 1_000L

        // The player's clock and the wall clock drift a little between samples taken about 200ms apart.
        private const val RATE_TOLERANCE = 1.25
        private const val SAMPLE_SLACK_MS = 250L
        private const val NO_POSITION = -1L

        /** The seconds field of /listen/progress: "30.4", or "1" for a whole second. */
        fun formatSeconds(playedMs: Long): String =
            BigDecimal
                .valueOf(playedMs.coerceAtLeast(0L), 3)
                .stripTrailingZeros()
                .toPlainString()
    }
}
