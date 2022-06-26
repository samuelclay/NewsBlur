package com.newsblur.activity;

import static com.newsblur.service.NBSyncReceiver.UPDATE_STATUS;

import android.content.Intent;
import android.database.Cursor;
import android.text.TextUtils;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import androidx.appcompat.app.AlertDialog;
import androidx.core.content.ContextCompat;

import com.newsblur.R;
import com.newsblur.databinding.ActivityMuteConfigBinding;
import com.newsblur.di.IconLoader;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class MuteConfig extends FeedChooser implements MuteConfigAdapter.FeedStateChangedListener {

    @Inject
    FeedUtils feedUtils;

    @Inject
    @IconLoader
    ImageLoader iconLoader;

    private ActivityMuteConfigBinding binding;
    private boolean checkedInitFeedsLimit = false;

    @Override
    public boolean onPrepareOptionsMenu(Menu menu) {
        super.onPrepareOptionsMenu(menu);
        menu.findItem(R.id.menu_select_all).setVisible(false);
        menu.findItem(R.id.menu_select_none).setVisible(false);
        menu.findItem(R.id.menu_widget_background).setVisible(false);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.menu_mute_all:
                setFeedsState(true);
                return true;
            case R.id.menu_mute_none:
                setFeedsState(false);
                return true;
            default:
                return super.onOptionsItemSelected(item);
        }
    }

    @Override
    void bindLayout() {
        binding = ActivityMuteConfigBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.mute_sites), true);
    }

    @Override
    void setupList() {
        adapter = new MuteConfigAdapter(this, feedUtils, iconLoader, this);
        binding.listView.setAdapter(adapter);
    }

    @Override
    void processFeeds(Cursor cursor) {
        ArrayList<Feed> feeds = new ArrayList<>();
        while (cursor != null && cursor.moveToNext()) {
            Feed feed = Feed.fromCursor(cursor);
            feeds.add(feed);
            feedMap.put(feed.feedId, feed);
        }
        this.feeds = feeds;
        processData();
    }

    @Override
    void processData() {
        if (folders != null && feeds != null) {
            for (Folder folder : folders) {
                ArrayList<Feed> children = new ArrayList<>();
                for (String feedId : folder.feedIds) {
                    Feed feed = feedMap.get(feedId);
                    if (!children.contains(feed)) {
                        children.add(feed);
                    }
                }
                folderNames.add(folder.flatName());
                folderChildren.add(children);
            }

            setAdapterData();
            syncActiveFeedCount();
            checkedInitFeedsLimit = true;
        }
    }

    @Override
    public void setAdapterData() {
        Set<String> feedIds = new HashSet<>(this.feeds.size());
        for (Feed feed : this.feeds) {
            feedIds.add(feed.feedId);
        }
        adapter.setFeedIds(feedIds);

        super.setAdapterData();
    }

    @Override
    protected void handleUpdate(int updateType) {
        super.handleUpdate(updateType);
        if ((updateType & UPDATE_STATUS) != 0) {
            String syncStatus = NBSyncService.getSyncStatusMessage(this, false);
            if (syncStatus != null) {
                binding.textSyncStatus.setText(syncStatus);
                binding.textSyncStatus.setVisibility(View.VISIBLE);
            } else {
                binding.textSyncStatus.setVisibility(View.GONE);
            }
        }
    }

    @Override
    public void onFeedStateChanged() {
        syncActiveFeedCount();
    }

    private void syncActiveFeedCount() {
        // free standard accounts can follow up to 64 sites
        boolean isPremium = PrefsUtils.getIsPremium(this);
        if (!isPremium && feeds != null) {
            int activeSites = 0;
            for (Feed feed : feeds) {
                if (feed.active) {
                    activeSites++;
                }
            }
            int textColorRes = activeSites > AppConstants.FREE_ACCOUNT_SITE_LIMIT ? R.color.negative : R.color.positive;
            binding.textSites.setTextColor(ContextCompat.getColor(this, textColorRes));
            binding.textSites.setText(String.format(getString(R.string.mute_config_sites), activeSites, AppConstants.FREE_ACCOUNT_SITE_LIMIT));
            showSitesCount();

            if (activeSites > AppConstants.FREE_ACCOUNT_SITE_LIMIT && !checkedInitFeedsLimit) {
                showAccountFeedsLimitDialog(activeSites - AppConstants.FREE_ACCOUNT_SITE_LIMIT);
            }
        } else {
            hideSitesCount();
        }
    }

    private void setFeedsState(boolean isMute) {
        for (Feed feed : feeds) {
            feed.active = !isMute;
        }
        adapter.notifyDataSetChanged();

        if (isMute) feedUtils.muteFeeds(this, adapter.feedIds);
        else feedUtils.unmuteFeeds(this, adapter.feedIds);
    }

    private void showAccountFeedsLimitDialog(int exceededLimitCount) {
        new AlertDialog.Builder(this)
                .setTitle(R.string.mute_config_title)
                .setMessage(String.format(getString(R.string.mute_config_message), exceededLimitCount))
                .setNeutralButton(android.R.string.ok, null)
                .setPositiveButton(R.string.mute_config_upgrade, (dialogInterface, i) -> openUpgradeToPremium())
                .show();
    }

    private void showSitesCount() {
        ViewGroup.LayoutParams oldLayout = binding.listView.getLayoutParams();
        FrameLayout.LayoutParams newLayout = new FrameLayout.LayoutParams(oldLayout);
        newLayout.topMargin = UIUtils.dp2px(this, 85);
        binding.listView.setLayoutParams(newLayout);
        binding.containerSitesCount.setVisibility(View.VISIBLE);
        binding.textResetSites.setOnClickListener(view -> resetToPopularFeeds());
        binding.textUpgrade.setOnClickListener(view -> openUpgradeToPremium());
    }

    private void hideSitesCount() {
        ViewGroup.LayoutParams oldLayout = binding.listView.getLayoutParams();
        FrameLayout.LayoutParams newLayout = new FrameLayout.LayoutParams(oldLayout);
        newLayout.topMargin = UIUtils.dp2px(this, 0);
        binding.listView.setLayoutParams(newLayout);
        binding.containerSitesCount.setVisibility(View.GONE);
        binding.textResetSites.setOnClickListener(null);
    }

    // reset to most popular sites based on subscribers
    private void resetToPopularFeeds() {
        // sort descending by subscribers
        Collections.sort(feeds, (f1, f2) -> {
            if (TextUtils.isEmpty(f1.subscribers)) f1.subscribers = "0";
            if (TextUtils.isEmpty(f2.subscribers)) f2.subscribers = "0";
            return Integer.valueOf(f2.subscribers).compareTo(Integer.valueOf(f1.subscribers));
        });
        Set<String> activeFeedIds = new HashSet<>();
        Set<String> inactiveFeedIds = new HashSet<>();
        for (int index = 0; index < feeds.size(); index++) {
            Feed feed = feeds.get(index);
            if (index < AppConstants.FREE_ACCOUNT_SITE_LIMIT) {
                activeFeedIds.add(feed.feedId);
            } else {
                inactiveFeedIds.add(feed.feedId);
            }
        }
        feedUtils.unmuteFeeds(this, activeFeedIds);
        feedUtils.muteFeeds(this, inactiveFeedIds);
        finish();
    }

    private void openUpgradeToPremium() {
        Intent intent = new Intent(this, Premium.class);
        startActivity(intent);
        finish();
    }
}
