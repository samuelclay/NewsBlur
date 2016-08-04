package com.newsblur.fragment;

import android.app.Activity;
import android.app.LoaderManager;
import android.content.Loader;
import android.database.Cursor;
import android.graphics.Typeface;
import android.os.Bundle;
import android.util.Log;
import android.view.ContextMenu;
import android.view.GestureDetector;
import android.view.LayoutInflater;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnTouchListener;
import android.view.ContextMenu.ContextMenuInfo;
import android.view.View.OnCreateContextMenuListener;
import android.view.ViewGroup;
import android.widget.AbsListView;
import android.widget.AbsListView.OnScrollListener;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ImageView;
import android.widget.ListView;
import android.widget.TextView;

import butterknife.ButterKnife;
import butterknife.Bind;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.database.StoryItemsAdapter;
import com.newsblur.domain.Story;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.UIUtils;
import com.newsblur.util.ViewUtils;
import com.newsblur.view.ProgressThrobber;

public abstract class ItemListFragment extends NbFragment implements OnScrollListener, OnCreateContextMenuListener, LoaderManager.LoaderCallbacks<Cursor>, OnItemClickListener {

	public static int ITEMLIST_LOADER = 0x01;

    protected ItemsList activity;
	@Bind(R.id.itemlistfragment_list) ListView itemList;
	protected StoryItemsAdapter adapter;
    protected DefaultFeedView defaultFeedView;
    private boolean cursorSeenYet = false;
    private boolean stopLoading = false;
    
    // loading indicator for when stories are present but stale (at top of list)
    protected ProgressThrobber headerProgressView;
    // loading indicator for when stories are present and fresh (at bottom of list)
    protected ProgressThrobber footerProgressView;
    // loading indicator for when no stories are loaded yet (instead of list)
    @Bind(R.id.empty_view_loading_throb) ProgressThrobber emptyProgressView;

    private View fleuronFooter;

    @Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
        defaultFeedView = (DefaultFeedView)getArguments().getSerializable("defaultFeedView");
        activity = (ItemsList) getActivity();
    }

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
        ButterKnife.bind(this, v);

        // disable the throbbers if animations are going to have a zero time scale
        boolean isDisableAnimations = ViewUtils.isPowerSaveMode(activity);

        emptyProgressView.setEnabled(!isDisableAnimations);
        emptyProgressView.setColors(UIUtils.getColor(getActivity(), R.color.refresh_1),
                                    UIUtils.getColor(getActivity(), R.color.refresh_2),
                                    UIUtils.getColor(getActivity(), R.color.refresh_3),
                                    UIUtils.getColor(getActivity(), R.color.refresh_4));
        View headerView = inflater.inflate(R.layout.row_loading_throbber, null);
        headerProgressView = (ProgressThrobber) headerView.findViewById(R.id.itemlist_loading_throb);
        headerProgressView.setEnabled(!isDisableAnimations);
        headerProgressView.setColors(UIUtils.getColor(getActivity(), R.color.refresh_1),
                                     UIUtils.getColor(getActivity(), R.color.refresh_2),
                                     UIUtils.getColor(getActivity(), R.color.refresh_3),
                                     UIUtils.getColor(getActivity(), R.color.refresh_4));
        itemList.addHeaderView(headerView, null, false);
        itemList.setHeaderDividersEnabled(false);

        View footerView = inflater.inflate(R.layout.row_loading_throbber, null);
        footerProgressView = (ProgressThrobber) footerView.findViewById(R.id.itemlist_loading_throb);
        footerProgressView.setEnabled(!isDisableAnimations);
        footerProgressView.setColors(UIUtils.getColor(getActivity(), R.color.refresh_1),
                                     UIUtils.getColor(getActivity(), R.color.refresh_2),
                                     UIUtils.getColor(getActivity(), R.color.refresh_3),
                                     UIUtils.getColor(getActivity(), R.color.refresh_4));
        itemList.addFooterView(footerView, null, false);
        itemList.setFooterDividersEnabled(false);

        fleuronFooter = inflater.inflate(R.layout.row_fleuron, null);
        fleuronFooter.setVisibility(View.GONE);
        itemList.addFooterView(fleuronFooter, null, false);

		itemList.setEmptyView(v.findViewById(R.id.empty_view));
        setupBezelSwipeDetector(itemList);
        itemList.setOnScrollListener(this);
		itemList.setOnItemClickListener(this);
        itemList.setOnCreateContextMenuListener(this);
        if (adapter != null) {
            // normally the adapter is set when it is created in onLoadFinished(), but sometimes
            // onCreateView gets re-called thereafter.
            itemList.setAdapter(adapter);
        }
		return v;
	}

    @Override
    public synchronized void onActivityCreated(Bundle savedInstanceState) {
        super.onActivityCreated(savedInstanceState);
        stopLoading = false;
        if (getLoaderManager().getLoader(ITEMLIST_LOADER) == null) {
            getLoaderManager().initLoader(ITEMLIST_LOADER, null, this);
        }
    }

    private void triggerRefresh(int desiredStoryCount, int totalSeen) {
        boolean gotSome = NBSyncService.requestMoreForFeed(getFeedSet(), desiredStoryCount, totalSeen);
        if (gotSome) triggerSync();
    }

    /**
     * Signal that all futher cursor loads should be ignored
     */
    public void stopLoader() {
        stopLoading = true;
    }

    /**
     * Indicate that the DB was cleared.
     */
    public void resetEmptyState() {
        cursorSeenYet = false;
        FeedUtils.dbHelper.clearStorySession();
    }

    /**
     * Turns on/off the loading indicator. Note that the text component of the
     * loading indicator requires a cursor and is handled below.
     */
    public void setLoading(boolean isLoading) {
        if (fleuronFooter != null) {
            if (isLoading) {
                if (NBSyncService.isFeedSetStoriesFresh(getFeedSet())) {
                    headerProgressView.setVisibility(View.INVISIBLE);
                    footerProgressView.setVisibility(View.VISIBLE);
                } else {
                    headerProgressView.setVisibility(View.VISIBLE);
                    footerProgressView.setVisibility(View.GONE);
                }
                emptyProgressView.setVisibility(View.VISIBLE);
                fleuronFooter.setVisibility(View.GONE);
            } else {
                headerProgressView.setVisibility(View.INVISIBLE);
                footerProgressView.setVisibility(View.GONE);
                emptyProgressView.setVisibility(View.GONE);
                if (cursorSeenYet && NBSyncService.isFeedSetExhausted(getFeedSet())) {
                    fleuronFooter.setVisibility(View.VISIBLE);
                }
            }
        }
    }

    private void updateLoadingMessage() {
        if (itemList == null) {
            Log.w(this.getClass().getName(), "ItemListFragment does not have the expected ListView.");
            return;
        }
        View emptyView = itemList.getEmptyView();
        TextView textView = (TextView) emptyView.findViewById(R.id.empty_view_text);
        ImageView imageView = (ImageView) emptyView.findViewById(R.id.empty_view_image);

        boolean isLoading = NBSyncService.isFeedSetSyncing(getFeedSet(), activity);
        if (isLoading || (!cursorSeenYet)) {
            textView.setText(R.string.empty_list_view_loading);
            textView.setTypeface(null, Typeface.ITALIC);
            imageView.setVisibility(View.INVISIBLE);
        } else {
            ReadFilter readFilter = PrefsUtils.getReadFilter(activity, getFeedSet());
            if (readFilter == ReadFilter.UNREAD) {
                textView.setText(R.string.empty_list_view_no_stories_unread);
            } else {
                textView.setText(R.string.empty_list_view_no_stories);
            }
            textView.setTypeface(null, Typeface.NORMAL);
            imageView.setVisibility(View.VISIBLE);
        }
    }

    public void scrollToTop() {
        if (itemList == null) {
            Log.w(this.getClass().getName(), "ItemListFragment does not have the expected ListView.");
            return;
        }

        itemList.setSelection(0);
    }

	@Override
	public synchronized void onScroll(AbsListView view, int firstVisible, int visibleCount, int totalCount) {
        // the framework likes to trigger this on init before we even known counts, so disregard those
        if (!cursorSeenYet) return;

        // there are two fake rows for header/footer that don't count
        int storiesSeen = totalCount - 2;
        if (storiesSeen < 0) storiesSeen = 0;

        // load an extra page or two worth of stories past the viewport
        int desiredStoryCount = firstVisible + (visibleCount*2) + 1;
        triggerRefresh(desiredStoryCount, storiesSeen);
	}

	@Override
	public void onScrollStateChanged(AbsListView view, int scrollState) { }

    protected FeedSet getFeedSet() {
        return activity.getFeedSet();
    }

	public void hasUpdated() {
        if (isAdded()) {
		    getLoaderManager().restartLoader(ITEMLIST_LOADER , null, this);
        }
	}

	@Override
	public Loader<Cursor> onCreateLoader(int arg0, Bundle arg1) {
        FeedSet fs = getFeedSet();
        if (fs == null) {
            Log.e(this.getClass().getName(), "can't create fragment, no feedset ready");
            // this is probably happening in a finalisation cycle or during a crash, pop the activity stack
            try { getActivity().finish(); } catch (Exception e) {;}
            return null;
        }
		return FeedUtils.dbHelper.getActiveStoriesLoader(getFeedSet());
	}

    @Override
	public synchronized void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if (stopLoading) return;
		if (cursor != null) {
            if (NBSyncService.ResetSession) {
                // the DB hasn't caught up yet from the last story list; don't display stale stories.
                triggerRefresh(1, 0);
                return;
            }
            cursorSeenYet = true;
            if (cursor.getCount() < 1) {
                triggerRefresh(1, 0);
            }
            adapter.swapCursor(cursor);
		}
        updateLoadingMessage();
	}

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
        if (adapter != null) adapter.notifyDataSetInvalidated();
	}

    public void setDefaultFeedView(DefaultFeedView value) {
        this.defaultFeedView = value;
    }

    @Override
    public void onCreateContextMenu(ContextMenu menu, View v, ContextMenuInfo menuInfo) {
        MenuInflater inflater = getActivity().getMenuInflater();
        if (PrefsUtils.getStoryOrder(activity, getFeedSet()) == StoryOrder.NEWEST) {
            inflater.inflate(R.menu.context_story_newest, menu);
        } else {
            inflater.inflate(R.menu.context_story_oldest, menu);
        }

        int truePosition = ((AdapterView.AdapterContextMenuInfo) menuInfo).position - 1;
        Story story = adapter.getStory(truePosition);
        if (getFeedSet().isFilterSaved()) {
            menu.removeItem(R.id.menu_mark_story_as_read);
            menu.removeItem(R.id.menu_mark_story_as_unread);
        } else if (story.read) {
            menu.removeItem(R.id.menu_mark_story_as_read);
        } else {
            menu.removeItem(R.id.menu_mark_story_as_unread);
        }

        if (story.starred) {
            menu.removeItem(R.id.menu_save_story);
        } else {
            menu.removeItem(R.id.menu_unsave_story);
        }
    }
    
    @Override
    public boolean onContextItemSelected(MenuItem item) {
        AdapterView.AdapterContextMenuInfo menuInfo = (AdapterView.AdapterContextMenuInfo)item.getMenuInfo();
        int truePosition = menuInfo.position - 1;
        Story story = adapter.getStory(truePosition);
        Activity activity = getActivity();

        switch (item.getItemId()) {
        case R.id.menu_mark_story_as_read:
            FeedUtils.markStoryAsRead(story, activity);
            return true;

        case R.id.menu_mark_story_as_unread:
            FeedUtils.markStoryUnread(story, activity);
            return true;

        case R.id.menu_mark_older_stories_as_read:
            FeedUtils.markFeedsRead(getFeedSet(), story.timestamp, null, activity);
            return true;

        case R.id.menu_mark_newer_stories_as_read:
            FeedUtils.markFeedsRead(getFeedSet(), null, story.timestamp, activity);
            return true;

        case R.id.menu_send_story:
            FeedUtils.sendStoryBrief(story, activity);
            return true;

        case R.id.menu_send_story_full:
            FeedUtils.sendStoryFull(story, activity);
            return true;

        case R.id.menu_save_story:
            FeedUtils.setStorySaved(story, true, activity);
            return true;

        case R.id.menu_unsave_story:
            FeedUtils.setStorySaved(story, false, activity);

            return true;

        default:
            return super.onContextItemSelected(item);
        }
    }

	@Override
	public synchronized void onItemClick(AdapterView<?> parent, View view, int position, long id) {
        int truePosition = position - 1;
        Story story = adapter.getStory(truePosition);
        if (getActivity().isFinishing()) return;
        UIUtils.startReadingActivity(getFeedSet(), story.storyHash, getActivity());
    }

    public void setTextSize(Float size) {
        if (adapter != null) {
            adapter.setTextSize(size);
            adapter.notifyDataSetChanged();
        }

    }

    protected void setupBezelSwipeDetector(View v) {
        final GestureDetector gestureDetector = new GestureDetector(getActivity(), new BezelSwipeDetector());
        v.setOnTouchListener(new OnTouchListener() {
            public boolean onTouch(View v, MotionEvent event) {
                return gestureDetector.onTouchEvent(event);
            }
        });
    }

    /**
     * A gesture detector that captures bezel swipes and finishes the activity,
     * to simulate a 'back' gesture.
     *
     * NB: pretty much all Views still try to process on-tap events despite
     *     returning true, so be sure to check isFinishing() on all other
     *     tap handlers.
     */
    class BezelSwipeDetector extends GestureDetector.SimpleOnGestureListener {
        @Override
        public boolean onScroll(MotionEvent e1, MotionEvent e2, float distanceX, float distanceY) {
            if((e1.getX() < 75f) &&                  // the gesture should start from the left bezel and
               ((e2.getX()-e1.getX()) > 90f) &&      // move horizontally to the right and
               (Math.abs(e1.getY()-e2.getY()) < 40f) // have minimal vertical travel, so we don't capture scrolling gestures
               ) {
                ItemListFragment.this.getActivity().finish();
                return true;
            }
            return false;
        }
    }
}
