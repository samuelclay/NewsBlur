package com.newsblur.fragment

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.SharedPreferences
import android.content.SharedPreferences.OnSharedPreferenceChangeListener
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.core.content.edit
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.compose.SettingsScreen
import com.newsblur.compose.SettingsUiState
import com.newsblur.compose.buildSettingsUiState
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.SyncServiceState
import com.newsblur.util.AppIconAppearanceMode
import com.newsblur.util.AppIconFlavor
import com.newsblur.util.AppIconManager
import com.newsblur.util.FeedUtils.Companion.triggerSync
import com.newsblur.util.NotificationUtils
import com.newsblur.util.PrefConstants
import com.newsblur.util.StoryClusterDisplayDecision
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@AndroidEntryPoint
class SettingsFragment : Fragment() {
    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    @Inject
    lateinit var syncServiceState: SyncServiceState

    @Inject
    lateinit var prefsRepo: PrefsRepo

    @Inject
    lateinit var sharedPreferences: SharedPreferences

    @Inject
    lateinit var userApi: UserApi

    private var uiState by mutableStateOf(SettingsUiState())

    private val preferenceChangeListener =
        OnSharedPreferenceChangeListener { _, _ ->
            refreshUiState()
        }

    private val requestPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted: Boolean ->
            if (!isGranted) {
                Toast
                    .makeText(requireContext(), R.string.notification_permissions_context, Toast.LENGTH_SHORT)
                    .show()
            }
            updateNotificationsPreference(isGranted)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        refreshUiState()
    }

    override fun onStart() {
        super.onStart()
        sharedPreferences.registerOnSharedPreferenceChangeListener(preferenceChangeListener)
    }

    override fun onStop() {
        sharedPreferences.unregisterOnSharedPreferenceChangeListener(preferenceChangeListener)
        super.onStop()
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View =
        ComposeView(requireContext()).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
            setContent {
                NewsBlurTheme(
                    variant = prefsRepo.getSelectedTheme().toVariant(),
                    dynamic = false,
                ) {
                    SettingsScreen(
                        state = uiState,
                        onBooleanChanged = ::updateBooleanPreference,
                        onStringChanged = ::updateStringPreference,
                        onStoryClusteringEnabledChanged = ::updateStoryClusteringEnabled,
                        onClusterModeChanged = ::updateClusterMode,
                        onAppIconSelected = ::updateAppIcon,
                        onAppIconUpgrade = ::showSubscription,
                        onDeleteOfflineStories = ::deleteOfflineStories,
                    )
                }
            }
        }

    private fun refreshUiState() {
        val context = context ?: return
        uiState = buildSettingsUiState(context, prefsRepo, sharedPreferences)
    }

    private fun updateBooleanPreference(
        key: String,
        value: Boolean,
    ) {
        if (key == PrefConstants.ENABLE_NOTIFICATIONS) {
            handleNotificationsPreferenceChange(value)
            return
        }
        prefsRepo.putBoolean(key, value)
        refreshUiState()
    }

    private fun updateStringPreference(
        key: String,
        value: String,
    ) {
        sharedPreferences.edit { putString(key, value) }
        refreshUiState()
    }

    private fun updateStoryClusteringEnabled(enabled: Boolean) {
        val currentClusterMode = prefsRepo.getString(PrefConstants.CLUSTER_MODE, StoryClusterDisplayDecision.CLUSTER_MODE_RELATED)
        updateStoryClusteringPreference(enabled, currentClusterMode)
    }

    private fun updateClusterMode(clusterMode: String) {
        updateStoryClusteringPreference(true, clusterMode)
    }

    private fun updateAppIcon(
        flavor: AppIconFlavor,
        mode: AppIconAppearanceMode,
    ) {
        try {
            AppIconManager.setAppIcon(requireContext(), flavor, mode)
            refreshUiState()
        } catch (_: RuntimeException) {
            Toast
                .makeText(requireContext(), R.string.settings_app_icon_save_failed, Toast.LENGTH_SHORT)
                .show()
        }
    }

    private fun showSubscription() {
        UIUtils.startSubscriptionActivity(requireContext())
    }

    private fun updateStoryClusteringPreference(
        desiredEnabled: Boolean,
        desiredClusterMode: String,
    ) {
        val previousEnabled = prefsRepo.getBoolean(PrefConstants.STORY_CLUSTERING, true)
        val previousClusterMode = prefsRepo.getString(PrefConstants.CLUSTER_MODE, StoryClusterDisplayDecision.CLUSTER_MODE_RELATED)

        if (previousEnabled == desiredEnabled && previousClusterMode == desiredClusterMode) {
            return
        }

        prefsRepo.putBoolean(PrefConstants.STORY_CLUSTERING, desiredEnabled)
        if (desiredEnabled) {
            prefsRepo.putString(PrefConstants.CLUSTER_MODE, desiredClusterMode)
        }
        refreshUiState()

        viewLifecycleOwner.lifecycleScope.launch {
            val saved =
                withContext(Dispatchers.IO) {
                    saveStoryClusteringPreference(
                        previousEnabled = previousEnabled,
                        desiredEnabled = desiredEnabled,
                        previousClusterMode = previousClusterMode,
                        desiredClusterMode = desiredClusterMode,
                    )
                }

            if (saved) {
                syncServiceState.resetFetchState(syncServiceState.lastFeedSet)
                syncServiceState.forceFeedsFolders()
                triggerSync(requireContext())
            } else {
                prefsRepo.putBoolean(PrefConstants.STORY_CLUSTERING, previousEnabled)
                prefsRepo.putString(PrefConstants.CLUSTER_MODE, previousClusterMode)
                refreshUiState()
                Toast
                    .makeText(requireContext(), R.string.settings_story_clustering_save_failed, Toast.LENGTH_SHORT)
                    .show()
            }
        }
    }

    private fun deleteOfflineStories() {
        dbHelper.deleteStories()
        syncServiceState.forceFeedsFolders()
        triggerSync(requireContext())
        Toast
            .makeText(requireContext(), R.string.menu_delete_offline_stories_confirmation, Toast.LENGTH_SHORT)
            .show()
        refreshUiState()
    }

    @SuppressLint("InlinedApi")
    private fun handleNotificationsPreferenceChange(enable: Boolean) {
        val askForPermission = enable && !NotificationUtils.hasPermissions(requireContext())
        val showRationale = NotificationUtils.shouldShowRationale(this)

        when {
            askForPermission && showRationale -> showNotificationRationaleDialog()
            askForPermission -> requestPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            else -> updateNotificationsPreference(enable)
        }
    }

    private fun updateNotificationsPreference(enabled: Boolean) {
        prefsRepo.putBoolean(PrefConstants.ENABLE_NOTIFICATIONS, enabled)
        refreshUiState()
    }

    private suspend fun saveStoryClusteringPreference(
        previousEnabled: Boolean,
        desiredEnabled: Boolean,
        previousClusterMode: String,
        desiredClusterMode: String,
    ): Boolean {
        val appliedChanges = mutableListOf<Pair<String, String>>()

        if (previousEnabled != desiredEnabled) {
            val saved = userApi.setPreference(PrefConstants.STORY_CLUSTERING, desiredEnabled.toString())
            if (!saved) return false
            appliedChanges += PrefConstants.STORY_CLUSTERING to previousEnabled.toString()
        }

        if (desiredEnabled && previousClusterMode != desiredClusterMode) {
            val saved = userApi.setPreference(PrefConstants.CLUSTER_MODE, desiredClusterMode)
            if (!saved) {
                rollbackStoryClusteringPreference(appliedChanges)
                return false
            }
            appliedChanges += PrefConstants.CLUSTER_MODE to previousClusterMode
        }

        return true
    }

    private suspend fun rollbackStoryClusteringPreference(appliedChanges: List<Pair<String, String>>) {
        appliedChanges
            .asReversed()
            .forEach { (key, value) ->
                userApi.setPreference(key, value)
            }
    }

    private fun showNotificationRationaleDialog() {
        AlertDialog
            .Builder(requireContext())
            .setTitle(R.string.settings_enable_notifications)
            .setMessage(R.string.notification_permissions_rationale)
            .setNegativeButton(android.R.string.cancel, null)
            .setPositiveButton(android.R.string.ok) { _, _ ->
                openAppSettings()
            }.show()
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.data = Uri.fromParts("package", requireContext().packageName, null)
        startActivity(intent)
    }
}
