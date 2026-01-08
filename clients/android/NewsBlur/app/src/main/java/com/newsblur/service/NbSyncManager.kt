package com.newsblur.service

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow

object NbSyncManager {
    const val UPDATE_DB_READY = 1 shl 0
    const val UPDATE_METADATA = 1 shl 1
    const val UPDATE_STORY = 1 shl 2
    const val UPDATE_SOCIAL = 1 shl 3
    const val UPDATE_INTEL = 1 shl 4
    const val UPDATE_STATUS = 1 shl 5
    const val UPDATE_TEXT = 1 shl 6
    const val UPDATE_REBUILD = 1 shl 7

    private val _state =
        MutableSharedFlow<NBSync>(
            replay = 0,
            extraBufferCapacity = 32,
            onBufferOverflow = BufferOverflow.DROP_OLDEST,
        )
    val state = _state.asSharedFlow()

    @JvmStatic
    fun submitUpdate(type: Int) = submit(NBSync.Update(type))

    @JvmStatic
    fun submitError(msg: String) = submit(NBSync.Error(msg))

    private fun submit(nbSync: NBSync) {
        _state.tryEmit(nbSync)
    }
}

sealed class NBSync {
    data class Error(
        val msg: String,
    ) : NBSync()

    data class Update(
        val type: Int,
    ) : NBSync()
}
