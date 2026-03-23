package com.newsblur.activity

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import androidx.fragment.app.DialogFragment
import com.google.android.gms.tasks.Task
import com.google.android.play.core.review.ReviewInfo
import com.google.android.play.core.review.ReviewManager
import com.google.android.play.core.review.ReviewManagerFactory
import com.newsblur.R
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.di.IconLoader
import com.newsblur.domain.Feed
import com.newsblur.fragment.AddFeedFragment
import com.newsblur.fragment.DeleteFeedFragment
import com.newsblur.fragment.FeedIntelTrainerFragment
import com.newsblur.fragment.RenameDialogFragment
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.util.CustomIconRenderer
import com.newsblur.util.FeedExt.isAndroidNotifyFocus
import com.newsblur.util.FeedExt.isAndroidNotifyUnread
import com.newsblur.util.FeedSet
import com.newsblur.util.ImageLoader
import com.newsblur.util.Session
import com.newsblur.util.SessionDataSource
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

internal enum class FeedItemsBackAction {
    FINISH_STORY_LIST,
    LAUNCH_REVIEW,
}

internal fun resolveFeedItemsBackAction(
    hasReviewInfo: Boolean,
    isGestureNavigation: Boolean,
): FeedItemsBackAction =
    if (hasReviewInfo && !isGestureNavigation) {
        FeedItemsBackAction.LAUNCH_REVIEW
    } else {
        FeedItemsBackAction.FINISH_STORY_LIST
    }

@AndroidEntryPoint
class FeedItemsList : ItemsList() {
    @Inject
    @IconLoader
    lateinit var iconLoader: ImageLoader

    private lateinit var feed: Feed
    private lateinit var folderName: String
    private var isTryFeed = false
    private var tryFeedUrl: String? = null

    private var reviewManager: ReviewManager? = null
    private var reviewInfo: ReviewInfo? = null

    override fun onCreate(bundle: Bundle?) {
        super.onCreate(bundle)
        setupFeedItems(intent)

        viewModel.nextSession.observe(this) { session ->
            setupFeedItems(session)
        }

        updateTryFeedBanner()
        checkInAppReview()
    }

    override fun interceptBackPress(isGestureNavigation: Boolean): Boolean =
        when (
            resolveFeedItemsBackAction(
                hasReviewInfo = reviewInfo != null,
                isGestureNavigation = isGestureNavigation,
            )
        ) {
            FeedItemsBackAction.LAUNCH_REVIEW -> {
                val flow = reviewManager!!.launchReviewFlow(this@FeedItemsList, reviewInfo!!)
                flow.addOnCompleteListener { _: Task<Void?>? ->
                    prefsRepo.setInAppReviewed()
                    finish()
                }
                true
            }

            FeedItemsBackAction.FINISH_STORY_LIST -> false
        }

    override fun shouldResetReadingSessionOnCreate(): Boolean =
        intent?.getBooleanExtra(EXTRA_IS_TRY_FEED, false) == true

    override fun handleUpdate(updateType: Int) {
        super.handleUpdate(updateType)
        if ((updateType and UPDATE_METADATA) != 0) {
            refreshFeedHeader()
        }
    }

    fun showDeleteFeedDialog() {
        val deleteFeedFragment: DialogFragment = DeleteFeedFragment.newInstance(feed, folderName)
        deleteFeedFragment.show(supportFragmentManager, "dialog")
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        if (super.onOptionsItemSelected(item)) {
            return true
        }

        return when (item.itemId) {
            R.id.menu_delete_feed -> {
                showDeleteFeedDialog()
                true
            }

            R.id.menu_notifications_disable -> {
                feedUtils.disableNotifications(this, feed)
                true
            }

            R.id.menu_notifications_focus -> {
                feedUtils.enableFocusNotifications(this, feed)
                true
            }

            R.id.menu_notifications_unread -> {
                feedUtils.enableUnreadNotifications(this, feed)
                true
            }

            R.id.menu_instafetch_feed -> {
                feedUtils.instaFetchFeed(this, feed.feedId)
                finish()
                true
            }

            R.id.menu_intel -> {
                val intelFrag = FeedIntelTrainerFragment.newInstance(feed, fs)
                intelFrag.show(supportFragmentManager, FeedIntelTrainerFragment::class.java.name)
                true
            }

            R.id.menu_rename_feed -> {
                val frag = RenameDialogFragment.newFeedInstance(feed.feedId, feed.title)
                frag.show(supportFragmentManager, RenameDialogFragment::class.java.name)
                true
            }

            R.id.menu_statistics -> {
                feedUtils.openStatistics(this, prefsRepo, feed.feedId)
                true
            }

            else -> false
        }
    }

    override fun prepareItemListMenuModel(menu: Menu): Boolean {
        super.prepareItemListMenuModel(menu)
        if (!::feed.isInitialized) return true

        when {
            feed.isAndroidNotifyUnread() -> {
                menu.findItem(R.id.menu_notifications_disable).isChecked = false
                menu.findItem(R.id.menu_notifications_unread).isChecked = true
                menu.findItem(R.id.menu_notifications_focus).isChecked = false
            }

            feed.isAndroidNotifyFocus() -> {
                menu.findItem(R.id.menu_notifications_disable).isChecked = false
                menu.findItem(R.id.menu_notifications_unread).isChecked = false
                menu.findItem(R.id.menu_notifications_focus).isChecked = true
            }

            else -> {
                menu.findItem(R.id.menu_notifications_disable).isChecked = true
                menu.findItem(R.id.menu_notifications_unread).isChecked = false
                menu.findItem(R.id.menu_notifications_focus).isChecked = false
            }
        }
        return true
    }

    override fun getSaveSearchFeedId(): String = if (::feed.isInitialized) "feed:${feed.feedId}" else ""

    private fun setupFeedItems(session: Session) {
        val feed = session.feed
        val folderName = session.folderName
        if (feed != null && folderName != null) {
            setupFeedItems(feed, folderName)
        } else {
            finish()
        }
    }

    private fun setupFeedItems(intent: Intent) {
        val feed = intent.getSerializableExtra(EXTRA_FEED) as Feed?
        val folderName = intent.getStringExtra(EXTRA_FOLDER_NAME)
        isTryFeed = intent.getBooleanExtra(EXTRA_IS_TRY_FEED, false)
        tryFeedUrl = intent.getStringExtra(EXTRA_TRY_FEED_URL)
        if (feed != null && folderName != null) {
            setupFeedItems(feed, folderName)
        } else {
            finish()
        }
    }

    private fun setupFeedItems(
        feed: Feed,
        folderName: String,
    ) {
        this.feed = feed
        this.folderName = folderName
        val customIcon = BlurDatabaseHelper.getFeedIcon(feed.feedId)
        if (customIcon != null) {
            val iconSize = UIUtils.dp2px(this, 24)
            val iconBitmap = CustomIconRenderer.renderIcon(this, customIcon, iconSize)
            if (iconBitmap != null) {
                UIUtils.setupToolbar(this, iconBitmap, feed.title, false)
                return
            }
        }
        UIUtils.setupToolbar(this, feed.faviconUrl, feed.title, iconLoader, false)
        updateTryFeedBanner()
    }

    private fun refreshFeedHeader() {
        if (!::feed.isInitialized || !::folderName.isInitialized) return
        dbHelper.getFeed(feed.feedId)?.let { updatedFeed ->
            setupFeedItems(updatedFeed, folderName)
        }
        updateTryFeedBanner()
    }

    private fun updateTryFeedBanner() {
        if (!isTryFeed || !::feed.isInitialized) {
            binding.itemlistTryFeedBanner.visibility = android.view.View.GONE
            return
        }

        val palette = com.newsblur.util.discoverThemePalette(this, prefsRepo)
        binding.itemlistTryFeedBanner.visibility = android.view.View.VISIBLE
        val background = android.graphics.drawable.GradientDrawable()
        background.shape = android.graphics.drawable.GradientDrawable.RECTANGLE
        background.cornerRadius = 0f
        background.setColor(palette.tryFeedBannerBackgroundColor)
        background.setStroke(UIUtils.dp2px(this, 1), palette.tryFeedBannerBorderColor)
        binding.itemlistTryFeedBanner.background = background
        binding.itemlistTryFeedTitle.text = feed.title
        binding.itemlistTryFeedSubtitle.setText(R.string.try_feed_banner_subtitle)
        binding.itemlistTryFeedTitle.setTextColor(palette.tryFeedBannerTitleColor)
        binding.itemlistTryFeedSubtitle.setTextColor(palette.tryFeedBannerSubtitleColor)
        binding.itemlistTryFeedSubscribeButton.backgroundTintList = android.content.res.ColorStateList.valueOf(palette.tryFeedButtonBackgroundColor)
        binding.itemlistTryFeedSubscribeButton.setTextColor(palette.tryFeedButtonTextColor)
        binding.itemlistTryFeedSubscribeButton.setOnClickListener {
            val feedUrl = tryFeedUrl?.takeIf { it.isNotBlank() } ?: feed.address.takeIf { it.isNotBlank() } ?: feed.feedLink
            if (!feedUrl.isNullOrBlank()) {
                AddFeedFragment
                    .newInstance(feedUrl, feed.title, clearTryFeedOnSuccess = true)
                    .show(supportFragmentManager, AddFeedFragment::class.java.name)
            }
        }
        iconLoader.displayImage(feed.faviconUrl, binding.itemlistTryFeedIcon)
    }

    private fun checkInAppReview() {
        if (!prefsRepo.hasInAppReviewed()) {
            reviewManager = ReviewManagerFactory.create(this)
            reviewManager
                ?.requestReviewFlow()
                ?.addOnCompleteListener { task ->
                    if (task.isSuccessful) {
                        reviewInfo = task.getResult()
                    }
                }
        }
    }

    companion object {
        const val EXTRA_FEED: String = "feed"
        const val EXTRA_FOLDER_NAME: String = "folderName"
        const val EXTRA_IS_TRY_FEED: String = "is_try_feed"
        const val EXTRA_TRY_FEED_URL: String = "try_feed_url"

        @JvmStatic
        fun startActivity(
            context: Context,
            feedSet: FeedSet,
            feed: Feed?,
            folderName: String?,
            sessionDataSource: SessionDataSource?,
        ) {
            Intent(context, FeedItemsList::class.java)
                .apply {
                    putExtra(EXTRA_FEED, feed)
                    putExtra(EXTRA_FOLDER_NAME, folderName)
                    putExtra(EXTRA_FEED_SET, feedSet)
                    putExtra(EXTRA_SESSION_DATA, sessionDataSource)
                }.also { intent ->
                    context.startActivity(intent)
                }
        }

        @JvmStatic
        fun startTryFeedActivity(
            context: Context,
            feed: Feed,
        ) {
            Intent(context, FeedItemsList::class.java)
                .apply {
                    putExtra(EXTRA_FEED, feed)
                    putExtra(EXTRA_FOLDER_NAME, com.newsblur.util.AppConstants.ROOT_FOLDER)
                    putExtra(EXTRA_FEED_SET, FeedSet.singleFeed(feed.feedId))
                    putExtra(EXTRA_IS_TRY_FEED, true)
                    putExtra(EXTRA_TRY_FEED_URL, feed.address)
                }.also { intent ->
                    context.startActivity(intent)
                }
        }
    }
}
