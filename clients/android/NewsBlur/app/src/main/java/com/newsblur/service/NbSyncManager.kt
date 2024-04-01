package com.newsblur.service

import com.newsblur.util.NBScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch

object NbSyncManager {

    const val UPDATE_DB_READY = 1 shl 0
    const val UPDATE_METADATA = 1 shl 1
    const val UPDATE_STORY = 1 shl 2
    const val UPDATE_SOCIAL = 1 shl 3
    const val UPDATE_INTEL = 1 shl 4
    const val UPDATE_STATUS = 1 shl 5
    const val UPDATE_TEXT = 1 shl 6
    const val UPDATE_REBUILD = 1 shl 7

    private val _state = MutableSharedFlow<NBSync>()
    val state = _state.asSharedFlow()

    @JvmStatic
    fun submitUpdate(type: Int) = submit(NBSync.Update(type))

    @JvmStatic
    fun submitError(msg: String) = submit(NBSync.Error(msg))

    private fun submit(nbSync: NBSync) {
        NBScope.launch(Dispatchers.IO) {
            _state.emit(nbSync)
        }
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