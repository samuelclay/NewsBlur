package com.newsblur.fragment

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.preference.CheckBoxPreference
import androidx.preference.Preference
import androidx.preference.PreferenceFragmentCompat
import com.newsblur.R
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.service.NBSyncService
import com.newsblur.util.FeedUtils.Companion.triggerSync
import com.newsblur.util.NotificationUtils
import com.newsblur.util.PrefConstants
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class SettingsFragment : PreferenceFragmentCompat() {

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    private val requestPermissionLauncher = registerForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted: Boolean ->
        if (!isGranted) Toast
                .makeText(requireContext(), R.string.notification_permissions_context, Toast.LENGTH_SHORT)
                .show()
        checkEnableNotifications(isGranted)
    }

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        val preferenceManager = preferenceManager
        preferenceManager.sharedPreferencesName = PrefConstants.PREFERENCES
        setPreferencesFromResource(R.xml.activity_settings, rootKey)

        findPreference<Preference>(getString(R.string.menu_delete_offline_stories_key))?.let {
            it.setOnPreferenceClickListener { pref ->
                deleteOfflineStories(pref)
                true
            }
        }
        findPreference<Preference>(getString(R.string.settings_enable_notifications_key))?.let {
            it.setOnPreferenceChangeListener { _, newValue ->
                notificationPrefChanged(newValue)
                false
            }
        }
    }

    private fun deleteOfflineStories(pref: Preference) {
        pref.apply {
            onPreferenceClickListener = null
            summary = ""
            setTitle(R.string.menu_delete_offline_stories_confirmation)
        }
        dbHelper.deleteStories()
        NBSyncService.forceFeedsFolders()
        triggerSync(requireContext())
    }

    private fun checkEnableNotifications(isChecked: Boolean) {
        findPreference<CheckBoxPreference>(getString(R.string.settings_enable_notifications_key))?.let {
            it.isChecked = isChecked
        }
    }

    @SuppressLint("InlinedApi") // check for API done in NotificationUtils
    private fun notificationPrefChanged(newValue: Any) {
        val askForPermission = newValue == true && !NotificationUtils.hasPermissions(requireContext())
        val showRationale = NotificationUtils.shouldShowRationale(this)

        if (askForPermission && showRationale) {
            showNotificationRationaleDialog()
        } else if (askForPermission) {
            requestPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            checkEnableNotifications(newValue == true)
        }
    }

    private fun showNotificationRationaleDialog() {
        AlertDialog.Builder(requireContext())
                .setTitle(R.string.settings_enable_notifications)
                .setMessage(R.string.notification_permissions_rationale)
                .setNegativeButton(android.R.string.cancel, null)
                .setPositiveButton(android.R.string.ok) { _, _ ->
                    openAppSettings()
                }
                .show()
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val uri = Uri.fromParts("package", requireContext().packageName, null)
        intent.data = uri
        startActivity(intent)
    }
}