package com.newsblur.activity

import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.drawable.GradientDrawable
import android.view.Menu
import android.view.MenuItem
import android.view.View
import androidx.annotation.DrawableRes
import androidx.annotation.StringRes
import com.newsblur.R
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.SocialFeed
import com.newsblur.fragment.AddFeedFragment
import com.newsblur.fragment.ChooseFoldersFragment
import com.newsblur.fragment.DeleteFeedFragment
import com.newsblur.fragment.DeleteFolderDialogFragment
import com.newsblur.fragment.FeedIntelTrainerFragment
import com.newsblur.fragment.InfrequentCutoffDialogFragment
import com.newsblur.fragment.RenameDialogFragment
import com.newsblur.network.FolderPath
import com.newsblur.service.TryFeedRefreshStatus
import com.newsblur.util.CustomIconRenderer
import com.newsblur.util.FeedExt.isAndroidNotifyFocus
import com.newsblur.util.FeedExt.isAndroidNotifyUnread
import com.newsblur.util.FeedSet
import com.newsblur.util.Session
import com.newsblur.util.UIUtils
import com.newsblur.util.discoverThemePalette

/**
 * The part of a story list that depends on what it shows: its toolbar, the menu items only that
 * kind of list offers, and the feed id a saved search on it is filed under.
 *
 * ItemsList.java picks a kind from its launch intent. A phone keeps that kind for the life of the
 * list. On a tablet the one story list in the split changes kind in place when a feed or folder is
 * picked from the feed list slide-over (ItemsList.switchStoryList), so the pane never reloads.
 */
sealed class StoryListKind {
    abstract fun setupToolbar(list: ItemsList)

    /** The feed id a saved search on this list is filed under, or null for lists that can't save one. */
    abstract fun saveSearchFeedId(): String?

    /** Adjusts the shared story list menu for this kind. Returns true when it did. */
    open fun prepareMenu(
        list: ItemsList,
        menu: Menu,
    ): Boolean = false

    open fun onOptionsItemSelected(
        list: ItemsList,
        item: MenuItem,
    ): Boolean = false

    /** The list advanced in place to the next feed or folder (ItemsList.applyNextSession). */
    open fun onNextSession(
        list: ItemsList,
        session: Session,
    ) {}

    /** Feed titles, icons or settings changed (NbSyncManager.UPDATE_METADATA). */
    open fun onMetadataUpdated(list: ItemsList) {}

    /** All Site Stories, Read Stories, the shared and trending lists: a fixed icon and title. */
    class Titled(
        @DrawableRes private val icon: Int,
        @StringRes private val title: Int,
        private val saveSearchId: String?,
    ) : StoryListKind() {
        override fun setupToolbar(list: ItemsList) {
            UIUtils.setupToolbar(list, icon, list.getString(title), false)
        }

        override fun saveSearchFeedId(): String? = saveSearchId
    }

    class Saved(
        private val savedTag: String?,
    ) : StoryListKind() {
        override fun setupToolbar(list: ItemsList) {
            var title = list.getString(R.string.saved_stories_title)
            if (savedTag != null) title = "$title - $savedTag"
            UIUtils.setupToolbar(list, R.drawable.ic_saved, title, false)
        }

        override fun saveSearchFeedId(): String = if (savedTag != null) "starred:$savedTag" else "starred"
    }

    object Infrequent : StoryListKind() {
        override fun setupToolbar(list: ItemsList) {
            UIUtils.setupToolbar(list, R.drawable.ak_icon_infrequent, list.getString(R.string.infrequent_title), false)
        }

        override fun saveSearchFeedId(): String = "river:infrequent"

        override fun onOptionsItemSelected(
            list: ItemsList,
            item: MenuItem,
        ): Boolean {
            if (item.itemId != R.id.menu_infrequent_cutoff) return false
            // ItemsList.java takes the dialog's answer (InfrequentCutoffChangedListener).
            InfrequentCutoffDialogFragment
                .newInstance(list.prefsRepo.getInfrequentCutoff())
                .show(list.supportFragmentManager, InfrequentCutoffDialogFragment::class.java.name)
            return true
        }
    }

    class Social(
        private val socialFeed: SocialFeed,
    ) : StoryListKind() {
        override fun setupToolbar(list: ItemsList) {
            UIUtils.setupToolbar(list, socialFeed.photoUrl, socialFeed.feedTitle, list.relatedIconLoader, false)
        }

        override fun saveSearchFeedId(): String = "social:${socialFeed.userId}"
    }

    class Folder(
        private var folderName: String?,
    ) : StoryListKind() {
        override fun setupToolbar(list: ItemsList) {
            val customIcon = BlurDatabaseHelper.getFolderIcon(folderName)
            if (customIcon != null) {
                val iconBitmap = CustomIconRenderer.renderIcon(list, customIcon, UIUtils.dp2px(list, 24))
                if (iconBitmap != null) {
                    UIUtils.setupToolbar(list, iconBitmap, FolderPath.leaf(folderName), false)
                    return
                }
            }
            UIUtils.setupToolbar(list, R.drawable.ic_folder_closed, FolderPath.leaf(folderName), false)
        }

        override fun saveSearchFeedId(): String = "river:" + FolderPath.serverName(folderName)

        override fun onNextSession(
            list: ItemsList,
            session: Session,
        ) {
            folderName = session.folderName
            setupToolbar(list)
        }

        override fun prepareMenu(
            list: ItemsList,
            menu: Menu,
        ): Boolean {
            val muteItem = menu.findItem(R.id.menu_mute_folder) ?: return true
            val unmuteItem = menu.findItem(R.id.menu_unmute_folder) ?: return true
            val feedIds = list.fs.allFeeds
            if (feedIds.isNullOrEmpty()) {
                muteItem.isVisible = false
                unmuteItem.isVisible = false
                return true
            }
            val hasActiveFeed = feedIds.any { feedId -> list.dbHelper.getFeed(feedId)?.active == true }
            muteItem.isVisible = hasActiveFeed
            unmuteItem.isVisible = !hasActiveFeed
            return true
        }

        override fun onOptionsItemSelected(
            list: ItemsList,
            item: MenuItem,
        ): Boolean {
            when (item.itemId) {
                R.id.menu_rename_folder -> {
                    val name = folderName ?: return true
                    RenameDialogFragment
                        .newFolderInstance(name, folderParentName(list, name))
                        .show(list.supportFragmentManager, RenameDialogFragment::class.java.name)
                }

                R.id.menu_mute_folder -> {
                    val feedIds = list.fs.allFeeds
                    if (!feedIds.isNullOrEmpty()) list.feedUtils.muteFeeds(list, feedIds)
                }

                R.id.menu_unmute_folder -> {
                    val feedIds = list.fs.allFeeds
                    if (!feedIds.isNullOrEmpty()) list.feedUtils.unmuteFeeds(list, feedIds)
                }

                R.id.menu_delete_folder -> {
                    val name = folderName ?: return true
                    DeleteFolderDialogFragment
                        .newInstance(name, folderParentName(list, name))
                        .show(list.supportFragmentManager, DeleteFolderDialogFragment::class.java.name)
                }

                else -> {
                    return false
                }
            }
            return true
        }

        private fun folderParentName(
            list: ItemsList,
            name: String,
        ): String? = list.dbHelper.getFolder(name)?.firstParentName
    }

    class Feed(
        private var feed: com.newsblur.domain.Feed?,
        private var folderName: String?,
        val isTryFeed: Boolean,
        private val tryFeedUrl: String?,
    ) : StoryListKind() {
        override fun setupToolbar(list: ItemsList) {
            val feed = feed
            if (feed == null || folderName == null) {
                list.replaceWithFeedList()
                return
            }
            showFeed(list, feed)
            updateTryFeedBanner(list)
        }

        override fun saveSearchFeedId(): String = feed?.let { "feed:${it.feedId}" } ?: ""

        override fun onNextSession(
            list: ItemsList,
            session: Session,
        ) {
            feed = session.feed
            folderName = session.folderName
            setupToolbar(list)
        }

        override fun onMetadataUpdated(list: ItemsList) {
            val current = feed ?: return
            if (folderName == null) return
            list.dbHelper.getFeed(current.feedId)?.let { updatedFeed ->
                feed = updatedFeed
                showFeed(list, updatedFeed)
            }
            updateTryFeedBanner(list)
        }

        private fun showFeed(
            list: ItemsList,
            feed: com.newsblur.domain.Feed,
        ) {
            val customIcon = BlurDatabaseHelper.getFeedIcon(feed.feedId)
            if (customIcon != null) {
                val iconBitmap = CustomIconRenderer.renderIcon(list, customIcon, UIUtils.dp2px(list, 24))
                if (iconBitmap != null) {
                    UIUtils.setupToolbar(list, iconBitmap, feed.title, false)
                    return
                }
            }
            UIUtils.setupToolbar(list, feed.faviconUrl, feed.title, list.relatedIconLoader, false)
        }

        fun showDeleteFeedDialog(list: ItemsList) {
            val feed = feed ?: return
            DeleteFeedFragment.newInstance(feed, folderName).show(list.supportFragmentManager, "dialog")
        }

        override fun prepareMenu(
            list: ItemsList,
            menu: Menu,
        ): Boolean {
            val feed = feed ?: return true
            menu.findItem(R.id.menu_mute_feed).isVisible = !isTryFeed && !list.fs.isFilterSaved && feed.active
            menu.findItem(R.id.menu_unmute_feed).isVisible = !isTryFeed && !list.fs.isFilterSaved && !feed.active
            menu.findItem(R.id.menu_choose_folders).isVisible = !isTryFeed && !list.fs.isFilterSaved
            val notifyUnread = feed.isAndroidNotifyUnread()
            val notifyFocus = !notifyUnread && feed.isAndroidNotifyFocus()
            menu.findItem(R.id.menu_notifications_disable).isChecked = !notifyUnread && !notifyFocus
            menu.findItem(R.id.menu_notifications_unread).isChecked = notifyUnread
            menu.findItem(R.id.menu_notifications_focus).isChecked = notifyFocus
            return true
        }

        override fun onOptionsItemSelected(
            list: ItemsList,
            item: MenuItem,
        ): Boolean {
            val feed = feed ?: return false
            when (item.itemId) {
                R.id.menu_choose_folders -> {
                    ChooseFoldersFragment.newInstance(feed).show(list.supportFragmentManager, "choose-folders")
                }

                R.id.menu_mute_feed -> {
                    list.feedUtils.muteFeeds(list, setOf(feed.feedId))
                }

                R.id.menu_unmute_feed -> {
                    list.feedUtils.unmuteFeeds(list, setOf(feed.feedId))
                }

                R.id.menu_delete_feed -> {
                    showDeleteFeedDialog(list)
                }

                R.id.menu_notifications_disable -> {
                    list.feedUtils.disableNotifications(list, feed)
                }

                R.id.menu_notifications_focus -> {
                    list.feedUtils.enableFocusNotifications(list, feed)
                }

                R.id.menu_notifications_unread -> {
                    list.feedUtils.enableUnreadNotifications(list, feed)
                }

                R.id.menu_instafetch_feed -> {
                    val tryFeedStatus = list.syncServiceState.getTryFeedRefreshStatus(list.fs)
                    if (isTryFeed && tryFeedStatus != TryFeedRefreshStatus.NONE) {
                        if (tryFeedStatus != TryFeedRefreshStatus.FETCHING) list.restartReadingSession()
                    } else {
                        list.feedUtils.instaFetchFeed(list, feed.feedId)
                        // Back to the feed list, where the refresh shows.
                        list.backToFeedList()
                    }
                }

                R.id.menu_intel -> {
                    FeedIntelTrainerFragment
                        .newInstance(feed, list.fs)
                        .show(list.supportFragmentManager, FeedIntelTrainerFragment::class.java.name)
                }

                R.id.menu_rename_feed -> {
                    RenameDialogFragment
                        .newFeedInstance(feed.feedId, feed.title)
                        .show(list.supportFragmentManager, RenameDialogFragment::class.java.name)
                }

                R.id.menu_statistics -> {
                    list.feedUtils.openStatistics(list, list.prefsRepo, feed.feedId)
                }

                else -> {
                    return false
                }
            }
            return true
        }

        private fun updateTryFeedBanner(list: ItemsList) {
            val binding = list.binding
            val feed = feed
            if (!isTryFeed || feed == null) {
                binding.itemlistTryFeedBanner.visibility = View.GONE
                return
            }
            val palette = discoverThemePalette(list, list.prefsRepo)
            binding.itemlistTryFeedBanner.visibility = View.VISIBLE
            val background = GradientDrawable()
            background.shape = GradientDrawable.RECTANGLE
            background.cornerRadius = 0f
            background.setColor(palette.tryFeedBannerBackgroundColor)
            background.setStroke(UIUtils.dp2px(list, 1), palette.tryFeedBannerBorderColor)
            binding.itemlistTryFeedBanner.background = background
            binding.itemlistTryFeedTitle.text = feed.title
            binding.itemlistTryFeedSubtitle.setText(R.string.try_feed_banner_subtitle)
            binding.itemlistTryFeedTitle.setTextColor(palette.tryFeedBannerTitleColor)
            binding.itemlistTryFeedSubtitle.setTextColor(palette.tryFeedBannerSubtitleColor)
            binding.itemlistTryFeedSubscribeButton.backgroundTintList = ColorStateList.valueOf(palette.tryFeedButtonBackgroundColor)
            binding.itemlistTryFeedSubscribeButton.setTextColor(palette.tryFeedButtonTextColor)
            binding.itemlistTryFeedSubscribeButton.setOnClickListener {
                val feedUrl = tryFeedUrl?.takeIf { it.isNotBlank() } ?: feed.address.takeIf { it.isNotBlank() } ?: feed.feedLink
                if (!feedUrl.isNullOrBlank()) {
                    AddFeedFragment
                        .newInstance(feedUrl, feed.title, clearTryFeedOnSuccess = true)
                        .show(list.supportFragmentManager, AddFeedFragment::class.java.name)
                }
            }
            list.relatedIconLoader.displayImage(feed.faviconUrl, binding.itemlistTryFeedIcon)
        }
    }

    companion object {
        /** The kind a story list intent opens, by the ItemsList.java subclass it names. */
        @JvmStatic
        fun fromIntent(
            intent: Intent,
            feedSet: FeedSet,
        ): StoryListKind =
            when (intent.component?.className) {
                FeedItemsList::class.java.name -> {
                    Feed(
                        feed = intent.getSerializableExtra(FeedItemsList.EXTRA_FEED) as com.newsblur.domain.Feed?,
                        folderName = intent.getStringExtra(FeedItemsList.EXTRA_FOLDER_NAME),
                        isTryFeed = intent.getBooleanExtra(FeedItemsList.EXTRA_IS_TRY_FEED, false),
                        tryFeedUrl = intent.getStringExtra(FeedItemsList.EXTRA_TRY_FEED_URL),
                    )
                }

                FolderItemsList::class.java.name -> {
                    Folder(intent.getStringExtra(FolderItemsList.EXTRA_FOLDER_NAME))
                }

                SocialFeedItemsList::class.java.name -> {
                    Social(intent.getSerializableExtra(SocialFeedItemsList.EXTRA_SOCIAL_FEED) as SocialFeed)
                }

                SavedStoriesItemsList::class.java.name -> {
                    Saved(feedSet.singleSavedTag)
                }

                InfrequentItemsList::class.java.name -> {
                    Infrequent
                }

                ReadStoriesItemsList::class.java.name -> {
                    Titled(R.drawable.ic_indicator_unread, R.string.read_stories_title, "read")
                }

                // Neither shared list has a save search option.
                GlobalSharedStoriesItemsList::class.java.name -> {
                    Titled(R.drawable.ic_global_shares, R.string.global_shared_stories_title, null)
                }

                AllSharedStoriesItemsList::class.java.name -> {
                    Titled(R.drawable.ic_all_shares, R.string.all_shared_stories_title, null)
                }

                WidelyReadStoriesItemsList::class.java.name -> {
                    Titled(R.drawable.ic_trending_well_read, R.string.widely_read_stories_title, "trending:well_read")
                }

                LongReadsItemsList::class.java.name -> {
                    Titled(R.drawable.ic_trending_long_reads, R.string.long_reads_title, "trending:long_reads")
                }

                GoodReadsItemsList::class.java.name -> {
                    Titled(R.drawable.ic_good_reads, R.string.good_reads_title, "trending:good_reads")
                }

                else -> {
                    Titled(R.drawable.ic_all_stories, R.string.all_stories_title, "river:")
                }
            }
    }
}
