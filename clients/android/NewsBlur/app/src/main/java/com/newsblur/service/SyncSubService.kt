package com.newsblur.service

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job

abstract class SyncSubService(
    val delegate: SyncServiceDelegate,
) : SyncServiceDelegate by delegate {
    private val runner = SyncJobRunner()

    fun launchIn(scope: CoroutineScope): Job =
        runner.launchIn(scope) {
            execute()
        }

    protected abstract suspend fun execute()
}
