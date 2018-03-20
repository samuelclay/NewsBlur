package com.newsblur.fragment;

import android.app.Activity;
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

public class ItemListFragment extends ItemSetFragment {

    /*


    // row index of the last story to get a LTR gesture or -1 if none
    private int gestureLeftToRightFlag = -1;
    // row index of the last story to get a RTL gesture or -1 if none
    private int gestureRightToLeftFlag = -1;
    // flag indicating a gesture just occurred so we can ignore spurious story taps right after
    private boolean gestureDebounce = false;

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        setupGestureDetector(itemList);
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
            FeedUtils.markRead(activity, getFeedSet(), story.timestamp, null, R.array.mark_older_read_options, false);
            return true;

        case R.id.menu_mark_newer_stories_as_read:
            FeedUtils.markRead(activity, getFeedSet(), null, story.timestamp, R.array.mark_newer_read_options, false);
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

        case R.id.menu_intel:
            if (story.feedId.equals("0")) return true; // cannot train on feedless stories
            StoryIntelTrainerFragment intelFrag = StoryIntelTrainerFragment.newInstance(story, getFeedSet());
            intelFrag.show(getFragmentManager(), StoryIntelTrainerFragment.class.getName());
            return true;

        default:
            return super.onContextItemSelected(item);
        }
    }

	@Override
	public synchronized void onItemClick(AdapterView<?> parent, View view, int position, long id) {
        // clicks like to get accidentally triggered by the ListView event handler right after we detect
        // a gesture. if so, let the gesture happen rather than popping up the menu
        if (gestureDebounce){
            gestureDebounce = false;
            return;
        }
        if ((gestureLeftToRightFlag > -1) || (gestureRightToLeftFlag > -1)) return;

        int truePosition = position - 1;
        Story story = adapter.getStory(truePosition);
        if (story == null) return; // can happen on shrinking lists
        if (getActivity().isFinishing()) return;
        UIUtils.startReadingActivity(getFeedSet(), story.storyHash, getActivity());
    }

    @Override
    public void setTextSize(Float size) {
        if (adapter != null) {
            adapter.setTextSize(size);
            adapter.notifyDataSetChanged();
        }
    }

    protected void setupGestureDetector(View v) {
        final GestureDetector gestureDetector = new GestureDetector(getActivity(), new ItemListGestureDetector());
        v.setOnTouchListener(new OnTouchListener() {
            public boolean onTouch(View v, MotionEvent event) {
                boolean result =  gestureDetector.onTouchEvent(event);
                if (event.getActionMasked() == MotionEvent.ACTION_UP) {
                    ItemListFragment.this.flushGesture();
                }
                return result;
            }
        });
    }

    protected void gestureLeftToRight(float x, float y) {
        int index = itemList.pointToPosition((int) x, (int) y);
        gestureLeftToRightFlag = index;
    }

    protected void gestureRightToLeft(float x, float y) {
        int index = itemList.pointToPosition((int) x, (int) y);
        gestureRightToLeftFlag = index;
    }

    // the above gesture* methods will trigger more than once while being performed. it is not until
    // the up-event that we look to see if any happened, and if so, take action and flush.
    protected void flushGesture() {
        int index = -1;
        GestureAction action = GestureAction.GEST_ACTION_NONE;
        if (gestureLeftToRightFlag > -1) {
            index = gestureLeftToRightFlag;
            action = PrefsUtils.getLeftToRightGestureAction(getActivity());
            gestureLeftToRightFlag = -1;
            gestureDebounce = true;
        }
        if (gestureRightToLeftFlag > -1) {
            index = gestureRightToLeftFlag;
            action = PrefsUtils.getRightToLeftGestureAction(getActivity());
            gestureRightToLeftFlag = -1;
            gestureDebounce = true;
        }
        if (index <= -1) return;
        Story story = adapter.getStory(index-1);
        if (story == null) return;
        switch (action) {
            case GEST_ACTION_MARKREAD:
                FeedUtils.markStoryAsRead(story, getActivity());;
                break;
            case GEST_ACTION_MARKUNREAD:
                FeedUtils.markStoryUnread(story, getActivity());;
                break;
            case GEST_ACTION_SAVE:
                FeedUtils.setStorySaved(story, true, getActivity());;
                break;
            case GEST_ACTION_UNSAVE:
                FeedUtils.setStorySaved(story, false, getActivity());;
                break;
            case GEST_ACTION_NONE:
            default:
        }
    }

    class ItemListGestureDetector extends GestureDetector.SimpleOnGestureListener {
        @Override
        public boolean onScroll(MotionEvent e1, MotionEvent e2, float distanceX, float distanceY) {
            if ((e1.getX() < 75f) &&                  // the gesture should start from the left bezel and
                ((e2.getX()-e1.getX()) > 90f) &&      // move horizontally to the right and
                (Math.abs(e1.getY()-e2.getY()) < 40f) // have minimal vertical travel, so we don't capture scrolling gestures
                ) {
                ItemListFragment.this.getActivity().finish();
                return true;
            }
            if ((e1.getX() > 75f) &&                  // the gesture should not start from the left bezel and
                ((e2.getX()-e1.getX()) > 120f) &&     // move horizontally to the right and
                (Math.abs(e1.getY()-e2.getY()) < 40f) // have minimal vertical travel, so we don't capture scrolling gestures
                ) {
                ItemListFragment.this.gestureLeftToRight(e1.getX(), e1.getY());
                return true;
            }
            if ((e1.getX() > 75f) &&                  // the gesture should not start from the left bezel and
                ((e1.getX()-e2.getX()) > 120f) &&     // move horizontally to the left and
                (Math.abs(e1.getY()-e2.getY()) < 40f) // have minimal vertical travel, so we don't capture scrolling gestures
                ) {
                ItemListFragment.this.gestureRightToLeft(e1.getX(), e1.getY());
                return true;
            }
            return false;
        }
    }
    */
}
