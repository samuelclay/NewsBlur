package com.newsblur.listen

import kotlin.math.roundToLong

/**
 * ListenTimeline.kt lays a story's segments end to end so the player, lock screen and scrubber can show one
 * story-long timeline. Durations start as the manifest's estimates and are replaced by real ones as segments
 * are played or come back cached.
 */
data class ListenTimeline(
    val durationsMs: List<Long>,
    val known: List<Boolean> = List(durationsMs.size) { false },
) {
    data class Location(
        val segmentIndex: Int,
        val offsetMs: Long,
    )

    val segmentCount: Int
        get() = durationsMs.size

    val totalMs: Long
        get() = durationsMs.sum()

    fun startMs(segmentIndex: Int): Long = durationsMs.take(segmentIndex.coerceIn(0, segmentCount)).sum()

    fun durationMs(segmentIndex: Int): Long = durationsMs.getOrElse(segmentIndex) { 0L }

    /** Story position of a point inside a segment, never past that segment's known or estimated end. */
    fun positionMs(
        segmentIndex: Int,
        offsetMs: Long,
    ): Long {
        if (segmentCount == 0) return 0L
        val index = segmentIndex.coerceIn(0, segmentCount - 1)
        return startMs(index) + offsetMs.coerceIn(0L, durationMs(index))
    }

    /** The segment and the offset inside it for a story position; positions past the end land on the last segment's end. */
    fun locate(positionMs: Long): Location {
        if (segmentCount == 0) return Location(0, 0L)
        var remaining = positionMs.coerceAtLeast(0L)
        durationsMs.forEachIndexed { index, duration ->
            if (remaining < duration || index == segmentCount - 1) {
                return Location(index, remaining.coerceAtMost(duration))
            }
            remaining -= duration
        }
        return Location(segmentCount - 1, durationMs(segmentCount - 1))
    }

    fun withDuration(
        segmentIndex: Int,
        durationMs: Long,
        isKnown: Boolean,
    ): ListenTimeline {
        if (segmentIndex !in 0 until segmentCount || durationMs <= 0L) return this
        // An estimate never replaces a measured duration.
        if (!isKnown && known[segmentIndex]) return this
        if (durationsMs[segmentIndex] == durationMs && known[segmentIndex] == isKnown) return this
        return copy(
            durationsMs = durationsMs.toMutableList().apply { set(segmentIndex, durationMs) },
            known = known.toMutableList().apply { set(segmentIndex, isKnown) },
        )
    }

    companion object {
        /** Segments the server couldn't estimate still get a moment on the scrubber. */
        private const val MIN_SEGMENT_MS = 500L

        fun fromSegments(segments: List<ListenSegment>): ListenTimeline =
            ListenTimeline(
                durationsMs =
                    segments.map {
                        secondsToMs(it.duration).coerceAtLeast(MIN_SEGMENT_MS)
                    },
                known = segments.map { !it.estimated && it.duration > 0.0 },
            )

        fun secondsToMs(seconds: Double): Long = if (seconds.isFinite()) (seconds * 1000.0).roundToLong() else 0L
    }
}

/** ListenTimeline.kt's helpers for finding segments by the server paragraph indexes they read. */
object ListenSegments {
    /** The first segment that reads this paragraph, for paragraph taps in the story. */
    fun segmentForParagraph(
        segments: List<ListenSegment>,
        paragraphIndex: Int,
    ): Int? = segments.indexOfFirst { paragraphIndex in it.paragraphs }.takeIf { it >= 0 }

    /**
     * After a manifest is rebuilt (expired, or a new voice), playback resumes at the segment holding the same
     * paragraph, or the next one that exists when the new manifest grouped paragraphs differently.
     */
    fun segmentForResume(
        segments: List<ListenSegment>,
        paragraphIndex: Int,
    ): Int {
        segmentForParagraph(segments, paragraphIndex)?.let { return it }
        val next =
            segments.indexOfFirst { segment ->
                segment.paragraphs.any { it >= paragraphIndex }
            }
        return if (next >= 0) next else (segments.size - 1).coerceAtLeast(0)
    }

    fun firstParagraph(
        segments: List<ListenSegment>,
        segmentIndex: Int,
    ): Int = segments.getOrNull(segmentIndex)?.paragraphs?.minOrNull() ?: 0
}

/** ListenTimeline.kt: how a 30 second preview ends, fading out over its last moment instead of cutting off. */
object ListenPreviewFade {
    const val FADE_MS = 1_500L

    fun volume(
        positionMs: Long,
        limitMs: Long,
    ): Float {
        if (limitMs <= 0L) return 1f
        val fadeStart = limitMs - FADE_MS
        return when {
            positionMs <= fadeStart -> 1f
            positionMs >= limitMs -> 0f
            else -> ((limitMs - positionMs).toFloat() / FADE_MS).coerceIn(0f, 1f)
        }
    }

    fun isFinished(
        positionMs: Long,
        limitMs: Long,
    ): Boolean = limitMs > 0L && positionMs >= limitMs
}

/** ListenTimeline.kt's skip and scrub targets, kept inside the story. */
object ListenSeek {
    const val SKIP_BACK_MS = 15_000L
    const val SKIP_FORWARD_MS = 30_000L

    fun target(
        currentMs: Long,
        deltaMs: Long,
        totalMs: Long,
    ): Long = (currentMs + deltaMs).coerceIn(0L, totalMs.coerceAtLeast(0L))
}
