package com.newsblur.viewModel

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.supervisorScope

/** Serializes AllFoldersViewModel.kt/StoriesViewModel.kt queries and StoryViewAdapter.kt diffs without starving an active snapshot. */
internal class LatestStoryLoadRunner<Request, Result>(
    scope: CoroutineScope,
    queryDispatcher: CoroutineDispatcher,
    load: suspend (Request) -> Result,
    private val cancel: (Request) -> Unit,
    publish: (Result) -> Unit,
    private val sameQuery: (Request, Request) -> Boolean = { first, second -> first == second },
    onError: (Exception) -> Unit,
) {
    private class Pending<Request>(val request: Request) {
        var cancelled = false
        var completed = false
    }

    private val requests = Channel<Pending<Request>>(Channel.CONFLATED)
    private var latest: Pending<Request>? = null
    private var active: Pending<Request>? = null
    private var activeQuery: Job? = null
    private var closed = false
    private val worker =
        scope.launch {
            for (pending in requests) {
                active = pending
                try {
                    // StoriesViewModel.kt refreshes for read/sync updates may arrive throughout a large load.
                    // Finish one useful snapshot, then process the latest queued refresh for that same query.
                    supervisorScope {
                        val query = async(queryDispatcher) { load(pending.request) }
                        activeQuery = query
                        try {
                            val result = query.await()
                            if (canPublish(pending)) publish(result)
                        } catch (cancelled: CancellationException) {
                            currentCoroutineContext().ensureActive()
                        } catch (error: Exception) {
                            if (canPublish(pending)) onError(error)
                        } finally {
                            activeQuery = null
                        }
                    }
                } finally {
                    pending.completed = true
                    active = null
                }
            }
        }

    fun submit(request: Request) {
        if (closed) {
            cancel(request)
            return
        }
        val previous = latest
        val pending = Pending(request)
        latest = pending
        active?.let {
            if (!sameQuery(it.request, request)) {
                cancelPending(it)
                activeQuery?.cancel()
            }
        }
        if (previous !== active) previous?.let(::cancelPending)
        requests.trySend(pending)
    }

    private fun canPublish(pending: Pending<Request>): Boolean =
        !pending.cancelled && latest?.let { sameQuery(pending.request, it.request) } == true

    private fun cancelPending(pending: Pending<Request>) {
        if (pending.cancelled || pending.completed) return
        pending.cancelled = true
        cancel(pending.request)
    }

    fun invalidate() {
        val previous = latest
        latest = null
        active?.let(::cancelPending)
        previous?.let(::cancelPending)
        activeQuery?.cancel()
        while (true) {
            val pending = requests.tryReceive().getOrNull() ?: break
            cancelPending(pending)
        }
    }

    fun close() {
        if (closed) return
        closed = true
        invalidate()
        requests.close()
        worker.cancel()
    }
}
