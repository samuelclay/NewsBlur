package com.newsblur.service

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

internal class SyncJobRunner {
    private val execution = Mutex()

    fun launchIn(
        scope: CoroutineScope,
        start: CoroutineStart = CoroutineStart.DEFAULT,
        block: suspend CoroutineScope.() -> Unit,
    ): Job =
        scope.launch(start = start) {
            // SyncService.kt cancellation cannot interrupt blocking network/Gson work.
            // Keep the permit until that work and all its children finish.
            execution.withLock {
                coroutineScope(block)
            }
        }
}
