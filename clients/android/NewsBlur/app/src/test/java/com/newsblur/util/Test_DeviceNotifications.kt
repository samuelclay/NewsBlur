package com.newsblur.util

import android.Manifest
import android.content.pm.PackageManager
import android.widget.Toast
import androidx.core.app.ActivityCompat
import com.newsblur.activity.NbActivity
import com.newsblur.domain.Feed
import com.newsblur.preference.PrefsRepo
import com.newsblur.push.PushMessaging
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.runs
import io.mockk.slot
import io.mockk.spyk
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class Test_DeviceNotifications {
    private val prefsRepo = mockk<PrefsRepo>(relaxed = true)
    private val activity = mockk<NbActivity>(relaxed = true)
    private val feedUtils =
        spyk(
            FeedUtils(
                dbHelper = mockk(relaxed = true),
                folderApi = mockk(relaxed = true),
                prefsRepo = prefsRepo,
                syncServiceState = mockk(relaxed = true),
                tryFeedStore = mockk(relaxed = true),
                storyApi = mockk(relaxed = true),
            ),
        )

    @Before fun setUp() {
        // PushMessaging.kt talks to Firebase in the Play build; DeviceNotifications.kt only tells it the switch moved.
        mockkStatic(NotificationUtils::class, ActivityCompat::class, Toast::class, PushMessaging::class)
        every { PushMessaging.sync(any()) } just runs
        // FeedUtils.kt saves the feed's setting to the server on a background scope, which a unit test must not start.
        every { feedUtils.updateFeedNotifications(any(), any()) } just runs
        every { ActivityCompat.requestPermissions(any(), any(), any()) } just runs
        every { ActivityCompat.shouldShowRequestPermissionRationale(any(), any()) } returns false
        every { Toast.makeText(any(), any<Int>(), any()) } returns mockk(relaxed = true)
        every { prefsRepo.isEnableNotifications() } returns false
    }

    @After fun tearDown() =
        unmockkStatic(NotificationUtils::class, ActivityCompat::class, Toast::class, PushMessaging::class)

    @Test fun test_setting_a_feed_to_notify_turns_on_this_devices_switch() {
        every { NotificationUtils.hasPermissions(any()) } returns true

        feedUtils.enableUnreadNotifications(activity, Feed().apply { feedId = "1" })
        feedUtils.enableFocusNotifications(activity, Feed().apply { feedId = "2" })

        verify(exactly = 2) { prefsRepo.putBoolean(PrefConstants.ENABLE_NOTIFICATIONS, true) }
    }

    @Test fun test_missing_permission_is_requested_and_its_answer_sets_the_switch() {
        every { NotificationUtils.hasPermissions(any()) } returns false
        val requestCode = slot<Int>()

        DeviceNotifications.turnOn(activity, prefsRepo)

        verify { ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), capture(requestCode)) }
        // The switch waits for the answer, or it would read as on while Android blocks every notification.
        verify(exactly = 0) { prefsRepo.putBoolean(PrefConstants.ENABLE_NOTIFICATIONS, any()) }

        // Another screen's permission request and an interrupted one are not answers.
        DeviceNotifications.onPermissionResult(activity, prefsRepo, requestCode.captured + 1, intArrayOf(PackageManager.PERMISSION_GRANTED))
        DeviceNotifications.onPermissionResult(activity, prefsRepo, requestCode.captured, intArrayOf())
        verify(exactly = 0) { prefsRepo.putBoolean(PrefConstants.ENABLE_NOTIFICATIONS, any()) }

        DeviceNotifications.onPermissionResult(activity, prefsRepo, requestCode.captured, intArrayOf(PackageManager.PERMISSION_DENIED))
        verify(exactly = 1) { prefsRepo.putBoolean(PrefConstants.ENABLE_NOTIFICATIONS, false) }

        DeviceNotifications.onPermissionResult(activity, prefsRepo, requestCode.captured, intArrayOf(PackageManager.PERMISSION_GRANTED))
        verify(exactly = 1) { prefsRepo.putBoolean(PrefConstants.ENABLE_NOTIFICATIONS, true) }
    }

    @Test fun test_a_working_device_is_not_asked_again() {
        every { prefsRepo.isEnableNotifications() } returns true
        every { NotificationUtils.hasPermissions(any()) } returns true

        DeviceNotifications.turnOn(activity, prefsRepo)

        verify(exactly = 0) { prefsRepo.putBoolean(any(), any()) }
        verify(exactly = 0) { ActivityCompat.requestPermissions(any(), any(), any()) }
    }

    @Test fun test_launch_prompt_only_asks_a_device_that_never_chose() {
        assertTrue(DeviceNotifications.shouldPromptOnLaunch(hasAndroidFeeds = true, hasChosen = false, alreadyPrompted = false))
        // Turning the switch off on this device is an answer, and so is dismissing the prompt.
        assertFalse(DeviceNotifications.shouldPromptOnLaunch(hasAndroidFeeds = true, hasChosen = true, alreadyPrompted = false))
        assertFalse(DeviceNotifications.shouldPromptOnLaunch(hasAndroidFeeds = true, hasChosen = false, alreadyPrompted = true))
        assertFalse(DeviceNotifications.shouldPromptOnLaunch(hasAndroidFeeds = false, hasChosen = false, alreadyPrompted = false))
    }
}
