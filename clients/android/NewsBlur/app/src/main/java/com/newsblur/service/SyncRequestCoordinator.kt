package com.newsblur.service

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch

internal class SyncRequestCoordinator(
    private val runner: SyncJobRunner,
) {
    private val monitor = Any()
    private var current: Job? = null
    private var currentGeneration: Any? = null
    private var pending = false
    private var prefetch: Job? = null

    fun request(
        scope: CoroutineScope,
        foreground: suspend CoroutineScope.() -> Unit,
        background: suspend CoroutineScope.() -> Unit,
    ): Job = synchronized(monitor) {
        pending = true
        // SyncService.kt must finish active page/action commits, but prefetch may yield.
        prefetch?.cancel()
        current?.takeIf { it.isActive }?.let { return@synchronized it }

        val generation = Any()
        val job = runner.launchIn(scope, start = CoroutineStart.LAZY) {
            val context = currentCoroutineContext()
            while (true) {
                val run = synchronized(monitor) {
                    context.ensureActive()
                    if (pending) {
                        pending = false
                        true
                    } else {
                        // SyncRequestCoordinator.kt detaches atomically with checking the queue,
                        // so a request arriving as this pass ends starts a new worker.
                        current = null
                        currentGeneration = null
                        false
                    }
                }
                if (!run) break
                foreground()
                context.ensureActive()
                coroutineScope {
                    val work = launch(start = CoroutineStart.LAZY, block = background)
                    synchronized(monitor) {
                        if (pending) work.cancel() else prefetch = work
                    }
                    try {
                        work.start()
                        work.join()
                    } finally {
                        synchronized(monitor) {
                            if (prefetch === work) prefetch = null
                        }
                    }
                }
            }
        }
        current = job
        currentGeneration = generation
        job.invokeOnCompletion {
            synchronized(monitor) {
                if (currentGeneration === generation) {
                    current = null
                    currentGeneration = null
                }
            }
        }
        job.start()
        job
    }
}
