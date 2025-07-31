package com.newsblur.service

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

abstract class SyncSubService(
        val delegate: SyncServiceDelegate
) : SyncServiceDelegate by delegate {

    fun start() {
        delegate.subScope.launch(Dispatchers.IO) {
            execute()
        }
    }

    protected abstract suspend fun execute()
}