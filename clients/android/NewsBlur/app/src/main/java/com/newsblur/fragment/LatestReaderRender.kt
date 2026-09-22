package com.newsblur.fragment

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch

/** Keeps ReadingItemFragment.kt's asynchronous document preparation ordered and bounded. */
internal class LatestReaderRender<Request : Any, Content> {
    private var generation = 0L
    private var pendingRequest: Request? = null
    private var renderedRequest: Request? = null
    private var job: Job? = null

    fun submit(
        scope: CoroutineScope,
        request: Request,
        prepare: suspend () -> Content,
        display: (Content) -> Unit,
    ) {
        if (request == pendingRequest) return
        val requestGeneration = ++generation
        job?.cancel()
        pendingRequest = null
        if (request == renderedRequest) return

        pendingRequest = request
        job =
            scope.launch {
                try {
                    val content = prepare()
                    ensureActive()
                    if (generation != requestGeneration) return@launch
                    display(content)
                    renderedRequest = request
                } finally {
                    if (generation == requestGeneration) pendingRequest = null
                }
            }
    }

    fun clear() {
        generation++
        job?.cancel()
        job = null
        pendingRequest = null
        renderedRequest = null
    }
}
