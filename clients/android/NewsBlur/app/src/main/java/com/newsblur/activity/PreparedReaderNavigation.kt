package com.newsblur.activity

internal data class ReaderPageTarget(val storyHash: String, val position: Int, val isHistoryBack: Boolean = false)

/** Reading.kt owns the pager; this coordinator admits only rendered pages into its visible history. */
internal class PreparedReaderNavigation(
    private val capture: ((Boolean) -> Unit) -> Unit,
    private val prepare: (ReaderPageTarget) -> Unit,
    private val commit: (ReaderPageTarget) -> Unit,
    private val animate: (Int, () -> Unit) -> Unit,
    private val release: () -> Unit,
    private val captureFailed: () -> Unit,
) {
    private enum class Phase { IDLE, CAPTURING, PREPARING, ANIMATING }

    private var phase = Phase.IDLE
    private var generation = 0
    private var origin: ReaderPageTarget? = null
    private var target: ReaderPageTarget? = null
    private var queuedTarget: ReaderPageTarget? = null
    private var paused = false

    @Volatile
    var requestedTarget: ReaderPageTarget? = null
        private set

    val isActive: Boolean get() = phase != Phase.IDLE
    val isPreparing: Boolean get() = phase == Phase.CAPTURING || phase == Phase.PREPARING
    val outgoingTarget: ReaderPageTarget? get() = origin

    fun request(source: ReaderPageTarget, destination: ReaderPageTarget) {
        if (phase == Phase.IDLE && source.storyHash == destination.storyHash) return
        requestedTarget = destination
        if (phase == Phase.ANIMATING) {
            queuedTarget = destination
            return
        }
        target = destination
        if (phase == Phase.PREPARING) {
            if (!paused) prepare(destination)
            return
        }
        if (phase == Phase.CAPTURING) return

        origin = source
        phase = Phase.CAPTURING
        val requestGeneration = ++generation
        capture { success ->
            if (generation != requestGeneration || phase != Phase.CAPTURING) return@capture
            if (!success) {
                cancel()
                captureFailed()
                return@capture
            }
            phase = Phase.PREPARING
            if (!paused) target?.let(prepare)
        }
    }

    fun ready(storyHash: String) {
        val destination = target ?: return
        val source = origin ?: return
        if (paused || phase != Phase.PREPARING || destination.storyHash != storyHash) return
        phase = Phase.ANIMATING
        commit(destination)
        val requestGeneration = generation
        animate(destination.position.compareTo(source.position)) {
            if (generation != requestGeneration || phase != Phase.ANIMATING) return@animate
            val next = queuedTarget
            cancel()
            if (next != null) request(destination, next)
        }
    }

    fun cancel(releaseSnapshot: Boolean = true) {
        generation++
        phase = Phase.IDLE
        origin = null
        target = null
        queuedTarget = null
        requestedTarget = null
        if (releaseSnapshot) release()
    }

    fun pause() {
        paused = true
    }

    fun resume() {
        if (!paused) return
        paused = false
        if (phase == Phase.PREPARING) target?.let(prepare)
    }
}
