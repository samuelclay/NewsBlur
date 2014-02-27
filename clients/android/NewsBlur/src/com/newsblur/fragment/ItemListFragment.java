package com.newsblur.fragment;

import java.util.ArrayList;
import java.util.List;

import android.database.Cursor;
import android.support.v4.app.Fragment;
import android.support.v4.content.Loader;
import android.util.Log;
import android.view.ContextMenu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ContextMenu.ContextMenuInfo;
import android.view.View.OnCreateContextMenuListener;
import android.widget.AbsListView;
import android.widget.AbsListView.OnScrollListener;
import android.widget.AdapterView;
import android.widget.ListView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.database.StoryItemsAdapter;
import com.newsblur.domain.Story;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.StoryOrder;

public abstract class ItemListFragment extends Fragment implements OnScrollListener, OnCreateContextMenuListener {

    protected int currentPage = 0;
    protected boolean requestedPage;
	protected StoryItemsAdapter adapter;
    protected DefaultFeedView defaultFeedView;
    private boolean firstSyncDone = false;
	
	public abstract void hasUpdated();
	public abstract void changeState(final int state);
	public abstract void setStoryOrder(StoryOrder storyOrder);


    public void resetPagination() {
        this.currentPage = 0;
        // also re-enable the loading indicator, since this means the story list was reset
        firstSyncDone = false;
        setEmptyListView(R.string.empty_list_view_loading);
    }

    public void syncDone() {
        this.firstSyncDone = true;
    }

    private void setEmptyListView(int rid) {
        View v = this.getView();
        if (v == null) return; // we might have beat construction?

        ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
        if (itemList == null) {
            Log.w(this.getClass().getName(), "ItemListFragment does not have the expected ListView.");
            return;
        }

        TextView emptyView = (TextView) itemList.getEmptyView();
        emptyView.setText(rid);
    }

	@Override
	public synchronized void onScroll(AbsListView view, int firstVisible, int visibleCount, int totalCount) {
        // load an extra page worth of stories past the viewport
		if (totalCount != 0 && (firstVisible + (visibleCount*2)  >= totalCount) && !requestedPage) {
			currentPage += 1;
			requestedPage = true;
			triggerRefresh(currentPage);
		}
	}

	@Override
	public void onScrollStateChanged(AbsListView view, int scrollState) { }

	protected void triggerRefresh(int page) {
        ((ItemsList) getActivity()).triggerRefresh(page);
    }

    // all child classes need this callback, so implement it here
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
		if (cursor != null) {
            if (cursor.getCount() == 0) {
                currentPage += 1;
                requestedPage = true;
                triggerRefresh(currentPage);
            }
			adapter.swapCursor(cursor);

            // iff a sync has finished and a cursor load has finished, it is safe to remove the loading message
            if (this.firstSyncDone) {
                setEmptyListView(R.string.empty_list_view_no_stories);
            }
		}
	}

    public void setDefaultFeedView(DefaultFeedView value) {
        this.defaultFeedView = value;
    }

    @Override
    public void onCreateContextMenu(ContextMenu menu, View v, ContextMenuInfo menuInfo) {
        MenuInflater inflater = getActivity().getMenuInflater();
        inflater.inflate(R.menu.context_story, menu);
    }
    
    @Override
    public boolean onContextItemSelected(MenuItem item) {
        AdapterView.AdapterContextMenuInfo menuInfo = (AdapterView.AdapterContextMenuInfo)item.getMenuInfo();
        Story story = adapter.getStory(menuInfo.position);

        switch (item.getItemId()) {
        case R.id.menu_mark_story_as_read:
            FeedUtils.markStoryAsRead(story, getActivity());
            hasUpdated();
            return true;

        case R.id.menu_mark_story_as_unread:
            FeedUtils.markStoryUnread(story, getActivity());
            hasUpdated();
            return true;

        case R.id.menu_mark_previous_stories_as_read:
            List<Story> previousStories = adapter.getPreviousStories(menuInfo.position);
            List<Story> storiesToMarkAsRead = new ArrayList<Story>();
            for(Story s : previousStories) {
                if(! s.read) {
                    storiesToMarkAsRead.add(s);
                }
            }
            FeedUtils.markStoriesAsRead(storiesToMarkAsRead, getActivity());
            hasUpdated();
            return true;

        case R.id.menu_shared:
            FeedUtils.shareStory(story, getActivity());
            return true;

        default:
            return super.onContextItemSelected(item);
        }
    }
}
