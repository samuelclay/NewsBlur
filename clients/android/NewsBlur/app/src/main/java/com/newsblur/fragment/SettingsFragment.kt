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
import com.newsblur.R
import com.newsblur.compose.SettingsScreen
import com.newsblur.compose.SettingsUiState
import com.newsblur.compose.buildSettingsUiState
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedUtils.Companion.triggerSync
import com.newsblur.util.NotificationUtils
import com.newsblur.util.PrefConstants
import dagger.hilt.android.AndroidEntryPoint
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
                        onDeleteOfflineStories = ::deleteOfflineStories,
                    )
                }
            }
        }

    private fun refreshUiState() {
        uiState = buildSettingsUiState(prefsRepo, sharedPreferences)
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
