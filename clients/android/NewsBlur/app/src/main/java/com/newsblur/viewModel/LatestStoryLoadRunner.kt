package com.newsblur.viewModel

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Serializes StoriesViewModel.kt cursor work and discards superseded refresh requests. */
internal class LatestStoryLoadRunner<Request, Result>(
    scope: CoroutineScope,
    queryDispatcher: CoroutineDispatcher,
    load: suspend (Request) -> Result,
    private val cancel: (Request) -> Unit,
    publish: (Result) -> Unit,
    onError: (Exception) -> Unit,
) {
    private class Pending<Request>(val request: Request)

    private val requests = Channel<Pending<Request>>(Channel.CONFLATED)
    private var latest: Pending<Request>? = null
    private var closed = false
    private val worker =
        scope.launch {
            requests.receiveAsFlow().collectLatest { pending ->
                try {
                    val result = withContext(queryDispatcher) { load(pending.request) }
                    if (latest === pending) publish(result)
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (error: Exception) {
                    if (latest === pending) onError(error)
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
        previous?.let { cancel(it.request) }
        requests.trySend(pending)
    }

    fun close() {
        if (closed) return
        closed = true
        val previous = latest
        latest = null
        previous?.let { cancel(it.request) }
        requests.close()
        worker.cancel()
    }
}
