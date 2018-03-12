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
import com.newsblur.database.StoryItemsAdapter;
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

public class ItemListFragment extends ItemSetFragment implements OnScrollListener, OnCreateContextMenuListener, OnItemClickListener {

	@Bind(R.id.itemlistfragment_list) ListView itemList;
	protected StoryItemsAdapter adapter;
    
    // loading indicator for when stories are present but stale (at top of list)
    protected ProgressThrobber headerProgressView;
    // loading indicator for when stories are present and fresh (at bottom of list)
    protected ProgressThrobber footerProgressView;
    // loading indicator for when no stories are loaded yet (instead of list)
    @Bind(R.id.empty_view_loading_throb) ProgressThrobber emptyProgressView;

    private View fleuronFooter;

    // we have to de-dupe auto-mark-read-on-scroll actions
    private String lastAutoMarkHash = null;

    // row index of the last story to get a LTR gesture or -1 if none
    private int gestureLeftToRightFlag = -1;
    // row index of the last story to get a RTL gesture or -1 if none
    private int gestureRightToLeftFlag = -1;
    // flag indicating a gesture just occurred so we can ignore spurious story taps right after
    private boolean gestureDebounce = false;

	public static ItemListFragment newInstance() {
		ItemListFragment fragment = new ItemListFragment();
		Bundle arguments = new Bundle();
		fragment.setArguments(arguments);
		return fragment;
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

        View footerView = inflater.inflate(R.layout.row_loading_throbber, null);
        footerProgressView = (ProgressThrobber) footerView.findViewById(R.id.itemlist_loading_throb);
        footerProgressView.setEnabled(!isDisableAnimations);
        footerProgressView.setColors(UIUtils.getColor(getActivity(), R.color.refresh_1),
                                     UIUtils.getColor(getActivity(), R.color.refresh_2),
                                     UIUtils.getColor(getActivity(), R.color.refresh_3),
                                     UIUtils.getColor(getActivity(), R.color.refresh_4));
        itemList.addFooterView(footerView, null, false);

        fleuronFooter = inflater.inflate(R.layout.row_fleuron, null);
        fleuronFooter.setVisibility(View.GONE);
        itemList.addFooterView(fleuronFooter, null, false);

		itemList.setEmptyView(v.findViewById(R.id.empty_view));
        setupGestureDetector(itemList);
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
    protected boolean isAdapterValid() {
        if (adapter == null) return true;
        if (adapter.isStale()) return false;
        return true;
    }

    /**
     * Turns on/off the loading indicator. Note that the text component of the
     * loading indicator requires a cursor and is handled below.
     */
    @Override
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

    protected void updateLoadingMessage(boolean isMuted, boolean isLoading) {
        if (itemList == null) {
            Log.w(this.getClass().getName(), "ItemListFragment does not have the expected ListView.");
            return;
        }
        View emptyView = itemList.getEmptyView();
        TextView textView = (TextView) emptyView.findViewById(R.id.empty_view_text);
        ImageView imageView = (ImageView) emptyView.findViewById(R.id.empty_view_image);

        if (isMuted) {
            textView.setText(R.string.empty_list_view_muted_feed);
            textView.setTypeface(null, Typeface.NORMAL);
            imageView.setVisibility(View.VISIBLE);
        } else {
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
    }

    @Override
    public void scrollToTop() {
        if (itemList == null) {
            com.newsblur.util.Log.w(this, "ItemListFragment does not have the expected ListView.");
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

        if ((storiesSeen > 0) &&
            (firstVisible > 0) && 
            PrefsUtils.isMarkReadOnScroll(getActivity())) {
            int topVisible = firstVisible - 1;
            Story story = adapter.getStory(topVisible);
            if (!story.storyHash.equals(lastAutoMarkHash)) {
                lastAutoMarkHash = story.storyHash;
                FeedUtils.markStoryAsRead(story, getActivity());
            }
        }
	}

	@Override
	public void onScrollStateChanged(AbsListView view, int scrollState) { }

    @Override
    protected void createAdapter(Cursor cursor) {
        if (adapter == null) {
            FeedSet fs = getFeedSet();
            if (fs.isGlobalShared())  adapter = new StoryItemsAdapter(getActivity(), cursor, false, true, false);
            if (fs.isAllSocial())     adapter = new StoryItemsAdapter(getActivity(), cursor, false, false, false);
            if (fs.isAllNormal())     adapter = new StoryItemsAdapter(getActivity(), cursor, false, false, false);
            if (fs.isInfrequent())    adapter = new StoryItemsAdapter(getActivity(), cursor, false, false, false);
            if (fs.isSingleSocial())  adapter = new StoryItemsAdapter(getActivity(), cursor, false, false, false);
            if (fs.isFolder())        adapter = new StoryItemsAdapter(getActivity(), cursor, fs.isFilterSaved(), fs.isFilterSaved(), false);
            if (fs.isSingleNormal())  adapter = new StoryItemsAdapter(getActivity(), cursor, fs.isFilterSaved(), fs.isFilterSaved(), true);
            if (fs.isAllRead())       adapter = new StoryItemsAdapter(getActivity(), cursor, false, true, false);
            if (fs.isAllSaved())      adapter = new StoryItemsAdapter(getActivity(), cursor, true, true, false);
            if (fs.isSingleSavedTag()) adapter = new StoryItemsAdapter(getActivity(), cursor, true, true, false);

            itemList.setAdapter(adapter);
        }
    }

    @Override
    protected void updateAdapter(Cursor cursor) {
        adapter.swapCursor(cursor);
    }

    @Override
    protected void setShowNone(boolean showNone) {
        adapter.setShowNone(showNone);
    }

    @Override
    public void onCreateContextMenu(ContextMenu menu, View v, ContextMenuInfo menuInfo) {
        // context menu like to get accidentally triggered by the ListView event handler right after
        // we detect a gesure.  if so, let the gesture happen rather than popping up the menu
        if ((gestureLeftToRightFlag > -1) || (gestureRightToLeftFlag > -1)) return;

        MenuInflater inflater = getActivity().getMenuInflater();

        int truePosition = ((AdapterView.AdapterContextMenuInfo) menuInfo).position - 1;
        Story story = adapter.getStory(truePosition);
        if (story == null) return;

        UIUtils.inflateStoryContextMenu(menu, inflater, getActivity(), getFeedSet(), story);
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
}
