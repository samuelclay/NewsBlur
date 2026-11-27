package com.newsblur.service

import org.junit.Assert.assertEquals
import org.junit.Test

class Test_SyncMode {
    @Test
    fun test_background_sync_on_a_restricted_network_is_skipped_without_notifications() {
        val mode = SyncMode.decide(isAppForeground = false, isBackgroundNetworkAllowed = false, isEnableNotifications = false)

        assertEquals("Without notifications nothing may use a network the user restricted", SyncMode.SKIP, mode)
    }

    @Test
    fun test_background_sync_on_a_restricted_network_serves_only_notifications_when_they_are_on() {
        val mode = SyncMode.decide(isAppForeground = false, isBackgroundNetworkAllowed = false, isEnableNotifications = true)

        assertEquals(SyncMode.NOTIFICATIONS_ONLY, mode)
    }

    @Test
    fun test_background_sync_on_an_allowed_network_stays_full() {
        for (notifications in listOf(true, false)) {
            val mode = SyncMode.decide(isAppForeground = false, isBackgroundNetworkAllowed = true, isEnableNotifications = notifications)

            assertEquals("notifications=$notifications", SyncMode.FULL, mode)
        }
    }

    @Test
    fun test_foreground_sync_stays_full_on_any_network() {
        for (networkAllowed in listOf(true, false)) {
            for (notifications in listOf(true, false)) {
                val mode =
                    SyncMode.decide(
                        isAppForeground = true,
                        isBackgroundNetworkAllowed = networkAllowed,
                        isEnableNotifications = notifications,
                    )

                assertEquals("networkAllowed=$networkAllowed notifications=$notifications", SyncMode.FULL, mode)
            }
        }
    }
}
