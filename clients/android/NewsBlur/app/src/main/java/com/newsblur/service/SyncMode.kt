package com.newsblur.service

/**
 * How much SyncService.kt may download on one sync run. The Download using setting keeps offline stories
 * and images off a restricted network, but story notifications come from the same background sync, so
 * NOTIFICATIONS_ONLY lets UnreadsSubService.kt fetch just the unread stories of notification feeds there.
 */
enum class SyncMode {
    FULL,
    NOTIFICATIONS_ONLY,
    SKIP,
    ;

    companion object {
        fun decide(
            isAppForeground: Boolean,
            isBackgroundNetworkAllowed: Boolean,
            isEnableNotifications: Boolean,
        ): SyncMode =
            when {
                isAppForeground || isBackgroundNetworkAllowed -> FULL
                isEnableNotifications -> NOTIFICATIONS_ONLY
                else -> SKIP
            }
    }
}
