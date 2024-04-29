package com.newsblur

import com.newsblur.domain.Feed
import com.newsblur.util.FeedExt.NOTIFY_ANDROID
import com.newsblur.util.FeedExt.disableNotification
import com.newsblur.util.FeedExt.disableNotificationType
import com.newsblur.util.FeedExt.enableNotificationType
import com.newsblur.util.FeedExt.setNotifyFocus
import com.newsblur.util.FeedExt.setNotifyUnread
import org.junit.Assert
import org.junit.Test

class FeedNotificationPrefsTest {

    @Test
    fun enableUnreadNotif() {
        val feed = Feed.getZeroFeed()
        Assert.assertEquals(null, feed.notificationFilter)
        Assert.assertEquals(null, feed.notificationTypes)

        feed.setNotifyUnread()
        Assert.assertEquals(Feed.NOTIFY_FILTER_UNREAD, feed.notificationFilter)
        Assert.assertTrue(feed.notificationTypes.contains(NOTIFY_ANDROID))
    }

    @Test
    fun enableFocusNotif() {
        val feed = Feed.getZeroFeed()
        Assert.assertEquals(null, feed.notificationFilter)
        Assert.assertEquals(null, feed.notificationTypes)

        feed.setNotifyFocus()
        Assert.assertEquals(Feed.NOTIFY_FILTER_FOCUS, feed.notificationFilter)
        Assert.assertTrue(feed.notificationTypes.contains(NOTIFY_ANDROID))
    }

    @Test
    fun disableNotif() {
        val feed = Feed.getZeroFeed()
        Assert.assertEquals(null, feed.notificationFilter)
        Assert.assertEquals(null, feed.notificationTypes)

        feed.setNotifyFocus()
        Assert.assertEquals(Feed.NOTIFY_FILTER_FOCUS, feed.notificationFilter)
        Assert.assertTrue(feed.notificationTypes.contains(NOTIFY_ANDROID))

        feed.disableNotification()
        Assert.assertEquals(null, feed.notificationFilter)
        Assert.assertFalse(feed.notificationTypes.contains(NOTIFY_ANDROID))
    }

    @Test
    fun enableNotificationTypeTest() {
        val feed = Feed.getZeroFeed()
        Assert.assertEquals(null, feed.notificationTypes)

        feed.enableNotificationType(NOTIFY_ANDROID)
        Assert.assertTrue(feed.notificationTypes.contains(NOTIFY_ANDROID))
    }

    @Test
    fun disableNotificationTypeTest() {
        val feed = Feed.getZeroFeed()
        Assert.assertEquals(null, feed.notificationTypes)

        feed.enableNotificationType(NOTIFY_ANDROID)
        Assert.assertTrue(feed.notificationTypes.contains(NOTIFY_ANDROID))

        feed.disableNotificationType(NOTIFY_ANDROID)
        Assert.assertFalse(feed.notificationTypes.contains(NOTIFY_ANDROID))
    }
}