package com.newsblur.preference

import android.content.SharedPreferences
import com.newsblur.util.AppConstants
import com.newsblur.util.PrefConstants
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DiscoveryViewPreferences @Inject constructor(private val preferences: SharedPreferences) {
    fun isGrid(): Boolean = preferences.getString(VIEW_MODE, "list") == "grid"

    fun setGrid(grid: Boolean) {
        preferences.edit().putString(VIEW_MODE, if (grid) "grid" else "list").apply()
    }

    fun folderSelection(): FolderSelection {
        val account = preferences.getString(PrefConstants.PREF_UNIQUE_LOGIN, null).orEmpty()
        val owner = preferences.getString(FOLDER_ACCOUNT, null)
        val folder = if (owner == account) preferences.getString(FOLDER, null) else null
        return FolderSelection(account, folder?.takeIf { it.isNotBlank() } ?: AppConstants.ROOT_FOLDER)
    }

    fun setFolder(folder: String) {
        preferences.edit()
            .putString(FOLDER_ACCOUNT, folderSelection().account)
            .putString(FOLDER, folder.takeIf { it.isNotBlank() } ?: AppConstants.ROOT_FOLDER)
            .apply()
    }

    // DiscoveryViewModel.kt and DiscoverFeedsViewModel.kt can remain alive while the other changes the preference.
    val gridChanges = callbackFlow {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == VIEW_MODE || key == null) trySend(isGrid())
        }
        preferences.registerOnSharedPreferenceChangeListener(listener)
        trySend(isGrid())
        awaitClose { preferences.unregisterOnSharedPreferenceChangeListener(listener) }
    }.distinctUntilChanged()

    val folderChanges = callbackFlow {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == FOLDER || key == FOLDER_ACCOUNT || key == PrefConstants.PREF_UNIQUE_LOGIN || key == null) {
                trySend(folderSelection())
            }
        }
        preferences.registerOnSharedPreferenceChangeListener(listener)
        trySend(folderSelection())
        awaitClose { preferences.unregisterOnSharedPreferenceChangeListener(listener) }
    }.distinctUntilChanged()

    data class FolderSelection(val account: String, val folder: String)

    private companion object {
        const val VIEW_MODE = "discover_feeds_view_mode"
        const val FOLDER = "discovery_add_folder"
        const val FOLDER_ACCOUNT = "discovery_add_folder_account"
    }
}
