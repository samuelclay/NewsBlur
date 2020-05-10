package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.content.Loader;
import android.support.v7.widget.RecyclerView;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.widget.WidgetUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

import butterknife.Bind;
import butterknife.ButterKnife;

public class WidgetConfig extends NbActivity {

    @Bind(R.id.recycler_view)
    RecyclerView recyclerView;

    private WidgetConfigAdapter adapter;
    private ArrayList<Feed> feedList = new ArrayList<>();

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_widget_config);
        ButterKnife.bind(this);
        getActionBar().setDisplayHomeAsUpEnabled(true);

        adapter = new WidgetConfigAdapter();
        recyclerView.setAdapter(adapter);

        loadFeedsList();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.menu_widget, menu);
        return true;
    }

    @Override
    public boolean onPrepareOptionsMenu(Menu menu) {
        int sortById = PrefsUtils.getSortByForWidgetConfig(this);
        int sortOrderId = PrefsUtils.getSortOrderForWidgetConfig(this);
        menu.findItem(sortById).setChecked(true);
        menu.findItem(sortOrderId).setChecked(true);
        return super.onPrepareOptionsMenu(menu);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case android.R.id.home:
                finish();
                return true;
            case R.id.menu_select_all:
                selectAllFeeds();
                return true;
            case R.id.menu_select_none:
                setWidgetFeedIds(Collections.<String>emptySet());
                return true;
            default:
                return super.onOptionsItemSelected(item);
        }
    }

    private void loadFeedsList() {
        Loader<Cursor> loader = FeedUtils.dbHelper.getFeedsLoader();
        loader.registerListener(loader.getId(), new Loader.OnLoadCompleteListener<Cursor>() {
            @Override
            public void onLoadComplete(@NonNull Loader<Cursor> loader, @Nullable Cursor cursor) {
                showFeedList(cursor);
            }
        });
        loader.startLoading();
    }

    private void showFeedList(Cursor cursor) {
        ArrayList<Feed> feedList = new ArrayList<>();
        while (cursor != null && cursor.moveToNext()) {
            Feed feed = Feed.fromCursor(cursor);
            if (!feed.feedId.equals("0") && feed.active) {
                feedList.add(feed);
            }
        }
        this.feedList = feedList;

        Set<String> feedIds = PrefsUtils.getWidgetFeedIds(this);
        if (feedIds == null) {
            // default config. Show all feeds
            feedIds = new HashSet<>(this.feedList.size());
            for (Feed feed : this.feedList) {
                feedIds.add(feed.feedId);
            }
        }
        adapter.replaceAll(this.feedList, feedIds);
    }

    private void selectAllFeeds() {
        Set<String> feedIds = new HashSet<>(this.feedList.size());
        for (Feed feed : this.feedList) {
            feedIds.add(feed.feedId);
        }
        setWidgetFeedIds(feedIds);
    }

    private void setWidgetFeedIds(Set<String> feedIds) {
        PrefsUtils.setWidgetFeedIds(this, feedIds);
        adapter.replaceAll(this.feedList, PrefsUtils.getWidgetFeedIds(this));
        WidgetUtils.notifyViewDataChanged(this);
    }
}
