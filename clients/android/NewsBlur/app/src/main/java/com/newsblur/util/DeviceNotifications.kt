package com.newsblur.util

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.core.app.ActivityCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.activity.NbActivity
import com.newsblur.compose.LanguageChooserDialog
import com.newsblur.preference.PrefsRepo
import com.newsblur.push.PushMessaging
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * DeviceNotifications.kt: story notifications are posted by each device after its own background sync
 * (SyncService.kt), not pushed by the server. A feed set to notify on Android stays silent on a device until that
 * device's Enable notifications switch is on and Android has granted the notification permission.
 */
object DeviceNotifications {
    private const val PERMISSION_REQUEST_CODE = 4107

    // Lets LanguageChooserDialog.kt, which waits 600ms on the same feed list load, show first.
    private const val PROMPT_DELAY_MS = 900L

    // Decided at most once per app session.
    private var launchDecided = false

    /** Whether a new story can show a notification on this device. */
    @JvmStatic
    fun isOn(
        context: Context,
        prefsRepo: PrefsRepo,
    ): Boolean = prefsRepo.isEnableNotifications() && NotificationUtils.hasPermissions(context)

    /**
     * Turns notifications on for this device, asking Android for the permission first if it is missing.
     * NbActivity.kt passes the answer to [onPermissionResult].
     */
    @JvmStatic
    @SuppressLint("InlinedApi")
    fun turnOn(
        context: Context,
        prefsRepo: PrefsRepo,
    ) {
        if (isOn(context, prefsRepo)) return
        if (NotificationUtils.hasPermissions(context)) {
            prefsRepo.putBoolean(PrefConstants.ENABLE_NOTIFICATIONS, true)
            PushMessaging.sync(context)
            return
        }
        val activity = context as? Activity ?: return
        if (ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.POST_NOTIFICATIONS)) {
            showPermissionRationale(activity)
        } else {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                PERMISSION_REQUEST_CODE,
            )
        }
    }

    /** The switch follows the answer, as it does for the same question in SettingsFragment.kt. */
    fun onPermissionResult(
        activity: Activity,
        prefsRepo: PrefsRepo,
        requestCode: Int,
        grantResults: IntArray,
    ) {
        // An interrupted request comes back empty, which is not an answer.
        if (requestCode != PERMISSION_REQUEST_CODE || grantResults.isEmpty()) return
        val granted = grantResults[0] == PackageManager.PERMISSION_GRANTED
        prefsRepo.putBoolean(PrefConstants.ENABLE_NOTIFICATIONS, granted)
        PushMessaging.sync(activity)
        if (!granted) {
            Toast.makeText(activity, R.string.notification_permissions_context, Toast.LENGTH_SHORT).show()
        }
    }

    /** Once Android stops showing its own dialog, the permission can only be granted from the app's system settings. */
    fun showPermissionRationale(activity: Activity) {
        AlertDialog
            .Builder(activity)
            .setTitle(R.string.settings_enable_notifications)
            .setMessage(R.string.notification_permissions_rationale)
            .setNegativeButton(android.R.string.cancel, null)
            .setPositiveButton(android.R.string.ok) { _, _ ->
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                intent.data = Uri.fromParts("package", activity.packageName, null)
                activity.startActivity(intent)
            }.show()
    }

    /**
     * Feeds can be set to notify on Android from the web or another device, where nothing asks this device to turn
     * its notifications on. Only a device that never set the switch either way is asked, and only once.
     */
    fun shouldPromptOnLaunch(
        hasAndroidFeeds: Boolean,
        hasChosen: Boolean,
        alreadyPrompted: Boolean,
    ): Boolean = hasAndroidFeeds && !hasChosen && !alreadyPrompted

    /** Main.java calls this whenever the feed list renders. */
    @JvmStatic
    fun feedListLoaded(activity: NbActivity) {
        if (launchDecided || !canShowDialog(activity)) return
        launchDecided = true
        val prefsRepo = activity.prefsRepo
        activity.lifecycleScope.launch {
            var settled = false
            try {
                val hasAndroidFeeds = withContext(Dispatchers.IO) { activity.dbHelper.getNotifyFeeds().isNotEmpty() }
                val prompt =
                    shouldPromptOnLaunch(
                        hasAndroidFeeds = hasAndroidFeeds,
                        hasChosen = prefsRepo.hasNotificationsChoice(),
                        alreadyPrompted = prefsRepo.getBoolean(PrefConstants.NOTIFICATIONS_PROMPT_SEEN, false),
                    )
                if (prompt) {
                    delay(PROMPT_DELAY_MS)
                    if (!canShowDialog(activity)) return@launch
                    showLaunchPrompt(activity)
                }
                settled = true
            } finally {
                // A recreated screen cancels this check, and another prompt can be in the way. Either way a later
                // feed list load tries again.
                if (!settled) launchDecided = false
            }
        }
    }

    private fun canShowDialog(activity: NbActivity): Boolean =
        activity.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) &&
            !activity.isFinishing &&
            !activity.supportFragmentManager.isStateSaved &&
            activity.supportFragmentManager.findFragmentByTag(LanguageChooserDialog.TAG) == null

    private fun showLaunchPrompt(activity: NbActivity) {
        // Seen as soon as it shows, so dismissing it is an answer too.
        activity.prefsRepo.putBoolean(PrefConstants.NOTIFICATIONS_PROMPT_SEEN, true)
        AlertDialog
            .Builder(activity)
            .setTitle(R.string.settings_enable_notifications)
            .setMessage(R.string.notifications_device_off)
            .setNegativeButton(android.R.string.cancel, null)
            .setPositiveButton(android.R.string.ok) { _, _ -> turnOn(activity, activity.prefsRepo) }
            .show()
    }
}
