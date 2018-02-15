package com.newsblur.fragment;

import android.app.Activity;
import android.database.Cursor;
import android.graphics.Typeface;
import android.os.Bundle;
import android.support.v7.widget.GridLayoutManager;
import android.support.v7.widget.RecyclerView;
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
import com.newsblur.database.StoryViewAdapter;
import com.newsblur.domain.Story;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.GestureAction;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.UIUtils;
import com.newsblur.util.ViewUtils;
import com.newsblur.view.ProgressThrobber;

public class ItemGridFragment extends ItemSetFragment {

    private final static int GRID_COLUMN_COUNT = 2;

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

	public static ItemGridFragment newInstance() {
		ItemGridFragment fragment = new ItemGridFragment();
		Bundle arguments = new Bundle();
		fragment.setArguments(arguments);
		return fragment;
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

        layoutManager = new GridLayoutManager(getActivity(), GRID_COLUMN_COUNT);
        itemGrid.setLayoutManager(layoutManager);

        adapter = new StoryViewAdapter(getActivity(), getFeedSet());
        adapter.addFooterView(footerView);
        adapter.addFooterView(fleuronFooter);
        itemGrid.setAdapter(adapter); 

        // the layout manager needs to know that the footer rows span all the way across
        layoutManager.setSpanSizeLookup(new GridLayoutManager.SpanSizeLookup() {
            @Override
            public int getSpanSize(int position) {
                switch (adapter.getItemViewType(position)) {
                    case StoryViewAdapter.VIEW_TYPE_STORY:
                        return 1;
                    case StoryViewAdapter.VIEW_TYPE_FOOTER:
                        return GRID_COLUMN_COUNT;
                    default:
                        return 1;
                }
            }
        });

        itemGrid.setItemViewCacheSize(20);

        itemGrid.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrolled(RecyclerView recyclerView, int dx, int dy) {
                ItemGridFragment.this.onScrolled(recyclerView, dx, dy);
            }
        });

		return v;
	}

    @Override
    protected boolean isAdapterValid() {
        return (adapter.isCursorValid());
    }

    /**
     * Turns on/off the loading indicator. Note that the text component of the
     * loading indicator requires a cursor and is handled below.
     */
    @Override
    public void setLoading(boolean isLoading) {
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
            if (cursorSeenYet && NBSyncService.isFeedSetExhausted(getFeedSet())) {
                fleuronFooter.setVisibility(View.VISIBLE);
            }
        }
    }

    protected void updateLoadingMessage(boolean isMuted, boolean isLoading) {
        if (isMuted) {
            emptyViewText.setText(R.string.empty_list_view_muted_feed);
            emptyViewText.setTypeface(null, Typeface.NORMAL);
            emptyViewImage.setVisibility(View.VISIBLE);
        } else {
            if (isLoading || (!cursorSeenYet)) {
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

    private void onScrolled(RecyclerView recyclerView, int dx, int dy) {
        // the framework likes to trigger this on init before we even known counts, so disregard those
        if (!cursorSeenYet) return;

        int totalCount = layoutManager.getItemCount();
        int visibleCount = layoutManager.getChildCount();
        int lastVisible = layoutManager.findLastVisibleItemPosition();
        //com.newsblur.util.Log.d(this, String.format("SCROLL  total:%d  bound:%d  last%d", totalCount, visibleCount, lastVisible));
        
        // load an extra page or two worth of stories past the viewport
        int desiredStoryCount = lastVisible + (visibleCount*2) + 1;
        triggerRefresh(desiredStoryCount, totalCount);

        // TODO: mark on scroll?
    }

    @Override
    public void scrollToTop() {
        layoutManager.scrollToPositionWithOffset(0, 0);
    }

    @Override
    protected void createAdapter(Cursor cursor) {
        // this fragment is capable of creating an adapter without a cursor, so just update
        updateAdapter(cursor);
    }

    @Override
    protected void updateAdapter(Cursor cursor) {
        adapter.swapCursor(cursor);
        adapter.notifyDataSetChanged();
        if (cursor.getCount() > 0) {
            emptyView.setVisibility(View.INVISIBLE);
        } else {
            emptyView.setVisibility(View.VISIBLE);
        }
    }

    @Override
    protected void resetAdapter() {  
    }

    @Override
    protected void setShowNone(boolean showNone) {
        adapter.setShowNone(showNone);
    }

    @Override
    public void setTextSize(Float size) {
        if (adapter != null) {
            adapter.setTextSize(size);
            adapter.notifyDataSetChanged();
        }
    }


}
