package com.newsblur.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

abstract class NBSyncReceiver : BroadcastReceiver() {

    abstract fun handleUpdateType(updateType: Int)

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == NB_SYNC_ACTION) {
            handleUpdateType(intent.getIntExtra(NB_SYNC_UPDATE_TYPE, 0))
        }
    }

    companion object {
        const val NB_SYNC_ACTION = "nb.sync.action"
        const val NB_SYNC_ERROR_MESSAGE = "nb_sync_error_msg"
        const val NB_SYNC_UPDATE_TYPE = "nb_sync_update_type"

        const val UPDATE_DB_READY = 1 shl 0
        const val UPDATE_METADATA = 1 shl 1
        const val UPDATE_STORY = 1 shl 2
        const val UPDATE_SOCIAL = 1 shl 3
        const val UPDATE_INTEL = 1 shl 4
        const val UPDATE_STATUS = 1 shl 5
        const val UPDATE_TEXT = 1 shl 6
        const val UPDATE_REBUILD = 1 shl 7
    }
}