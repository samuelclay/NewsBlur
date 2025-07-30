package com.newsblur.service

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.plus

abstract class SyncSubService(
        val parent: SyncService,
) {
    private val subJob = SupervisorJob(parent.coroutineContext[Job])
    private val subScope = parent + subJob

    fun start() {
        subScope.launch(Dispatchers.IO) {
            execute()
        }
    }

    fun sendSyncUpdate(update: Int) {
        parent.sendSyncUpdate(update)
    }

    protected abstract suspend fun execute()

    abstract fun clear()
}