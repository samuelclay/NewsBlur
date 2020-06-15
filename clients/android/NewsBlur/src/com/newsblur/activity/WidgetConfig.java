package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.content.Loader;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.widget.ExpandableListView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.util.FeedOrderFilter;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.FolderViewFilter;
import com.newsblur.util.ListOrderFilter;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.WidgetBackground;
import com.newsblur.widget.WidgetUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import butterknife.Bind;
import butterknife.ButterKnife;

public class WidgetConfig extends NbActivity {

    @Bind(R.id.list_view)
    ExpandableListView listView;
    @Bind(R.id.text_no_subscriptions)
    TextView textNoSubscriptions;

    private WidgetConfigAdapter adapter;
    private ArrayList<Feed> feeds;
    private ArrayList<Folder> folders;
    private Map<String, Feed> feedMap = new HashMap<>();
    private ArrayList<String> folderNames = new ArrayList<>();
    private ArrayList<ArrayList<Feed>> folderChildren = new ArrayList<>();

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_widget_config);
        ButterKnife.bind(this);
        getActionBar().setDisplayHomeAsUpEnabled(true);
        setupList();
        loadFeeds();
        loadFolders();
    }

    @Override
    protected void onPause() {
        super.onPause();
        // notify widget to refresh next time it's viewed
        WidgetUtils.notifyViewDataChanged(this);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.menu_widget, menu);
        return true;
    }

    @Override
    public boolean onPrepareOptionsMenu(Menu menu) {
        super.onPrepareOptionsMenu(menu);
        ListOrderFilter listOrderFilter = PrefsUtils.getWidgetConfigListOrder(this);
        if (listOrderFilter == ListOrderFilter.ASCENDING) {
            menu.findItem(R.id.menu_sort_order_ascending).setChecked(true);
        } else if (listOrderFilter == ListOrderFilter.DESCENDING) {
            menu.findItem(R.id.menu_sort_order_descending).setChecked(true);
        }

        FeedOrderFilter feedOrderFilter = PrefsUtils.getWidgetConfigFeedOrder(this);
        if (feedOrderFilter == FeedOrderFilter.NAME) {
            menu.findItem(R.id.menu_sort_by_name).setChecked(true);
        } else if (feedOrderFilter == FeedOrderFilter.SUBSCRIBERS) {
            menu.findItem(R.id.menu_sort_by_subs).setChecked(true);
        } else if (feedOrderFilter == FeedOrderFilter.STORIES_MONTH) {
            menu.findItem(R.id.menu_sort_by_stories_month).setChecked(true);
        } else if (feedOrderFilter == FeedOrderFilter.RECENT_STORY) {
            menu.findItem(R.id.menu_sort_by_recent_story).setChecked(true);
        } else if (feedOrderFilter == FeedOrderFilter.OPENS) {
            menu.findItem(R.id.menu_sort_by_number_opens).setChecked(true);
        }

        FolderViewFilter folderViewFilter = PrefsUtils.getWidgetConfigFolderView(this);
        if (folderViewFilter == FolderViewFilter.NESTED) {
            menu.findItem(R.id.menu_folder_view_nested).setChecked(true);
        } else if (folderViewFilter == FolderViewFilter.FLAT) {
            menu.findItem(R.id.menu_folder_view_flat).setChecked(true);
        }

        WidgetBackground widgetBackground = PrefsUtils.getWidgetBackground(this);
        if (widgetBackground == WidgetBackground.DEFAULT) {
            menu.findItem(R.id.menu_widget_background_default).setChecked(true);
        } else if (widgetBackground == WidgetBackground.TRANSPARENT) {
            menu.findItem(R.id.menu_widget_background_transparent).setChecked(true);
        }
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case android.R.id.home:
                finish();
                return true;
            case R.id.menu_sort_order_ascending:
                replaceListOrderFilter(ListOrderFilter.ASCENDING);
                return true;
            case R.id.menu_sort_order_descending:
                replaceListOrderFilter(ListOrderFilter.DESCENDING);
                return true;
            case R.id.menu_sort_by_name:
                replaceFeedOrderFilter(FeedOrderFilter.NAME);
                return true;
            case R.id.menu_sort_by_subs:
                replaceFeedOrderFilter(FeedOrderFilter.SUBSCRIBERS);
                return true;
            case R.id.menu_sort_by_recent_story:
                replaceFeedOrderFilter(FeedOrderFilter.RECENT_STORY);
                return true;
            case R.id.menu_sort_by_stories_month:
                replaceFeedOrderFilter(FeedOrderFilter.STORIES_MONTH);
                return true;
            case R.id.menu_sort_by_number_opens:
                replaceFeedOrderFilter(FeedOrderFilter.OPENS);
                return true;
            case R.id.menu_folder_view_nested:
                replaceFolderView(FolderViewFilter.NESTED);
                return true;
            case R.id.menu_folder_view_flat:
                replaceFolderView(FolderViewFilter.FLAT);
                return true;
            case R.id.menu_select_all:
                selectAllFeeds();
                return true;
            case R.id.menu_select_none:
                replaceWidgetFeedIds(Collections.<String>emptySet());
                return true;
            case R.id.menu_widget_background_default:
                setWidgetBackground(WidgetBackground.DEFAULT);
                return true;
            case R.id.menu_widget_background_transparent:
                setWidgetBackground(WidgetBackground.TRANSPARENT);
                return true;
            default:
                return super.onOptionsItemSelected(item);
        }
    }

    private void setupList() {
        adapter = new WidgetConfigAdapter(this);
        listView.setAdapter(adapter);
    }

    private void loadFeeds() {
        Loader<Cursor> loader = FeedUtils.dbHelper.getFeedsLoader();
        loader.registerListener(loader.getId(), new Loader.OnLoadCompleteListener<Cursor>() {
            @Override
            public void onLoadComplete(@NonNull Loader<Cursor> loader, @Nullable Cursor cursor) {
                processFeeds(cursor);
            }
        });
        loader.startLoading();
    }

    private void loadFolders() {
        Loader<Cursor> loader = FeedUtils.dbHelper.getFoldersLoader();
        loader.registerListener(loader.getId(), new Loader.OnLoadCompleteListener<Cursor>() {
            @Override
            public void onLoadComplete(@NonNull Loader<Cursor> loader, @Nullable Cursor cursor) {
                processFolders(cursor);
            }
        });
        loader.startLoading();
    }

    private void processFeeds(Cursor cursor) {
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

    private void processFolders(Cursor cursor) {
        ArrayList<Folder> folders = new ArrayList<>();
        while (cursor != null && cursor.moveToNext()) {
            Folder folder = Folder.fromCursor(cursor);
            if (!folder.feedIds.isEmpty()) {
                folders.add(folder);
            }
        }
        this.folders = folders;
        Collections.sort(this.folders, new Comparator<Folder>() {
            @Override
            public int compare(Folder o1, Folder o2) {
                return Folder.compareFolderNames(o1.flatName(), o2.flatName());
            }
        });
        processData();
    }

    private void processData() {
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

            setSelectedFeeds();
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

    private void replaceFeedOrderFilter(FeedOrderFilter feedOrderFilter) {
        PrefsUtils.setWidgetConfigFeedOrder(this, feedOrderFilter);
        adapter.replaceFeedOrder(feedOrderFilter);
    }

    private void replaceListOrderFilter(ListOrderFilter listOrderFilter) {
        PrefsUtils.setWidgetConfigListOrder(this, listOrderFilter);
        adapter.replaceListOrder(listOrderFilter);
    }

    private void replaceFolderView(FolderViewFilter folderViewFilter) {
        PrefsUtils.setWidgetConfigFolderView(this, folderViewFilter);
        adapter.replaceFolderView(folderViewFilter);
        setAdapterData();
    }

    private void setWidgetBackground(WidgetBackground widgetBackground) {
        PrefsUtils.setWidgetBackground(this, widgetBackground);
        WidgetUtils.updateWidget(this);
    }

    private void setSelectedFeeds() {
        Set<String> feedIds = PrefsUtils.getWidgetFeedIds(this);
        // by default select all feeds
        if (feedIds == null) {
            feedIds = new HashSet<>(this.feeds.size());
            for (Feed feed : this.feeds) {
                feedIds.add(feed.feedId);
            }
        }
        adapter.setFeedIds(feedIds);
    }

    private void setAdapterData() {
        adapter.setData(this.folderNames, this.folderChildren, this.feeds);

        listView.setVisibility(this.feeds.isEmpty() ? View.GONE : View.VISIBLE);
        textNoSubscriptions.setVisibility(this.feeds.isEmpty() ? View.VISIBLE : View.GONE);
    }
}