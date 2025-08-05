package com.newsblur.activity

import android.content.DialogInterface
import android.content.Intent
import android.text.TextUtils
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.widget.FrameLayout
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import com.newsblur.R
import com.newsblur.activity.MuteConfigAdapter.FeedStateChangedListener
import com.newsblur.databinding.ActivityMuteConfigBinding
import com.newsblur.di.IconLoader
import com.newsblur.domain.Feed
import com.newsblur.service.NbSyncManager.UPDATE_STATUS
import com.newsblur.util.AppConstants
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.FeedUtils
import com.newsblur.util.ImageLoader
import com.newsblur.util.UIUtils
import com.newsblur.viewModel.FeedFolderData
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MuteConfig : FeedChooser(), FeedStateChangedListener {

    @Inject
    lateinit var feedUtils: FeedUtils

    @Inject
    @IconLoader
    lateinit var iconLoader: ImageLoader

    private lateinit var binding: ActivityMuteConfigBinding
    private var checkedInitFeedsLimit = false

    override fun onPrepareOptionsMenu(menu: Menu): Boolean {
        super.onPrepareOptionsMenu(menu)
        menu.findItem(R.id.menu_select_all).setVisible(false)
        menu.findItem(R.id.menu_select_none).setVisible(false)
        menu.findItem(R.id.menu_widget_background).setVisible(false)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        if (item.itemId == R.id.menu_mute_all) {
            setFeedsState(true)
            return true
        } else if (item.itemId == R.id.menu_mute_none) {
            setFeedsState(false)
            return true
        } else {
            return super.onOptionsItemSelected(item)
        }
    }

    override fun bindLayout() {
        binding = ActivityMuteConfigBinding.inflate(layoutInflater)
        this.applyView(binding)
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.mute_sites), true)
    }

    override fun setupList() {
        adapter = MuteConfigAdapter(feedUtils, iconLoader, prefsRepo, this)
        binding.listView.setAdapter(adapter)
    }

    override fun processData(data: FeedFolderData) {
        folders.clear()
        folders.addAll(data.folders)

        feeds.clear()
        feeds.addAll(data.feeds)

        val feedMap = feeds.associateBy { it.feedId }

        for (folder in folders) {
            val children = folder.feedIds.mapNotNull { feedMap[it] }.distinct()
            folderNames.add(folder.flatName())
            folderChildren.add(ArrayList(children))
        }

        setAdapterData()
        syncActiveFeedCount()
        checkedInitFeedsLimit = true
    }

    public override fun setAdapterData() {
        val feedIds = feeds.map { it.feedId }.toSet()
        adapter.setFeedIds(feedIds)

        super.setAdapterData()
    }

    override fun handleUpdate(updateType: Int) {
        super.handleUpdate(updateType)
        if ((updateType and UPDATE_STATUS) != 0) {
            val syncStatus = syncServiceState.getSyncStatusMessage(this, false)
            if (syncStatus != null) {
                binding.textSyncStatus.text = syncStatus
                binding.textSyncStatus.visibility = View.VISIBLE
            } else {
                binding.textSyncStatus.visibility = View.GONE
            }
        }
    }

    override fun onFeedStateChanged() {
        syncActiveFeedCount()
    }

    private fun syncActiveFeedCount() {
        // free standard accounts can follow up to 64 sites
        val hasSubscription = prefsRepo.hasSubscription()
        if (!hasSubscription && feeds.isNotEmpty()) {
            var activeSites = 0
            for (feed in feeds) {
                if (feed.active) {
                    activeSites++
                }
            }
            val textColorRes = if (activeSites > AppConstants.FREE_ACCOUNT_SITE_LIMIT) R.color.negative else R.color.positive
            binding.textSites.setTextColor(ContextCompat.getColor(this, textColorRes))
            binding.textSites.text = String.format(getString(R.string.mute_config_sites), activeSites, AppConstants.FREE_ACCOUNT_SITE_LIMIT)
            showSitesCount()

            if (activeSites > AppConstants.FREE_ACCOUNT_SITE_LIMIT && !checkedInitFeedsLimit) {
                showAccountFeedsLimitDialog(activeSites - AppConstants.FREE_ACCOUNT_SITE_LIMIT)
            }
        } else {
            hideSitesCount()
        }
    }

    private fun setFeedsState(isMute: Boolean) {
        for (feed in feeds) {
            feed.active = !isMute
        }
        adapter.notifyDataSetChanged()

        if (isMute) feedUtils.muteFeeds(this, adapter.feedIds)
        else feedUtils.unmuteFeeds(this, adapter.feedIds)
    }

    private fun showAccountFeedsLimitDialog(exceededLimitCount: Int) {
        AlertDialog.Builder(this)
                .setTitle(R.string.mute_config_title)
                .setMessage(String.format(getString(R.string.mute_config_message), exceededLimitCount))
                .setNeutralButton(android.R.string.ok, null)
                .setPositiveButton(R.string.mute_config_upgrade) { dialogInterface: DialogInterface?, i: Int -> openUpgradeToPremium() }
                .show()
    }

    private fun showSitesCount() {
        val oldLayout = binding.listView.layoutParams
        val newLayout = FrameLayout.LayoutParams(oldLayout)
        newLayout.topMargin = UIUtils.dp2px(this, 85)
        binding.listView.layoutParams = newLayout
        binding.containerSitesCount.visibility = View.VISIBLE
        binding.textResetSites.setOnClickListener { view: View? -> resetToPopularFeeds() }
        binding.textUpgrade.setOnClickListener { view: View? -> openUpgradeToPremium() }
    }

    private fun hideSitesCount() {
        val oldLayout = binding.listView.layoutParams
        val newLayout = FrameLayout.LayoutParams(oldLayout)
        newLayout.topMargin = UIUtils.dp2px(this, 0)
        binding.listView.layoutParams = newLayout
        binding.containerSitesCount.visibility = View.GONE
        binding.textResetSites.setOnClickListener(null)
    }

    // reset to most popular sites based on subscribers
    private fun resetToPopularFeeds() {
        // sort descending by subscribers
        feeds.sortWith { f1: Feed, f2: Feed ->
            if (TextUtils.isEmpty(f1.subscribers)) f1.subscribers = "0"
            if (TextUtils.isEmpty(f2.subscribers)) f2.subscribers = "0"
            f2.subscribers.toInt().compareTo(f1.subscribers.toInt())
        }
        val activeFeedIds: MutableSet<String> = HashSet()
        val inactiveFeedIds: MutableSet<String> = HashSet()
        for (index in feeds.indices) {
            val feed = feeds[index]
            if (index < AppConstants.FREE_ACCOUNT_SITE_LIMIT) {
                activeFeedIds.add(feed.feedId)
            } else {
                inactiveFeedIds.add(feed.feedId)
            }
        }
        feedUtils.unmuteFeeds(this, activeFeedIds)
        feedUtils.muteFeeds(this, inactiveFeedIds)
        finish()
    }

    private fun openUpgradeToPremium() {
        val intent = Intent(this, SubscriptionActivity::class.java)
        startActivity(intent)
        finish()
    }
}
