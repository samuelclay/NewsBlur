package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;

import androidx.annotation.Nullable;
import androidx.lifecycle.ViewModelProvider;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.util.FeedOrderFilter;
import com.newsblur.util.FolderViewFilter;
import com.newsblur.util.ListOrderFilter;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.WidgetBackground;
import com.newsblur.viewModel.FeedFolderViewModel;
import com.newsblur.widget.WidgetUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

abstract public class FeedChooser extends NbActivity {

    protected FeedChooserAdapter adapter;
    protected ArrayList<Feed> feeds;
    protected ArrayList<Folder> folders;
    protected Map<String, Feed> feedMap = new HashMap<>();
    protected ArrayList<String> folderNames = new ArrayList<>();
    protected ArrayList<ArrayList<Feed>> folderChildren = new ArrayList<>();
    private FeedFolderViewModel feedFolderViewModel;

    abstract void bindLayout();

    abstract void setupList();

    abstract void processFeeds(Cursor cursor);

    abstract void processData();

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        feedFolderViewModel = new ViewModelProvider(this).get(FeedFolderViewModel.class);
        bindLayout();
        setupList();
        setupObservers();
        loadData();
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
        ListOrderFilter listOrderFilter = PrefsUtils.getFeedChooserListOrder(this);
        if (listOrderFilter == ListOrderFilter.ASCENDING) {
            menu.findItem(R.id.menu_sort_order_ascending).setChecked(true);
        } else if (listOrderFilter == ListOrderFilter.DESCENDING) {
            menu.findItem(R.id.menu_sort_order_descending).setChecked(true);
        }

        FeedOrderFilter feedOrderFilter = PrefsUtils.getFeedChooserFeedOrder(this);
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

        FolderViewFilter folderViewFilter = PrefsUtils.getFeedChooserFolderView(this);
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
            case R.id.menu_widget_background_default:
                setWidgetBackground(WidgetBackground.DEFAULT);
                return true;
            case R.id.menu_widget_background_transparent:
                setWidgetBackground(WidgetBackground.TRANSPARENT);
            default:
                return super.onOptionsItemSelected(item);
        }
    }

    protected void setAdapterData() {
        adapter.setData(this.folderNames, this.folderChildren, this.feeds);
    }

    private void setupObservers() {
        feedFolderViewModel.getFoldersLiveData().observe(this, this::processFolders);
        feedFolderViewModel.getFeedsLiveData().observe(this, this::processFeeds);
    }

    private void replaceFeedOrderFilter(FeedOrderFilter feedOrderFilter) {
        PrefsUtils.setFeedChooserFeedOrder(this, feedOrderFilter);
        adapter.replaceFeedOrder(feedOrderFilter);
    }

    private void replaceListOrderFilter(ListOrderFilter listOrderFilter) {
        PrefsUtils.setFeedChooserListOrder(this, listOrderFilter);
        adapter.replaceListOrder(listOrderFilter);
    }

    private void replaceFolderView(FolderViewFilter folderViewFilter) {
        PrefsUtils.setFeedChooserFolderView(this, folderViewFilter);
        adapter.replaceFolderView(folderViewFilter);
        setAdapterData();
    }

    private void setWidgetBackground(WidgetBackground widgetBackground) {
        PrefsUtils.setWidgetBackground(this, widgetBackground);
        WidgetUtils.updateWidget(this);
    }

    private void loadData() {
        feedFolderViewModel.getData();
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
        Collections.sort(this.folders, (o1, o2) -> Folder.compareFolderNames(o1.flatName(), o2.flatName()));
        processData();
    }
}
