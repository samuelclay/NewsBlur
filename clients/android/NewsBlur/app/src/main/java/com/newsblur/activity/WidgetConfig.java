package com.newsblur.activity;

import android.database.Cursor;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;

import com.newsblur.R;
import com.newsblur.databinding.ActivityWidgetConfigBinding;
import com.newsblur.di.IconLoader;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.widget.WidgetUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class WidgetConfig extends FeedChooser {

    @Inject
    FeedUtils feedUtils;

    @Inject
    @IconLoader
    ImageLoader iconLoader;

    private ActivityWidgetConfigBinding binding;

    @Override
    protected void onPause() {
        super.onPause();
        // notify widget to update next time it's viewed
        WidgetUtils.updateWidget(this);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.menu_feed_chooser, menu);
        return true;
    }

    @Override
    public boolean onPrepareOptionsMenu(Menu menu) {
        super.onPrepareOptionsMenu(menu);
        menu.findItem(R.id.menu_mute_all).setVisible(false);
        menu.findItem(R.id.menu_mute_none).setVisible(false);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.menu_select_all:
                selectAllFeeds();
                return true;
            case R.id.menu_select_none:
                replaceWidgetFeedIds(Collections.emptySet());
                return true;
            default:
                return super.onOptionsItemSelected(item);
        }
    }

    @Override
    void bindLayout() {
        binding = ActivityWidgetConfigBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.widget), true);
    }

    @Override
    void setupList() {
        adapter = new WidgetConfigAdapter(this, feedUtils, iconLoader);
        binding.listView.setAdapter(adapter);
    }

    @Override
    void processFeeds(Cursor cursor) {
        ArrayList<Feed> feeds = new ArrayList<>();
        while (cursor != null && cursor.moveToNext()) {
            Feed feed = Feed.fromCursor(cursor);
            if (feed.active) {
                feeds.add(feed);
                feedMap.put(feed.feedId, feed);
            }
        }
        this.feeds = feeds;
        processData();
    }

    @Override
    public void setAdapterData() {
        Set<String> feedIds = PrefsUtils.getWidgetFeedIds(this);
        // by default select all feeds
        if (feedIds == null) {
            feedIds = new HashSet<>(this.feeds.size());
            for (Feed feed : this.feeds) {
                feedIds.add(feed.feedId);
            }
        }
        adapter.setFeedIds(feedIds);

        super.setAdapterData();
        binding.listView.setVisibility(this.feeds.isEmpty() ? View.GONE : View.VISIBLE);
        binding.textNoSubscriptions.setVisibility(this.feeds.isEmpty() ? View.VISIBLE : View.GONE);
    }

    @Override
    void processData() {
        if (folders != null && feeds != null) {
            for (Folder folder : folders) {
                ArrayList<Feed> activeFeeds = new ArrayList<>();
                for (String feedId : folder.feedIds) {
                    Feed feed = feedMap.get(feedId);
                    if (feed != null && feed.active && !activeFeeds.contains(feed)) {
                        activeFeeds.add(feed);
                    }
                }
                folderNames.add(folder.flatName());
                folderChildren.add(activeFeeds);
            }

            setAdapterData();
        }
    }

    private void selectAllFeeds() {
        Set<String> feedIds = new HashSet<>(this.feeds.size());
        for (Feed feed : this.feeds) {
            feedIds.add(feed.feedId);
        }
        replaceWidgetFeedIds(feedIds);
    }

    private void replaceWidgetFeedIds(Set<String> feedIds) {
        PrefsUtils.setWidgetFeedIds(this, feedIds);
        adapter.replaceFeedIds(feedIds);
    }
}