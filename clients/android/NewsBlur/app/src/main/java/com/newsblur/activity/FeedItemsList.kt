package com.newsblur.activity

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import androidx.activity.OnBackPressedCallback
import androidx.fragment.app.DialogFragment
import com.google.android.gms.tasks.Task
import com.google.android.play.core.review.ReviewInfo
import com.google.android.play.core.review.ReviewManager
import com.google.android.play.core.review.ReviewManagerFactory
import com.newsblur.R
import com.newsblur.di.IconLoader
import com.newsblur.domain.Feed
import com.newsblur.fragment.DeleteFeedFragment
import com.newsblur.fragment.FeedIntelTrainerFragment
import com.newsblur.fragment.RenameDialogFragment
import com.newsblur.util.FeedExt.isAndroidNotifyFocus
import com.newsblur.util.FeedExt.isAndroidNotifyUnread
import com.newsblur.util.FeedSet
import com.newsblur.util.ImageLoader
import com.newsblur.util.Session
import com.newsblur.util.SessionDataSource
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class FeedItemsList : ItemsList() {
    @Inject
    @IconLoader
    lateinit var iconLoader: ImageLoader

    private lateinit var feed: Feed
    private lateinit var folderName: String

    private var reviewManager: ReviewManager? = null
    private var reviewInfo: ReviewInfo? = null

    override fun onCreate(bundle: Bundle?) {
        super.onCreate(bundle)
        setupFeedItems(intent)

        viewModel.nextSession.observe(this) { session ->
            setupFeedItems(session)
        }

        checkInAppReview()

        val backCallback =
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    if (reviewInfo != null) {
                        val flow = reviewManager!!.launchReviewFlow(this@FeedItemsList, reviewInfo!!)
                        flow.addOnCompleteListener { task: Task<Void?>? ->
                            prefsRepo.setInAppReviewed()
                            finish()
                        }
                    } else {
                        isEnabled = false
                        onBackPressedDispatcher.onBackPressed()
                        isEnabled = true
                    }
                }
            }

        onBackPressedDispatcher.addCallback(this, backCallback)
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
                // NOTE: This activity uses a Feed passed via extras; name changes won’t reflect until finish().
                true
            }

            R.id.menu_statistics -> {
                feedUtils.openStatistics(this, prefsRepo, feed.feedId)
                true
            }

            else -> false
        }
    }

    override fun onPrepareOptionsMenu(menu: Menu): Boolean {
        super.onPrepareOptionsMenu(menu)
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

    override fun getSaveSearchFeedId(): String = "feed:${feed.feedId}"

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
        UIUtils.setupToolbar(this, feed.faviconUrl, feed.title, iconLoader, false)
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
    }
}
