package com.newsblur.fragment;

import java.util.ArrayList;
import java.util.List;

import android.app.Activity;
import android.database.Cursor;
import android.app.Fragment;
import android.content.Loader;
import android.util.Log;
import android.view.ContextMenu;
import android.view.GestureDetector;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnTouchListener;
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
import com.newsblur.network.APIManager;
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

        Story story = adapter.getStory(((AdapterView.AdapterContextMenuInfo) (menuInfo)).position);
        if (story.read) {
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
        Story story = adapter.getStory(menuInfo.position);
        Activity activity = getActivity();

        switch (item.getItemId()) {
        case R.id.menu_mark_story_as_read:
            FeedUtils.markStoryAsRead(story, activity);
            hasUpdated();
            return true;

        case R.id.menu_mark_story_as_unread:
            FeedUtils.markStoryUnread(story, activity);
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
            FeedUtils.markStoriesAsRead(storiesToMarkAsRead, activity);
            hasUpdated();
            return true;

        case R.id.menu_shared:
            FeedUtils.shareStory(story, activity);
            return true;

        case R.id.menu_save_story:
            FeedUtils.saveStory(story, activity, new APIManager(activity), null);
            return true;

        case R.id.menu_unsave_story:
            FeedUtils.unsaveStory(story, activity, new APIManager(activity), null);
            return true;

        default:
            return super.onContextItemSelected(item);
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
