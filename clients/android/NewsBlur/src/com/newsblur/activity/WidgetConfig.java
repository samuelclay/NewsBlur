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
import android.view.View;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.util.FeedOrderFilter;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ListOrderFilter;
import com.newsblur.util.PrefsUtils;
import com.newsblur.widget.WidgetUtils;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

import butterknife.Bind;
import butterknife.ButterKnife;

public class WidgetConfig extends NbActivity {

    @Bind(R.id.recycler_view)
    RecyclerView recyclerView;
    @Bind(R.id.text_no_subscriptions)
    TextView textNoSubscriptions;

    private WidgetConfigAdapter adapter;
    private ArrayList<Feed> feeds = new ArrayList<>();

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_widget_config);
        ButterKnife.bind(this);
        getActionBar().setDisplayHomeAsUpEnabled(true);

        adapter = new WidgetConfigAdapter();
        recyclerView.setAdapter(adapter);

        loadFeeds();
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
        ListOrderFilter listOrderFilter = PrefsUtils.getWidgetConfigSortOrder(this);
        if (listOrderFilter == ListOrderFilter.ASCENDING) {
            menu.findItem(R.id.menu_sort_order_ascending).setChecked(true);
        } else if (listOrderFilter == ListOrderFilter.DESCENDING) {
            menu.findItem(R.id.menu_sort_order_descending).setChecked(true);
        }

        FeedOrderFilter feedOrderFilter = PrefsUtils.getWidgetConfigSortBy(this);
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
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case android.R.id.home:
                finish();
                return true;
            case R.id.menu_sort_order_ascending:
                setSortOrder(ListOrderFilter.ASCENDING);
                return true;
            case R.id.menu_sort_order_descending:
                setSortOrder(ListOrderFilter.DESCENDING);
                return true;
            case R.id.menu_sort_by_name:
                setSortBy(FeedOrderFilter.NAME);
                return true;
            case R.id.menu_sort_by_subs:
                setSortBy(FeedOrderFilter.SUBSCRIBERS);
                return true;
            case R.id.menu_sort_by_recent_story:
                setSortBy(FeedOrderFilter.RECENT_STORY);
                return true;
            case R.id.menu_sort_by_stories_month:
                setSortBy(FeedOrderFilter.STORIES_MONTH);
                return true;
            case R.id.menu_sort_by_number_opens:
                setSortBy(FeedOrderFilter.OPENS);
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

    private void loadFeeds() {
        Loader<Cursor> loader = FeedUtils.dbHelper.getFeedsLoader();
        loader.registerListener(loader.getId(), new Loader.OnLoadCompleteListener<Cursor>() {
            @Override
            public void onLoadComplete(@NonNull Loader<Cursor> loader, @Nullable Cursor cursor) {
                showFeeds(cursor);
            }
        });
        loader.startLoading();
    }

    private void showFeeds(Cursor cursor) {
        ArrayList<Feed> feeds = new ArrayList<>();
        while (cursor != null && cursor.moveToNext()) {
            Feed feed = Feed.fromCursor(cursor);
            if (!feed.feedId.equals("0") && feed.active) {
                feeds.add(feed);
            }
        }
        this.feeds = feeds;

        Set<String> feedIds = PrefsUtils.getWidgetFeedIds(this);
        if (feedIds == null) {
            // default config. Show all feeds
            feedIds = new HashSet<>(this.feeds.size());
            for (Feed feed : this.feeds) {
                feedIds.add(feed.feedId);
            }
        }
        adapter.replaceAll(this, this.feeds, feedIds);
        updateListOrder();

        recyclerView.setVisibility(adapter.getItemCount() > 0 ? View.VISIBLE : View.GONE);
        textNoSubscriptions.setVisibility(adapter.getItemCount() > 0 ? View.GONE : View.VISIBLE);
    }

    private void selectAllFeeds() {
        Set<String> feedIds = new HashSet<>(this.feeds.size());
        for (Feed feed : this.feeds) {
            feedIds.add(feed.feedId);
        }
        setWidgetFeedIds(feedIds);
    }

    private void setWidgetFeedIds(Set<String> feedIds) {
        PrefsUtils.setWidgetFeedIds(this, feedIds);
        adapter.replaceAll(this, this.feeds, feedIds);
    }

    private void setSortBy(FeedOrderFilter feedOrderFilter) {
        PrefsUtils.setWidgetConfigSortBy(this, feedOrderFilter);
        updateListOrder();
    }

    private void setSortOrder(ListOrderFilter listOrderFilter) {
        PrefsUtils.setWidgetConfigSortOrder(this, listOrderFilter);
        updateListOrder();
    }

    private void updateListOrder() {
        Collections.sort(this.feeds, getListComparator());
        FeedOrderFilter feedOrder = PrefsUtils.getWidgetConfigSortBy(this);
        adapter.diffAll(this.feeds, feedOrder);
    }

    private Comparator<Feed> getListComparator() {
        return new Comparator<Feed>() {
            @Override
            public int compare(Feed o1, Feed o2) {
                ListOrderFilter listOrderFilter = PrefsUtils.getWidgetConfigSortOrder(WidgetConfig.this);
                FeedOrderFilter feedOrderFilter = PrefsUtils.getWidgetConfigSortBy(WidgetConfig.this);
                if (feedOrderFilter == FeedOrderFilter.NAME && listOrderFilter == ListOrderFilter.ASCENDING) {
                    return o1.title.compareTo(o2.title);
                } else if (feedOrderFilter == FeedOrderFilter.NAME && listOrderFilter == ListOrderFilter.DESCENDING) {
                    return o2.title.compareTo(o1.title);
                } else if (feedOrderFilter == FeedOrderFilter.SUBSCRIBERS && listOrderFilter == ListOrderFilter.ASCENDING) {
                    return Integer.valueOf(o1.subscribers).compareTo(Integer.valueOf(o2.subscribers));
                } else if (feedOrderFilter == FeedOrderFilter.SUBSCRIBERS && listOrderFilter == ListOrderFilter.DESCENDING) {
                    return Integer.valueOf(o2.subscribers).compareTo(Integer.valueOf(o1.subscribers));
                } else if (feedOrderFilter == FeedOrderFilter.OPENS && listOrderFilter == ListOrderFilter.ASCENDING) {
                    return Integer.compare(o1.feedOpens, o2.feedOpens);
                } else if (feedOrderFilter == FeedOrderFilter.OPENS && listOrderFilter == ListOrderFilter.DESCENDING) {
                    return Integer.compare(o2.feedOpens, o1.feedOpens);
                } else if (feedOrderFilter == FeedOrderFilter.RECENT_STORY && listOrderFilter == ListOrderFilter.ASCENDING) {
                    try {
                        DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
                        Date firstDate = dateFormat.parse(o1.lastStoryDate);
                        Date secondDate = dateFormat.parse(o2.lastStoryDate);
                        return secondDate.compareTo(firstDate);
                    } catch (ParseException e) {
                        e.printStackTrace();
                    }
                } else if (feedOrderFilter == FeedOrderFilter.RECENT_STORY && listOrderFilter == ListOrderFilter.DESCENDING) {
                    try {
                        DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
                        Date firstDate = dateFormat.parse(o1.lastStoryDate);
                        Date secondDate = dateFormat.parse(o2.lastStoryDate);
                        return firstDate.compareTo(secondDate);
                    } catch (ParseException e) {
                        e.printStackTrace();
                    }
                } else if (feedOrderFilter == FeedOrderFilter.STORIES_MONTH && listOrderFilter == ListOrderFilter.ASCENDING) {
                    return Integer.compare(o1.storiesPerMonth, o2.storiesPerMonth);
                } else if (feedOrderFilter == FeedOrderFilter.STORIES_MONTH && listOrderFilter == ListOrderFilter.DESCENDING) {
                    return Integer.compare(o2.storiesPerMonth, o1.storiesPerMonth);
                }
                return o1.title.compareTo(o2.title);
            }
        };
    }
}