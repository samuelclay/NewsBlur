package com.newsblur.fragment;

import android.app.Activity;
import android.app.LoaderManager;
import android.content.Loader;
import android.database.Cursor;
import android.graphics.Typeface;
import android.graphics.Rect;
import android.os.Bundle;
import android.support.v7.widget.GridLayoutManager;
import android.support.v7.widget.RecyclerView;
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
import com.newsblur.database.StoryViewAdapter;
import com.newsblur.domain.Story;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.GestureAction;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryListStyle;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.UIUtils;
import com.newsblur.util.ViewUtils;
import com.newsblur.view.ProgressThrobber;

public class ItemSetFragment extends NbFragment implements LoaderManager.LoaderCallbacks<Cursor> {

	public static int ITEMLIST_LOADER = 0x01;

    protected ItemsList activity;
    protected boolean cursorSeenYet = false;
    private boolean stopLoading = false;

    private int columnCount;

    private final static int GRID_SPACING_DP = 5;
    private int gridSpacingPx;

	@Bind(R.id.itemgridfragment_grid) RecyclerView itemGrid;
    private GridLayoutManager layoutManager;
    private StoryViewAdapter adapter;

    // loading indicator for when stories are absent or stale (at top of list)
    @Bind(R.id.top_loading_throb) ProgressThrobber topProgressView;
    // loading indicator for when stories are present and fresh (at bottom of list)
    protected ProgressThrobber bottomProgressView;

    @Bind(R.id.empty_view) View emptyView;
    @Bind(R.id.empty_view_text) TextView emptyViewText;
    @Bind(R.id.empty_view_image) ImageView emptyViewImage;

    private View fleuronFooter;

    // de-dupe the massive stream of scrolling data to auto-mark read
    private int lastAutoMarkIndex = -1;

	public static ItemSetFragment newInstance() {
		ItemSetFragment fragment = new ItemSetFragment();
		Bundle arguments = new Bundle();
		fragment.setArguments(arguments);
		return fragment;
	}
    
    @Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
        activity = (ItemsList) getActivity();

        if (getFeedSet() == null) {
            com.newsblur.util.Log.w(this.getClass().getName(), "item list started without FeedSet.");
            activity.finish();
            return;
        }

        // warm up the sync service as soon as possible since it will init the story session DB
        triggerRefresh(1, null);
    }

    @Override
    public void onStart() {
        super.onStart();
        stopLoading = false;
        getLoaderManager().initLoader(ITEMLIST_LOADER, null, this);
    }

    @Override
    public void onPause() {
        // a pause/resume cycle will depopulate and repopulate the list and trigger bad scroll
        // readings and cause zero-index refreshes, wasting massive cycles. hold the refresh logic
        // until the loaders reset
        cursorSeenYet = false;
        super.onPause();
    }

    @Override
    public void onResume() {
        if (!adapter.isCursorValid()) {
            com.newsblur.util.Log.e(this.getClass().getName(), "stale fragment loaded, falling back.");
            getActivity().finish();
        }
        super.onResume();
    }

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemgrid, null);
        ButterKnife.bind(this, v);

        // disable the throbbers if animations are going to have a zero time scale
        boolean isDisableAnimations = ViewUtils.isPowerSaveMode(activity);

        topProgressView.setEnabled(!isDisableAnimations);
        topProgressView.setColors(UIUtils.getColor(getActivity(), R.color.refresh_1),
                                  UIUtils.getColor(getActivity(), R.color.refresh_2),
                                  UIUtils.getColor(getActivity(), R.color.refresh_3),
                                  UIUtils.getColor(getActivity(), R.color.refresh_4));

        View footerView = inflater.inflate(R.layout.row_loading_throbber, null);
        bottomProgressView = (ProgressThrobber) footerView.findViewById(R.id.itemlist_loading_throb);
        bottomProgressView.setEnabled(!isDisableAnimations);
        bottomProgressView.setColors(UIUtils.getColor(getActivity(), R.color.refresh_1),
                                     UIUtils.getColor(getActivity(), R.color.refresh_2),
                                     UIUtils.getColor(getActivity(), R.color.refresh_3),
                                     UIUtils.getColor(getActivity(), R.color.refresh_4));

        fleuronFooter = inflater.inflate(R.layout.row_fleuron, null);
        fleuronFooter.setVisibility(View.GONE);

        StoryListStyle listStyle = PrefsUtils.getStoryListStyle(getActivity(), getFeedSet());

        calcColumnCount(listStyle);
        layoutManager = new GridLayoutManager(getActivity(), columnCount);
        itemGrid.setLayoutManager(layoutManager);

        calcGridSpacing(listStyle);
        itemGrid.addItemDecoration(new RecyclerView.ItemDecoration() {
            @Override
            public void getItemOffsets(Rect outRect, View view, RecyclerView parent, RecyclerView.State state) {
                outRect.set(gridSpacingPx, gridSpacingPx, gridSpacingPx, gridSpacingPx);
            }
        });

        adapter = new StoryViewAdapter(getActivity(), getFeedSet(), listStyle);
        adapter.addFooterView(footerView);
        adapter.addFooterView(fleuronFooter);
        itemGrid.setAdapter(adapter); 

        // the layout manager needs to know that the footer rows span all the way across
        layoutManager.setSpanSizeLookup(new GridLayoutManager.SpanSizeLookup() {
            @Override
            public int getSpanSize(int position) {
                switch (adapter.getItemViewType(position)) {
                    case StoryViewAdapter.VIEW_TYPE_FOOTER:
                        return columnCount;
                    default:
                        return 1;
                }
            }
        });

        itemGrid.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrolled(RecyclerView recyclerView, int dx, int dy) {
                ItemSetFragment.this.onScrolled(recyclerView, dx, dy);
            }
        });

		return v;
	}

    protected void triggerRefresh(int desiredStoryCount, Integer totalSeen) {
        if (getFeedSet().isMuted()) return;

        // ask the sync service for as many stories as we want
        boolean gotSome = NBSyncService.requestMoreForFeed(getFeedSet(), desiredStoryCount, totalSeen);
        // if the service thinks it can get more, or if we haven't even seen a cursor yet, start the service
        if (gotSome || (totalSeen == null)) triggerSync();
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
        setShowNone(true);
        cursorSeenYet = false;
    }

    /**
     * Turns on/off the loading indicator. Note that the text component of the
     * loading indicator/explainer requires a cursor and is handled below.
     */
    public void setLoading(boolean isLoading) {
        // sanity check that we even have views yet
        if (fleuronFooter == null) return;

        if (isLoading) {
            if (NBSyncService.isFeedSetStoriesFresh(getFeedSet())) {
                topProgressView.setVisibility(View.INVISIBLE);
                bottomProgressView.setVisibility(View.VISIBLE);
            } else {
                topProgressView.setVisibility(View.VISIBLE);
                bottomProgressView.setVisibility(View.GONE);
            }
            fleuronFooter.setVisibility(View.GONE);
        } else {
            topProgressView.setVisibility(View.INVISIBLE);
            bottomProgressView.setVisibility(View.INVISIBLE);
            if (cursorSeenYet && NBSyncService.isFeedSetExhausted(getFeedSet()) && (adapter.getStoryCount() > 0)) {
                fleuronFooter.setVisibility(View.VISIBLE);
            }
        }
    }

    /**
     * Set up the text view that shows when no stories are yet visible.
     */
    private void updateLoadingMessage() {
        if (getFeedSet().isMuted()) {
            emptyViewText.setText(R.string.empty_list_view_muted_feed);
            emptyViewText.setTypeface(null, Typeface.NORMAL);
            emptyViewImage.setVisibility(View.VISIBLE);
        } else {
            if (NBSyncService.isFeedSetSyncing(getFeedSet(), activity) || (!cursorSeenYet)) {
                emptyViewText.setText(R.string.empty_list_view_loading);
                emptyViewText.setTypeface(null, Typeface.ITALIC);
                emptyViewImage.setVisibility(View.INVISIBLE);
            } else {
                ReadFilter readFilter = PrefsUtils.getReadFilter(getActivity(), getFeedSet());
                if (readFilter == ReadFilter.UNREAD) {
                    emptyViewText.setText(R.string.empty_list_view_no_stories_unread);
                } else {
                    emptyViewText.setText(R.string.empty_list_view_no_stories);
                }
                emptyViewText.setTypeface(null, Typeface.NORMAL);
                emptyViewImage.setVisibility(View.VISIBLE);
            }
        }
    }

    public void scrollToTop() {
        layoutManager.scrollToPositionWithOffset(0, 0);
    }

    protected FeedSet getFeedSet() {
        return activity.getFeedSet();
    }

	public void hasUpdated() {
        if (isAdded() && !getFeedSet().isMuted()) {
		    getLoaderManager().restartLoader(ITEMLIST_LOADER , null, this);
        }
	}

	@Override
	public Loader<Cursor> onCreateLoader(int arg0, Bundle arg1) {
        FeedSet fs = getFeedSet();
        if (fs == null) {
            com.newsblur.util.Log.e(this.getClass().getName(), "can't create fragment, no feedset ready");
            // this is probably happening in a finalisation cycle or during a crash, pop the activity stack
            try {
                getActivity().finish();
            } catch (Exception e) {
                ;
            }
            return null;
        } else if (fs.isMuted()) {
            updateLoadingMessage();
            return null;
        } else {
            return FeedUtils.dbHelper.getActiveStoriesLoader(getFeedSet());
        }
    }

    @Override
	public synchronized void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if (stopLoading) return;
		if (cursor != null) {
            if (! NBSyncService.isFeedSetReady(getFeedSet())) {
                // the DB hasn't caught up yet from the last story list; don't display stale stories.
                com.newsblur.util.Log.i(this.getClass().getName(), "stale load");
                setShowNone(true);
                setLoading(true);
                triggerRefresh(1, null);
            } else {
                cursorSeenYet = true;
                com.newsblur.util.Log.d(this.getClass().getName(), "loaded cursor with count: " + cursor.getCount());
                if (cursor.getCount() < 1) {
                    triggerRefresh(1, 0);
                }
                setShowNone(false);
            }
            updateAdapter(cursor);
		}
        updateLoadingMessage();
	}

    protected void updateAdapter(Cursor cursor) {
        adapter.swapCursor(cursor);
        adapter.updateFeedSet(getFeedSet());
        adapter.notifyDataSetChanged();
        if (cursor.getCount() > 0) {
            emptyView.setVisibility(View.INVISIBLE);
        } else {
            emptyView.setVisibility(View.VISIBLE);
        }

        // though we have stories, we might not yet have as many as we want
        ensureSufficientStories();
    }

    protected void setShowNone(boolean showNone) {
        adapter.setShowNone(showNone);
    }

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
        ;
	}

    public void updateStyle() {
        StoryListStyle listStyle = PrefsUtils.getStoryListStyle(getActivity(), getFeedSet());
        calcColumnCount(listStyle);
        calcGridSpacing(listStyle);
        layoutManager.setSpanCount(columnCount);
        adapter.setStyle(listStyle);
        adapter.notifyDataSetChanged();
    }

    public void setTextSize(Float size) {
        if (adapter != null) {
            adapter.setTextSize(size);
            adapter.notifyDataSetChanged();
        }
    }

    private void calcColumnCount(StoryListStyle listStyle) {
        if (listStyle == StoryListStyle.LIST) {
            columnCount = 1;
        } else {
            columnCount = 3;
        }
    }

    private void calcGridSpacing(StoryListStyle listStyle) {
        if (listStyle == StoryListStyle.LIST) {
            gridSpacingPx = 0;
        } else {
            gridSpacingPx = UIUtils.dp2px(getActivity(), GRID_SPACING_DP);
        }
    }

    private void onScrolled(RecyclerView recyclerView, int dx, int dy) {
        // the framework likes to trigger this on init before we even known counts, so disregard those
        if (!cursorSeenYet) return;

        // don't bother checking on scroll up
        if (dy < 1) return;

        ensureSufficientStories();

        if (PrefsUtils.isMarkReadOnScroll(getActivity())) {
            // we want the top row of stories that is partially obscured. go back one from the first fully visible
            int markEnd = layoutManager.findFirstCompletelyVisibleItemPosition() - 1;
            if (markEnd > lastAutoMarkIndex) {
                lastAutoMarkIndex = markEnd;
                // iterate backwards through that row, marking read
                for (int i=0; i<columnCount; i++) {
                    int index = markEnd - i;
                    Story story = adapter.getStory(index);
                    if (story != null) {
                        FeedUtils.markStoryAsRead(story, getActivity());
                    }
                }
            }
        }
    }

    private void ensureSufficientStories() {
        int totalCount = layoutManager.getItemCount();
        int visibleCount = layoutManager.getChildCount();
        int lastVisible = layoutManager.findLastVisibleItemPosition();
        
        // load an extra page worth of stories past the viewport plus at least two rows to prime the height calc
        int desiredStoryCount = lastVisible + (visibleCount*2) + (columnCount*2);
        triggerRefresh(desiredStoryCount, totalCount);
        //com.newsblur.util.Log.d(this, String.format(" total:%d  bound:%d  last%d  desire:%d", totalCount, visibleCount, lastVisible, desiredStoryCount));
    }

}
