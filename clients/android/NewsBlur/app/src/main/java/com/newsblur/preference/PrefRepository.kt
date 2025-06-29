package com.newsblur.preference

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Bitmap.CompressFormat
import android.graphics.BitmapFactory
import android.net.ConnectivityManager
import android.os.Build
import android.util.Log
import androidx.annotation.WorkerThread
import androidx.core.content.FileProvider
import androidx.core.content.edit
import com.newsblur.R
import com.newsblur.activity.Login
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.UserDetails
import com.newsblur.network.APIConstants
import com.newsblur.service.NBSyncService
import com.newsblur.service.SubscriptionSyncService.Companion.cancel
import com.newsblur.util.AppConstants
import com.newsblur.util.DefaultBrowser
import com.newsblur.util.DefaultFeedView
import com.newsblur.util.FeedListOrder
import com.newsblur.util.FeedOrderFilter
import com.newsblur.util.FeedSet
import com.newsblur.util.FolderViewFilter
import com.newsblur.util.Font
import com.newsblur.util.GestureAction
import com.newsblur.util.ListOrderFilter
import com.newsblur.util.MarkAllReadConfirmation
import com.newsblur.util.MarkStoryReadBehavior
import com.newsblur.util.NotificationUtils
import com.newsblur.util.PrefConstants
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.PrefsUtils
import com.newsblur.util.ReadFilter
import com.newsblur.util.SpacingStyle
import com.newsblur.util.StateFilter
import com.newsblur.util.StoryContentPreviewStyle
import com.newsblur.util.StoryListStyle
import com.newsblur.util.StoryOrder
import com.newsblur.util.ThumbnailStyle
import com.newsblur.util.VolumeKeyNavigation
import com.newsblur.util.WidgetBackground
import com.newsblur.widget.WidgetUtils.disableWidgetUpdate
import com.newsblur.widget.WidgetUtils.hasActiveAppWidgets
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.URL
import java.util.Date

class PrefRepository(
        private val sharedPreferences: SharedPreferences,
) {

    fun load() {}

    fun saveCustomServer(customServer: String?) {
        if (customServer == null) return
        if (customServer.isEmpty()) return
        sharedPreferences.edit {
            putString(PrefConstants.PREF_CUSTOM_SERVER, customServer)
        }
    }

    fun getCustomSever(): String? =
            sharedPreferences.getString(PrefConstants.PREF_CUSTOM_SERVER, null)

    fun clearCustomServer() {
        sharedPreferences.edit {
            remove(PrefConstants.PREF_CUSTOM_SERVER)
        }
    }

    fun saveLogin(context: Context, userName: String, cookie: String?) {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val edit = preferences.edit()
        edit.putString(PrefConstants.PREF_COOKIE, cookie)
        edit.putString(PrefConstants.PREF_UNIQUE_LOGIN, userName + "_" + System.currentTimeMillis())
        edit.commit()
    }

    fun checkForUpgrade(context: Context): Boolean {
        val version = getVersion(context)
        if (version == null) {
            Log.wtf(PrefsUtils::class.java.name, "could not determine app version")
            return false
        }
        if (AppConstants.VERBOSE_LOG) Log.i(PrefsUtils::class.java.name, "launching version: $version")

        val oldVersion = sharedPreferences.getString(AppConstants.LAST_APP_VERSION, null)
        if ((oldVersion == null) || (oldVersion != version)) {
            com.newsblur.util.Log.i(PrefsUtils::class.java.name, "detected new version of app:$version")
            return true
        }
        return false
    }

    fun updateVersion(appVersion: String?) {
        // store the current version
        sharedPreferences.edit {
            putString(AppConstants.LAST_APP_VERSION, appVersion)
        }
        // also make sure we auto-trigger an update, since all data are now gone
        sharedPreferences.edit { putLong(AppConstants.LAST_SYNC_TIME, 0L) }
    }

    fun getVersion(context: Context): String? {
        try {
            return context.packageManager.getPackageInfo(context.packageName, 0).versionName
        } catch (nnfe: PackageManager.NameNotFoundException) {
            Log.w(PrefsUtils::class.java.name, "could not determine app version")
            return null
        }
    }

    fun createFeedbackLink(context: Context, dbHelper: BlurDatabaseHelper): String {
        val s = StringBuilder(AppConstants.FEEDBACK_URL)
        s.append("<give us some feedback!>%0A%0A%0A")
        val info = getDebugInfo(context, dbHelper)
        s.append(info.replace("\n", "%0A"))
        return s.toString()
    }

    fun sendLogEmail(context: Context, dbHelper: BlurDatabaseHelper) {
        val f = com.newsblur.util.Log.getLogfile() ?: return
        val debugInfo = """
             Tell us a bit about your problem:
             
             
             
             ${getDebugInfo(context, dbHelper)}
             """.trimIndent()
        val localPath = FileProvider.getUriForFile(context, "com.newsblur.fileprovider", f)
        val i = Intent(Intent.ACTION_SEND)
        i.setType("*/*")
        i.putExtra(Intent.EXTRA_EMAIL, arrayOf("android@newsblur.com"))
        i.putExtra(Intent.EXTRA_SUBJECT, "Android logs (" + getUserName() + ")")
        i.putExtra(Intent.EXTRA_TEXT, debugInfo)
        i.putExtra(Intent.EXTRA_STREAM, localPath)
        if (i.resolveActivity(context.packageManager) != null) {
            context.startActivity(i)
        }
    }

    private fun getDebugInfo(context: Context, dbHelper: BlurDatabaseHelper): String {
        val s = StringBuilder()
        s.append("app version: ").append(getVersion(context))
        s.append("\n")
        s.append("android version: ").append(Build.VERSION.RELEASE).append(" (").append(Build.DISPLAY).append(")")
        s.append("\n")
        s.append("device: ").append(Build.MANUFACTURER).append(" ").append(Build.MODEL).append(" (").append(Build.BOARD).append(")")
        s.append("\n")
        s.append("sqlite version: ").append(dbHelper.engineVersion)
        s.append("\n")
        s.append("username: ").append(getUserName())
        s.append("\n")
        s.append("server: ").append(if (APIConstants.isCustomServer()) "custom" else "default")
        s.append("\n")
        s.append("speed: ").append(NBSyncService.getSpeedInfo())
        s.append("\n")
        s.append("pending actions: ").append(NBSyncService.getPendingInfo())
        s.append("\n")
        s.append("premium: ")
        if (NBSyncService.isPremium === java.lang.Boolean.TRUE) {
            s.append("yes")
        } else if (NBSyncService.isPremium === java.lang.Boolean.FALSE) {
            s.append("no")
        } else {
            s.append("unknown")
        }
        s.append("\n")
        s.append("prefetch: ").append(if (isOfflineEnabled()) "yes" else "no")
        s.append("\n")
        s.append("notifications: ").append(if (isEnableNotifications()) "yes" else "no")
        s.append("\n")
        s.append("keepread: ").append(if (isKeepOldStories()) "yes" else "no")
        s.append("\n")
        s.append("thumbs: ").append(if (isShowThumbnails(context)) "yes" else "no")
        s.append("\n")
        return s.toString()
    }

    fun logout(context: Context, dbHelper: BlurDatabaseHelper) {
        NBSyncService.softInterrupt()
        NBSyncService.clearState()

        // cancel scheduled subscription sync service
        cancel(context)

        NotificationUtils.clear(context)

        // wipe the prefs store
        sharedPreferences.edit { clear() }

        // wipe the local DB
        dbHelper.dropAndRecreateTables()

        // disable widget
        disableWidgetUpdate(context)

        // reset custom server
        APIConstants.unsetCustomServer()


        // prompt for a new login
        val i = Intent(context, Login::class.java)
        i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        context.startActivity(i)
    }

    fun clearPrefsAndDbForLoginAs(dbHelper: BlurDatabaseHelper) {
        NBSyncService.softInterrupt()
        NBSyncService.clearState()

        // wipe the prefs store except for the cookie and login keys since we need to
        // authenticate further API calls
        val keys: MutableSet<String> = HashSet(sharedPreferences.all.keys)
        keys.remove(PrefConstants.PREF_COOKIE)
        keys.remove(PrefConstants.PREF_UNIQUE_LOGIN)
        keys.remove(PrefConstants.PREF_CUSTOM_SERVER)
        sharedPreferences.edit(commit = true) {
            for (key in keys) {
                remove(key)
            }
        }

        // wipe the local DB
        dbHelper.dropAndRecreateTables()
    }

    /**
     * Retrieves the current unique login key. This key will be unique for each
     * login. If this login key doesn't match the login key you have then assume
     * the user is logged out
     */
    fun getUniqueLoginKey(): String? = sharedPreferences.getString(PrefConstants.PREF_UNIQUE_LOGIN, null)

    fun getCustomServer(context: Context): String? {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return preferences.getString(PrefConstants.PREF_CUSTOM_SERVER, null)
    }

    fun saveUserDetails(context: Context, profile: UserDetails) {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val edit = preferences.edit()
        edit.putInt(PrefConstants.USER_AVERAGE_STORIES_PER_MONTH, profile.averageStoriesPerMonth)
        edit.putString(PrefConstants.USER_BIO, profile.bio)
        edit.putString(PrefConstants.USER_FEED_ADDRESS, profile.feedAddress)
        edit.putString(PrefConstants.USER_FEED_TITLE, profile.feedTitle)
        edit.putInt(PrefConstants.USER_FOLLOWER_COUNT, profile.followerCount)
        edit.putInt(PrefConstants.USER_FOLLOWING_COUNT, profile.followingCount)
        edit.putString(PrefConstants.USER_ID, profile.userId)
        edit.putString(PrefConstants.USER_LOCATION, profile.location)
        edit.putString(PrefConstants.USER_PHOTO_SERVICE, profile.photoService)
        edit.putString(PrefConstants.USER_PHOTO_URL, profile.photoUrl)
        edit.putInt(PrefConstants.USER_SHARED_STORIES_COUNT, profile.sharedStoriesCount)
        edit.putInt(PrefConstants.USER_STORIES_LAST_MONTH, profile.storiesLastMonth)
        edit.putInt(PrefConstants.USER_SUBSCRIBER_COUNT, profile.subscriptionCount)
        edit.putString(PrefConstants.USER_USERNAME, profile.username)
        edit.putString(PrefConstants.USER_WEBSITE, profile.website)
        edit.commit()
        saveUserImage(context, profile.photoUrl)
    }

    fun getUserId(): String? = sharedPreferences.getString(PrefConstants.USER_ID, null)

    fun getUserName(): String? = sharedPreferences.getString(PrefConstants.USER_USERNAME, null)

    fun getUserDetails(): UserDetails {
        val user = UserDetails()

        user.averageStoriesPerMonth = sharedPreferences.getInt(PrefConstants.USER_AVERAGE_STORIES_PER_MONTH, 0)
        user.bio = sharedPreferences.getString(PrefConstants.USER_BIO, null)
        user.feedAddress = sharedPreferences.getString(PrefConstants.USER_FEED_ADDRESS, null)
        user.feedTitle = sharedPreferences.getString(PrefConstants.USER_FEED_TITLE, null)
        user.followerCount = sharedPreferences.getInt(PrefConstants.USER_FOLLOWER_COUNT, 0)
        user.followingCount = sharedPreferences.getInt(PrefConstants.USER_FOLLOWING_COUNT, 0)
        user.id = sharedPreferences.getString(PrefConstants.USER_ID, null)
        user.location = sharedPreferences.getString(PrefConstants.USER_LOCATION, null)
        user.photoService = sharedPreferences.getString(PrefConstants.USER_PHOTO_SERVICE, null)
        user.photoUrl = sharedPreferences.getString(PrefConstants.USER_PHOTO_URL, null)
        user.sharedStoriesCount = sharedPreferences.getInt(PrefConstants.USER_SHARED_STORIES_COUNT, 0)
        user.storiesLastMonth = sharedPreferences.getInt(PrefConstants.USER_STORIES_LAST_MONTH, 0)
        user.subscriptionCount = sharedPreferences.getInt(PrefConstants.USER_SUBSCRIBER_COUNT, 0)
        user.username = sharedPreferences.getString(PrefConstants.USER_USERNAME, null)
        user.website = sharedPreferences.getString(PrefConstants.USER_WEBSITE, null)

        return user
    }

    private fun saveUserImage(context: Context, pictureUrl: String) {
        val bitmap: Bitmap
        try {
            val url = URL(pictureUrl)
            val connection = url.openConnection()
            connection.useCaches = true
            bitmap = BitmapFactory.decodeStream(connection.content as InputStream)

            val file = context.cacheDir
            val imageFile = File(file.path + "/userProfilePicture")
            bitmap.compress(CompressFormat.PNG, 100, FileOutputStream(imageFile))
        } catch (e: Exception) {
            // this can fail for a huge number of reasons, from storage problems to
            // missing image codecs. if it fails, a placeholder will be used
            Log.e(PrefsUtils::class.java.name, "couldn't save user profile image", e)
        }
    }

    @WorkerThread
    fun getUserImage(context: Context): Bitmap? = BitmapFactory.decodeFile(context.cacheDir.path + "/userProfilePicture")

    /**
     * Check to see if it has been sufficiently long since the last sync of the feed/folder
     * data to justify automatically syncing again.
     */
    fun isTimeToAutoSync(): Boolean {
        val lastTime = sharedPreferences.getLong(AppConstants.LAST_SYNC_TIME, 1L)
        return ((lastTime + AppConstants.AUTO_SYNC_TIME_MILLIS) < (Date()).time)
    }

    /**
     * Make note that a sync of the feed/folder list has been completed, so we can track
     * how long it has been until another is needed.
     */
    fun updateLastSyncTime() {
        sharedPreferences.edit { putLong(AppConstants.LAST_SYNC_TIME, (Date()).time) }
    }

    private fun getLastVacuumTime(): Long =
            sharedPreferences.getLong(PrefConstants.LAST_VACUUM_TIME, 1L)

    fun isTimeToVacuum(): Boolean {
        val lastTime = getLastVacuumTime()
        val now = (Date()).time
        return ((lastTime + AppConstants.VACUUM_TIME_MILLIS) < now)
    }

    fun updateLastVacuumTime() {
        sharedPreferences.edit { putLong(PrefConstants.LAST_VACUUM_TIME, (Date()).time) }
    }

    fun isTimeToCleanup(): Boolean {
        val lastTime = sharedPreferences.getLong(PrefConstants.LAST_CLEANUP_TIME, 1L)
        val nowTime = (Date()).time
        return (lastTime + AppConstants.CLEANUP_TIME_MILLIS) < nowTime
    }

    fun updateLastCleanupTime() {
        sharedPreferences.edit { putLong(PrefConstants.LAST_CLEANUP_TIME, (Date()).time) }
    }

    fun getStoryOrderForFeed(feedId: String): StoryOrder =
            StoryOrder.valueOf(sharedPreferences.getString(PrefConstants.FEED_STORY_ORDER_PREFIX + feedId, getDefaultStoryOrder(sharedPreferences).toString())!!)

    fun getStoryOrderForFolder(folderName: String): StoryOrder =
            StoryOrder.valueOf(sharedPreferences.getString(PrefConstants.FOLDER_STORY_ORDER_PREFIX + folderName, getDefaultStoryOrder(sharedPreferences).toString())!!)

    fun getReadFilterForFeed(feedId: String): ReadFilter =
            ReadFilter.valueOf(sharedPreferences.getString(PrefConstants.FEED_READ_FILTER_PREFIX + feedId, getDefaultReadFilter(sharedPreferences).toString())!!)

    fun getReadFilterForFolder(folderName: String): ReadFilter =
            ReadFilter.valueOf(sharedPreferences.getString(PrefConstants.FOLDER_READ_FILTER_PREFIX + folderName, getDefaultReadFilter(sharedPreferences).toString())!!)

    fun setStoryOrderForFolder(folderName: String, newValue: StoryOrder) {
        sharedPreferences.edit {
            putString(PrefConstants.FOLDER_STORY_ORDER_PREFIX + folderName, newValue.toString())
        }
    }

    fun setStoryOrderForFeed(feedId: String, newValue: StoryOrder) {
        sharedPreferences.edit {
            putString(PrefConstants.FEED_STORY_ORDER_PREFIX + feedId, newValue.toString())
        }
    }

    fun setReadFilterForFolder(folderName: String, newValue: ReadFilter) {
        sharedPreferences.edit {
            putString(PrefConstants.FOLDER_READ_FILTER_PREFIX + folderName, newValue.toString())
        }
    }

    fun setReadFilterForFeed(feedId: String, newValue: ReadFilter) {
        sharedPreferences.edit {
            putString(PrefConstants.FEED_READ_FILTER_PREFIX + feedId, newValue.toString())
        }
    }

    fun getStoryListStyleForFeed(feedId: String): StoryListStyle =
            StoryListStyle.safeValueOf(sharedPreferences.getString(PrefConstants.FEED_STORY_LIST_STYLE_PREFIX + feedId, StoryListStyle.LIST.toString()))

    fun getStoryListStyleForFolder(folderName: String): StoryListStyle =
            StoryListStyle.safeValueOf(sharedPreferences.getString(PrefConstants.FOLDER_STORY_LIST_STYLE_PREFIX + folderName, StoryListStyle.LIST.toString()))

    fun setStoryListStyleForFolder(folderName: String, newValue: StoryListStyle) {
        sharedPreferences.edit {
            putString(PrefConstants.FOLDER_STORY_LIST_STYLE_PREFIX + folderName, newValue.toString())
        }
    }

    fun setStoryListStyleForFeed(feedId: String, newValue: StoryListStyle) {
        sharedPreferences.edit {
            putString(PrefConstants.FEED_STORY_LIST_STYLE_PREFIX + feedId, newValue.toString())
        }
    }

    private fun getDefaultStoryOrder(prefs: SharedPreferences): StoryOrder =
            StoryOrder.valueOf(prefs.getString(PrefConstants.DEFAULT_STORY_ORDER, StoryOrder.NEWEST.toString())!!)

    fun getDefaultStoryOrder(): StoryOrder = getDefaultStoryOrder(sharedPreferences)

    private fun getDefaultReadFilter(prefs: SharedPreferences): ReadFilter =
            ReadFilter.valueOf(prefs.getString(PrefConstants.DEFAULT_READ_FILTER, ReadFilter.ALL.toString())!!)

    fun isEnableRowGlobalShared(): Boolean =
            sharedPreferences.getBoolean(PrefConstants.ENABLE_ROW_GLOBAL_SHARED, true)

    fun isEnableRowInfrequent(): Boolean =
            sharedPreferences.getBoolean(PrefConstants.ENABLE_ROW_INFREQUENT_STORIES, true)

    fun showPublicComments(): Boolean =
            sharedPreferences.getBoolean(PrefConstants.SHOW_PUBLIC_COMMENTS, true)

    fun getReadingTextSize(): Float =
            sharedPreferences.getFloat(PrefConstants.PREFERENCE_TEXT_SIZE, 1.0f)

    fun setReadingTextSize(size: Float) {
        sharedPreferences.edit {
            putFloat(PrefConstants.PREFERENCE_TEXT_SIZE, size)
        }
    }

    fun getListTextSize(): Float =
            sharedPreferences.getFloat(PrefConstants.PREFERENCE_LIST_TEXT_SIZE, 1.0f)

    fun setListTextSize(size: Float) {
        sharedPreferences.edit {
            putFloat(PrefConstants.PREFERENCE_LIST_TEXT_SIZE, size)
        }
    }

    fun getInfrequentCutoff(): Int =
            sharedPreferences.getInt(PrefConstants.PREFERENCE_INFREQUENT_CUTOFF, 30)

    fun setInfrequentCutoff(newValue: Int) {
        sharedPreferences.edit {
            putInt(PrefConstants.PREFERENCE_INFREQUENT_CUTOFF, newValue)
        }
    }

//    fun getDefaultViewModeForFeed(context: Context, feedId: String?): DefaultFeedView {
//        if ((feedId == null) || (feedId == 0)) return DefaultFeedView.STORY
//        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
//        return DefaultFeedView.valueOf(prefs.getString(PrefConstants.FEED_DEFAULT_FEED_VIEW_PREFIX + feedId, getDefaultFeedView().toString())!!)
//    }
//
//    fun setDefaultViewModeForFeed(context: Context, feedId: String?, newValue: DefaultFeedView) {
//        if ((feedId == null) || (feedId == 0)) return
//        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
//        val editor = prefs.edit()
//        editor.putString(PrefConstants.FEED_DEFAULT_FEED_VIEW_PREFIX + feedId, newValue.toString())
//        editor.commit()
//    }

    fun getStoryOrder(fs: FeedSet): StoryOrder {
        if (fs.isAllNormal) {
            return getStoryOrderForFolder(PrefConstants.ALL_STORIES_FOLDER_NAME)
        } else if (fs.singleFeed != null) {
            return getStoryOrderForFeed(fs.singleFeed)
        } else if (fs.multipleFeeds != null) {
            return getStoryOrderForFolder(fs.folderName)
        } else if (fs.isAllSocial) {
            return getStoryOrderForFolder(PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME)
        } else if (fs.singleSocialFeed != null) {
            return getStoryOrderForFeed(fs.singleSocialFeed.key)
        } else require(fs.multipleSocialFeeds == null) { "requests for multiple social feeds not supported" }
        return if (fs.isAllRead) {
            // dummy value, not really used
            StoryOrder.NEWEST
        } else if (fs.isAllSaved) {
            getStoryOrderForFolder(PrefConstants.SAVED_STORIES_FOLDER_NAME)
        } else if (fs.singleSavedTag != null) {
            getStoryOrderForFolder(PrefConstants.SAVED_STORIES_FOLDER_NAME)
        } else if (fs.isGlobalShared) {
            StoryOrder.NEWEST
        } else if (fs.isInfrequent) {
            getStoryOrderForFolder(PrefConstants.INFREQUENT_FOLDER_NAME)
        } else {
            throw IllegalArgumentException("unknown type of feed set")
        }
    }

    fun updateStoryOrder(fs: FeedSet, newOrder: StoryOrder) {
        if (fs.isAllNormal) {
            setStoryOrderForFolder(PrefConstants.ALL_STORIES_FOLDER_NAME, newOrder)
        } else if (fs.singleFeed != null) {
            setStoryOrderForFeed(fs.singleFeed, newOrder)
        } else if (fs.multipleFeeds != null) {
            setStoryOrderForFolder(fs.folderName, newOrder)
        } else if (fs.isAllSocial) {
            setStoryOrderForFolder(PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME, newOrder)
        } else if (fs.singleSocialFeed != null) {
            setStoryOrderForFeed(fs.singleSocialFeed.key, newOrder)
        } else require(fs.multipleSocialFeeds == null) { "multiple social feeds not supported" }
        require(!fs.isAllRead) { "AllRead FeedSet type has fixed ordering" }
        if (fs.isAllSaved) {
            setStoryOrderForFolder(PrefConstants.SAVED_STORIES_FOLDER_NAME, newOrder)
        } else if (fs.singleSavedTag != null) {
            setStoryOrderForFolder(PrefConstants.SAVED_STORIES_FOLDER_NAME, newOrder)
        } else require(!fs.isGlobalShared) { "GlobalShared FeedSet type has fixed ordering" }
        if (fs.isInfrequent) {
            setStoryOrderForFolder(PrefConstants.INFREQUENT_FOLDER_NAME, newOrder)
        } else {
            throw IllegalArgumentException("unknown type of feed set")
        }
    }

    fun getReadFilter(fs: FeedSet): ReadFilter {
        if (fs.isAllNormal) {
            return getReadFilterForFolder(PrefConstants.ALL_STORIES_FOLDER_NAME)
        } else if (fs.singleFeed != null) {
            return getReadFilterForFeed(fs.singleFeed)
        } else if (fs.multipleFeeds != null) {
            return getReadFilterForFolder(fs.folderName)
        } else if (fs.isAllSocial) {
            return getReadFilterForFolder(PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME)
        } else if (fs.singleSocialFeed != null) {
            return getReadFilterForFeed(fs.singleSocialFeed.key)
        } else require(fs.multipleSocialFeeds == null) { "requests for multiple social feeds not supported" }
        if (fs.isAllRead) {
            // it would make no sense to look for read stories in unread-only
            return ReadFilter.ALL
        } else if (fs.isAllSaved) {
            // saved stories view doesn't track read status
            return ReadFilter.ALL
        } else if (fs.singleSavedTag != null) {
            // saved stories view doesn't track read status
            return ReadFilter.ALL
        } else if (fs.isGlobalShared) {
            return getReadFilterForFolder(PrefConstants.GLOBAL_SHARED_STORIES_FOLDER_NAME)
        } else if (fs.isInfrequent) {
            return getReadFilterForFolder(PrefConstants.INFREQUENT_FOLDER_NAME)
        }
        throw IllegalArgumentException("unknown type of feed set")
    }

    fun updateReadFilter(fs: FeedSet, newFilter: ReadFilter) {
        if (fs.isAllNormal) {
            setReadFilterForFolder(PrefConstants.ALL_STORIES_FOLDER_NAME, newFilter)
        } else if (fs.singleFeed != null) {
            setReadFilterForFeed(fs.singleFeed, newFilter)
        } else if (fs.multipleFeeds != null) {
            setReadFilterForFolder(fs.folderName, newFilter)
        } else if (fs.isAllSocial) {
            setReadFilterForFolder(PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME, newFilter)
        } else if (fs.singleSocialFeed != null) {
            setReadFilterForFeed(fs.singleSocialFeed.key, newFilter)
        } else if (fs.multipleSocialFeeds != null) {
            setReadFilterForFolder(fs.folderName, newFilter)
        } else require(!fs.isAllRead) { "read filter not applicable to this type of feedset" }
        require(!fs.isAllSaved) { "read filter not applicable to this type of feedset" }
        require(fs.singleSavedTag == null) { "read filter not applicable to this type of feedset" }
        if (fs.isGlobalShared) {
            setReadFilterForFolder(PrefConstants.GLOBAL_SHARED_STORIES_FOLDER_NAME, newFilter)
        } else if (fs.isInfrequent) {
            setReadFilterForFolder(PrefConstants.INFREQUENT_FOLDER_NAME, newFilter)
        } else {
            throw IllegalArgumentException("unknown type of feed set")
        }
    }

    fun getStoryListStyle(fs: FeedSet): StoryListStyle {
        if (fs.isAllNormal) {
            return getStoryListStyleForFolder(PrefConstants.ALL_STORIES_FOLDER_NAME)
        } else if (fs.singleFeed != null) {
            return getStoryListStyleForFeed(fs.singleFeed)
        } else if (fs.multipleFeeds != null) {
            return getStoryListStyleForFolder(fs.folderName)
        } else if (fs.isAllSocial) {
            return getStoryListStyleForFolder(PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME)
        } else if (fs.singleSocialFeed != null) {
            return getStoryListStyleForFeed(fs.singleSocialFeed.key)
        } else require(fs.multipleSocialFeeds == null) { "requests for multiple social feeds not supported" }
        return if (fs.isAllRead) {
            getStoryListStyleForFolder(PrefConstants.READ_STORIES_FOLDER_NAME)
        } else if (fs.isAllSaved) {
            getStoryListStyleForFolder(PrefConstants.SAVED_STORIES_FOLDER_NAME)
        } else if (fs.singleSavedTag != null) {
            getStoryListStyleForFolder(PrefConstants.SAVED_STORIES_FOLDER_NAME)
        } else if (fs.isGlobalShared) {
            getStoryListStyleForFolder(PrefConstants.GLOBAL_SHARED_STORIES_FOLDER_NAME)
        } else if (fs.isInfrequent) {
            getStoryListStyleForFolder(PrefConstants.INFREQUENT_FOLDER_NAME)
        } else {
            throw IllegalArgumentException("unknown type of feed set")
        }
    }

    fun updateStoryListStyle(fs: FeedSet, newListStyle: StoryListStyle) {
        if (fs.isAllNormal) {
            setStoryListStyleForFolder(PrefConstants.ALL_STORIES_FOLDER_NAME, newListStyle)
        } else if (fs.singleFeed != null) {
            setStoryListStyleForFeed(fs.singleFeed, newListStyle)
        } else if (fs.multipleFeeds != null) {
            setStoryListStyleForFolder(fs.folderName, newListStyle)
        } else if (fs.isAllSocial) {
            setStoryListStyleForFolder(PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME, newListStyle)
        } else if (fs.singleSocialFeed != null) {
            setStoryListStyleForFeed(fs.singleSocialFeed.key, newListStyle)
        } else require(fs.multipleSocialFeeds == null) { "multiple social feeds not supported" }
        if (fs.isAllRead) {
            setStoryListStyleForFolder(PrefConstants.READ_STORIES_FOLDER_NAME, newListStyle)
        } else if (fs.isAllSaved) {
            setStoryListStyleForFolder(PrefConstants.SAVED_STORIES_FOLDER_NAME, newListStyle)
        } else if (fs.singleSavedTag != null) {
            setStoryListStyleForFolder(PrefConstants.SAVED_STORIES_FOLDER_NAME, newListStyle)
        } else if (fs.isGlobalShared) {
            setStoryListStyleForFolder(PrefConstants.GLOBAL_SHARED_STORIES_FOLDER_NAME, newListStyle)
        } else if (fs.isInfrequent) {
            setStoryListStyleForFolder(PrefConstants.INFREQUENT_FOLDER_NAME, newListStyle)
        } else {
            throw IllegalArgumentException("unknown type of feed set")
        }
    }

    private fun getDefaultFeedView(): DefaultFeedView {
        return DefaultFeedView.STORY
    }

    fun getStoryContentPreviewStyle(): StoryContentPreviewStyle =
            StoryContentPreviewStyle.valueOf(sharedPreferences.getString(PrefConstants.STORIES_SHOW_PREVIEWS_STYLE, StoryContentPreviewStyle.MEDIUM.toString())!!)

    fun setStoryContentPreviewStyle(value: StoryContentPreviewStyle) {
        sharedPreferences.edit {
            putString(PrefConstants.STORIES_SHOW_PREVIEWS_STYLE, value.name)
        }
    }

    private fun isShowThumbnails(context: Context): Boolean {
        return getThumbnailStyle(context) != ThumbnailStyle.OFF
    }

    fun setThumbnailStyle(value: ThumbnailStyle) {
        sharedPreferences.edit {
            putString(PrefConstants.STORIES_THUMBNAIL_STYLE, value.name)
        }
    }


    fun getThumbnailStyle(context: Context): ThumbnailStyle {
        val defaultValue = context.getString(R.string.thumbnail_style_default_value)
        return ThumbnailStyle.valueOf(sharedPreferences.getString(PrefConstants.STORIES_THUMBNAIL_STYLE, defaultValue)!!)
    }

    fun isAutoOpenFirstUnread(): Boolean =
            sharedPreferences.getBoolean(PrefConstants.STORIES_AUTO_OPEN_FIRST, false)

    fun isMarkReadOnFeedScroll(): Boolean =
            sharedPreferences.getBoolean(PrefConstants.STORIES_MARK_READ_ON_SCROLL, false)

    fun setMarkReadOnScroll(value: Boolean) {
        sharedPreferences.edit {
            putBoolean(PrefConstants.STORIES_MARK_READ_ON_SCROLL, value)
        }
    }

    fun isOfflineEnabled(): Boolean =
            sharedPreferences.getBoolean(PrefConstants.ENABLE_OFFLINE, false)

    fun isImagePrefetchEnabled(): Boolean =
            sharedPreferences.getBoolean(PrefConstants.ENABLE_IMAGE_PREFETCH, false)

    /**
     * Compares the user's setting for when background data use is allowed against the
     * current network status and sees if it is okay to sync.
     */
    fun isBackgroundNetworkAllowed(context: Context): Boolean {
        val mode = sharedPreferences.getString(PrefConstants.NETWORK_SELECT, PrefConstants.NETWORK_SELECT_NOMONONME)!!

        val connMgr = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeInfo = connMgr.activeNetworkInfo

        // if we aren't even online, there is no way bg data will work
        if ((activeInfo == null) || (!activeInfo.isConnected)) return false

        // if user restricted use of mobile nets, make sure we aren't on one
        val type = activeInfo.type
        if (mode == PrefConstants.NETWORK_SELECT_NOMO) {
            if (!((type == ConnectivityManager.TYPE_WIFI) || (type == ConnectivityManager.TYPE_ETHERNET))) {
                return false
            }
        } else if (mode == PrefConstants.NETWORK_SELECT_NOMONONME) {
            if (!((type == ConnectivityManager.TYPE_WIFI) || (type == ConnectivityManager.TYPE_ETHERNET))) {
                return false
            }
            if (connMgr.isActiveNetworkMetered) {
                return false
            }
        }

        return true
    }

    fun isKeepOldStories(): Boolean =
            sharedPreferences.getBoolean(PrefConstants.KEEP_OLD_STORIES, false)

    fun getMaxCachedAgeMillis(): Long {
        val `val` = sharedPreferences.getString(PrefConstants.CACHE_AGE_SELECT, PrefConstants.CACHE_AGE_SELECT_30D)!!
        if (`val` == PrefConstants.CACHE_AGE_SELECT_2D) return PrefConstants.CACHE_AGE_VALUE_2D
        if (`val` == PrefConstants.CACHE_AGE_SELECT_7D) return PrefConstants.CACHE_AGE_VALUE_7D
        if (`val` == PrefConstants.CACHE_AGE_SELECT_14D) return PrefConstants.CACHE_AGE_VALUE_14D
        if (`val` == PrefConstants.CACHE_AGE_SELECT_30D) return PrefConstants.CACHE_AGE_VALUE_30D
        return PrefConstants.CACHE_AGE_VALUE_30D
    }

    fun getFeedListOrder(): FeedListOrder =
            FeedListOrder.valueOf(sharedPreferences.getString(PrefConstants.FEED_LIST_ORDER, FeedListOrder.ALPHABETICAL.toString())!!)

    fun getSelectedTheme(): ThemeValue {
        val value = sharedPreferences.getString(PrefConstants.THEME, ThemeValue.AUTO.name)!!
        // check for legacy hard-coded values. this can go away once installs of v152 or earlier are minimized
        if (value == "light") {
            setSelectedTheme(ThemeValue.LIGHT)
            return ThemeValue.LIGHT
        }
        if (value == "dark") {
            setSelectedTheme(ThemeValue.DARK)
            return ThemeValue.DARK
        }
        return ThemeValue.valueOf(value)
    }

    fun setSelectedTheme(value: ThemeValue) {
        sharedPreferences.edit {
            putString(PrefConstants.THEME, value.name)
        }
    }

    fun getStateFilter(): StateFilter = StateFilter.valueOf(sharedPreferences.getString(PrefConstants.STATE_FILTER, StateFilter.SOME.toString())!!)

    fun setStateFilter(newValue: StateFilter) {
        sharedPreferences.edit {
            putString(PrefConstants.STATE_FILTER, newValue.toString())
        }
    }

    fun getVolumeKeyNavigation(): VolumeKeyNavigation =
            VolumeKeyNavigation.valueOf(sharedPreferences.getString(PrefConstants.VOLUME_KEY_NAVIGATION, VolumeKeyNavigation.OFF.toString())!!)

    fun getMarkAllReadConfirmation(): MarkAllReadConfirmation =
            MarkAllReadConfirmation.valueOf(sharedPreferences.getString(PrefConstants.MARK_ALL_READ_CONFIRMATION, MarkAllReadConfirmation.FOLDER_ONLY.toString())!!)

    fun isConfirmMarkRangeRead(): Boolean =
            sharedPreferences.getBoolean(PrefConstants.MARK_RANGE_READ_CONFIRMATION, false)

    fun getLeftToRightGestureAction(): GestureAction =
            GestureAction.valueOf(sharedPreferences.getString(PrefConstants.LTR_GESTURE_ACTION, GestureAction.GEST_ACTION_MARKREAD.toString())!!)

    fun getRightToLeftGestureAction(): GestureAction =
            GestureAction.valueOf(sharedPreferences.getString(PrefConstants.RTL_GESTURE_ACTION, GestureAction.GEST_ACTION_MARKUNREAD.toString())!!)

    fun isEnableNotifications(): Boolean =
            sharedPreferences.getBoolean(PrefConstants.ENABLE_NOTIFICATIONS, false)

    fun isBackgroundNeeded(context: Context): Boolean =
            isEnableNotifications() || isOfflineEnabled() || hasActiveAppWidgets(context)

    fun getFont(): Font = Font.getFont(getFontString())

    fun getFontString(): String =
            sharedPreferences.getString(PrefConstants.READING_FONT, Font.DEFAULT.toString())!!

    fun setFontString(newValue: String?) {
        sharedPreferences.edit {
            putString(PrefConstants.READING_FONT, newValue)
        }
    }

    fun setWidgetFeedIds(context: Context, feedIds: Set<String?>?) {
        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val editor = prefs.edit()
        editor.putStringSet(PrefConstants.WIDGET_FEED_SET, feedIds)
        editor.commit()
    }

    fun getWidgetFeedIds(context: Context): Set<String>? {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return preferences.getStringSet(PrefConstants.WIDGET_FEED_SET, null)
    }

    fun removeWidgetData(context: Context) {
        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val editor = prefs.edit()
        if (prefs.contains(PrefConstants.WIDGET_FEED_SET)) {
            editor.remove(PrefConstants.WIDGET_FEED_SET)
        }
        if (prefs.contains(PrefConstants.WIDGET_BACKGROUND)) {
            editor.remove(PrefConstants.WIDGET_BACKGROUND)
        }
        editor.apply()
    }

    fun getFeedChooserFeedOrder(context: Context): FeedOrderFilter {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return FeedOrderFilter.valueOf(preferences.getString(PrefConstants.FEED_CHOOSER_FEED_ORDER, FeedOrderFilter.NAME.toString())!!)
    }

    fun setFeedChooserFeedOrder(context: Context, feedOrderFilter: FeedOrderFilter) {
        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val editor = prefs.edit()
        editor.putString(PrefConstants.FEED_CHOOSER_FEED_ORDER, feedOrderFilter.toString())
        editor.commit()
    }

    fun getFeedChooserListOrder(context: Context): ListOrderFilter {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return ListOrderFilter.valueOf(preferences.getString(PrefConstants.FEED_CHOOSER_LIST_ORDER, ListOrderFilter.ASCENDING.name)!!)
    }

    fun setFeedChooserListOrder(context: Context, listOrderFilter: ListOrderFilter) {
        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val editor = prefs.edit()
        editor.putString(PrefConstants.FEED_CHOOSER_LIST_ORDER, listOrderFilter.toString())
        editor.commit()
    }

    fun getFeedChooserFolderView(context: Context): FolderViewFilter {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return FolderViewFilter.valueOf(preferences.getString(PrefConstants.FEED_CHOOSER_FOLDER_VIEW, FolderViewFilter.NESTED.name)!!)
    }

    fun setFeedChooserFolderView(context: Context, folderViewFilter: FolderViewFilter) {
        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val editor = prefs.edit()
        editor.putString(PrefConstants.FEED_CHOOSER_FOLDER_VIEW, folderViewFilter.toString())
        editor.commit()
    }

    fun getWidgetBackground(context: Context): WidgetBackground {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return WidgetBackground.valueOf(preferences.getString(PrefConstants.WIDGET_BACKGROUND, WidgetBackground.DEFAULT.name)!!)
    }

    fun setWidgetBackground(context: Context, widgetBackground: WidgetBackground) {
        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val editor = prefs.edit()
        editor.putString(PrefConstants.WIDGET_BACKGROUND, widgetBackground.toString())
        editor.commit()
    }

    fun getDefaultBrowser(context: Context): DefaultBrowser {
        return DefaultBrowser.getDefaultBrowser(getDefaultBrowserString(context))
    }

    fun getDefaultBrowserString(context: Context): String {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return preferences.getString(PrefConstants.DEFAULT_BROWSER, DefaultBrowser.SYSTEM_DEFAULT.toString())!!
    }

    fun setArchive(context: Context, isArchive: Boolean, archiveExpire: Long?) {
        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val editor = prefs.edit()
        editor.putBoolean(PrefConstants.IS_ARCHIVE, isArchive)
        if (archiveExpire != null) {
            editor.putLong(PrefConstants.SUBSCRIPTION_EXPIRE, archiveExpire)
        }
        editor.commit()
    }

    fun getIsArchive(context: Context): Boolean {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return preferences.getBoolean(PrefConstants.IS_ARCHIVE, false)
    }

    fun setPremium(context: Context, isPremium: Boolean, premiumExpire: Long?) {
        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val editor = prefs.edit()
        editor.putBoolean(PrefConstants.IS_PREMIUM, isPremium)
        if (premiumExpire != null) {
            editor.putLong(PrefConstants.SUBSCRIPTION_EXPIRE, premiumExpire)
        }
        editor.commit()
    }

    fun getIsPremium(context: Context): Boolean {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return preferences.getBoolean(PrefConstants.IS_PREMIUM, false)
    }

    fun getSubscriptionExpire(context: Context): Long {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return preferences.getLong(PrefConstants.SUBSCRIPTION_EXPIRE, -1)
    }

    fun hasSubscription(context: Context): Boolean {
        return getIsPremium(context) || getIsArchive(context)
    }

    fun hasInAppReviewed(context: Context): Boolean {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return preferences.getBoolean(PrefConstants.IN_APP_REVIEW, false)
    }

    fun setInAppReviewed(context: Context) {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val editor = preferences.edit()
        editor.putBoolean(PrefConstants.IN_APP_REVIEW, true)
        editor.commit()
    }

    fun getSpacingStyle(context: Context): SpacingStyle {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return SpacingStyle.valueOf(preferences.getString(PrefConstants.SPACING_STYLE, SpacingStyle.COMFORTABLE.name)!!)
    }

    fun setSpacingStyle(context: Context, spacingStyle: SpacingStyle) {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val editor = preferences.edit()
        editor.putString(PrefConstants.SPACING_STYLE, spacingStyle.toString())
        editor.commit()
    }

    /**
     * Check for logged in user.
     * @return whether a cookie is stored on disk
     * which gets saved when a user is authenticated.
     */
    fun hasCookie(): Boolean = getCookie() != null

    fun getCookie(): String? =
            sharedPreferences.getString(PrefConstants.PREF_COOKIE, null)

    fun getMarkStoryReadBehavior(): MarkStoryReadBehavior =
            MarkStoryReadBehavior.valueOf(sharedPreferences.getString(PrefConstants.STORY_MARK_READ_BEHAVIOR, MarkStoryReadBehavior.IMMEDIATELY.name)!!)

    fun loadNextOnMarkRead(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        return prefs.getBoolean(PrefConstants.LOAD_NEXT_ON_MARK_READ, false)
    }

    fun setExtToken(context: Context, token: String?) {
        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val editor = prefs.edit()
        editor.putString(PrefConstants.EXT_TOKEN, token)
        editor.commit()
    }

    fun getExtToken(): String? = sharedPreferences.getString(PrefConstants.EXT_TOKEN, null)
}