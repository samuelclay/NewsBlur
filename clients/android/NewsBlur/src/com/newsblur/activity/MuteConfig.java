package com.newsblur.activity;

import android.app.AlertDialog;
import android.database.Cursor;
import android.text.TextUtils;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;

import com.newsblur.R;
import com.newsblur.databinding.ActivityMuteConfigBinding;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

public class MuteConfig extends FeedChooser {

    private ActivityMuteConfigBinding binding;

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
    }

    @Override
    void setupList() {
        adapter = new MuteConfigAdapter(this);
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
        int activeSites = 0;
        if (folders != null && feeds != null) {
            for (Folder folder : folders) {
                ArrayList<Feed> children = new ArrayList<>();
                for (String feedId : folder.feedIds) {
                    Feed feed = feedMap.get(feedId);
                    if (!children.contains(feed)) {
                        children.add(feed);
                    }
                    if (feed != null && feed.active) {
                        activeSites++;
                    }
                }
                folderNames.add(folder.flatName());
                folderChildren.add(children);
            }

            setAdapterData();

            // free standard accounts can follow up to 64 sites
            boolean isPremium = PrefsUtils.getIsPremium(this);
            if (!isPremium && activeSites > AppConstants.FREE_ACCOUNT_SITE_LIMIT) {
                showAccountFeedsLimitDialog(activeSites - AppConstants.FREE_ACCOUNT_SITE_LIMIT);
            }
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

    private void setFeedsState(boolean isMute) {
        for (Feed feed : feeds) {
            feed.active = !isMute;
        }
        adapter.notifyDataSetChanged();

        if (isMute) FeedUtils.muteFeeds(this, adapter.feedIds);
        else FeedUtils.unmuteFeeds(this, adapter.feedIds);
    }

    private void showAccountFeedsLimitDialog(int exceededLimitCount) {
        new AlertDialog.Builder(this)
                .setTitle(R.string.mute_config_title)
                .setMessage(String.format(getString(R.string.mute_config_message), exceededLimitCount))
                .setPositiveButton(android.R.string.ok, null)
                .setNeutralButton(R.string.mute_config_reset_button, (dialogInterface, i) -> resetToPopularFeeds())
                .show();
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
        FeedUtils.unmuteFeeds(this, activeFeedIds);
        FeedUtils.muteFeeds(this, inactiveFeedIds);
        finish();
    }
}
