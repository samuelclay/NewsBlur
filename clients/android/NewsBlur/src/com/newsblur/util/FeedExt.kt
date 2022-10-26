package com.newsblur.util

import com.newsblur.domain.Feed

object FeedExt {

    fun Feed.isNotifyEmail(): Boolean = isNotify(NOTIFY_EMAIL)

    fun Feed.isNotifyWeb(): Boolean = isNotify(NOTIFY_WEB)

    fun Feed.isNotifyIOS(): Boolean = isNotify(NOTIFY_IOS)

    fun Feed.isNotifyAndroid(): Boolean = isNotify(NOTIFY_ANDROID)

    fun Feed.enableNotificationType(type: String) {
        if (notificationTypes == null) notificationTypes = mutableListOf()
        if (!notificationTypes.contains(type)) notificationTypes.add(type)
    }

    fun Feed.disableNotificationType(type: String) {
        notificationTypes?.remove(type)
    }

    fun Feed.disableNotification() {
        notificationFilter = null
    }

    @JvmStatic
    fun Feed.isAndroidNotifyUnread(): Boolean = isNotifyUnread() && isNotifyAndroid()

    @JvmStatic
    fun Feed.isAndroidNotifyFocus(): Boolean = isNotifyFocus() && isNotifyAndroid()

    @JvmStatic
    fun Feed.isNotifyUnread(): Boolean = notificationFilter == Feed.NOTIFY_FILTER_UNREAD

    @JvmStatic
    fun Feed.isNotifyFocus(): Boolean = notificationFilter == Feed.NOTIFY_FILTER_FOCUS

    fun Feed.setNotifyFocus() {
        notificationFilter = Feed.NOTIFY_FILTER_FOCUS
    }

    fun Feed.setNotifyUnread() {
        notificationFilter = Feed.NOTIFY_FILTER_UNREAD
    }

    private fun Feed.isNotify(type: String): Boolean = notificationTypes?.contains(type) ?: false

    const val NOTIFY_EMAIL = "email"
    const val NOTIFY_WEB = "web"
    const val NOTIFY_IOS = "ios"
    const val NOTIFY_ANDROID = "android"
}