package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.app.FragmentManager;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.Window;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.fragment.DefaultFeedViewDialogFragment;
import com.newsblur.fragment.ItemListFragment;
import com.newsblur.fragment.ReadFilterDialogFragment;
import com.newsblur.fragment.StoryOrderDialogFragment;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.DefaultFeedViewChangedListener;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.ReadFilterChangedListener;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.StoryOrderChangedListener;
import com.newsblur.util.UIUtils;

public abstract class ItemsList extends NbActivity implements StoryOrderChangedListener, ReadFilterChangedListener, DefaultFeedViewChangedListener {

	private static final String STORY_ORDER = "storyOrder";
	private static final String READ_FILTER = "readFilter";
    private static final String DEFAULT_FEED_VIEW = "defaultFeedView";
    public static final String BUNDLE_FEED_IDS = "feedIds";

	protected ItemListFragment itemListFragment;
	protected FragmentManager fragmentManager;
    private TextView overlayStatusText;
	protected StateFilter intelState;

    private FeedSet fs;
	
	@Override
    protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        overridePendingTransition(R.anim.slide_in_from_right, R.anim.slide_out_to_left);

		intelState = PrefsUtils.getStateFilter(this);
        this.fs = createFeedSet();

        getWindow().setBackgroundDrawableResource(android.R.color.transparent);

		setContentView(R.layout.activity_itemslist);
		fragmentManager = getFragmentManager();

        this.overlayStatusText = (TextView) findViewById(R.id.itemlist_sync_status);

        if (PrefsUtils.isAutoOpenFirstUnread(this)) {
            if (FeedUtils.dbHelper.getUnreadCount(fs, intelState) > 0) {
                UIUtils.startReadingActivity(fs, Reading.FIND_FIRST_UNREAD, this, false);
            }
        }
	}

    protected abstract FeedSet createFeedSet();

    public FeedSet getFeedSet() {
        return this.fs;
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (NBSyncService.isHousekeepingRunning()) finish();
        updateStatusIndicators();
        // Reading activities almost certainly changed the read/unread state of some stories. Ensure
        // we reflect those changes promptly.
        itemListFragment.hasUpdated();
    }

    @Override
    protected void onPause() {
        super.onPause();
        NBSyncService.addRecountCandidates(fs);
    }

	public void markItemListAsRead() {
        if (itemListFragment != null) {
            // since v6.0 of Android, the ListView in the fragment likes to crash if the underlying
            // dataset changes rapidly as happens when marking-all-read and when the fragment is
            // stopping. do a manual hard-stop of the loaders in the fragment before we finish
            itemListFragment.stopLoader();
        }
        FeedUtils.markFeedsRead(fs, null, null, this);
        finish();
    }
	
	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		if (item.getItemId() == android.R.id.home) {
			finish();
			return true;
		} else if (item.getItemId() == R.id.menu_mark_all_as_read) {
			markItemListAsRead();
			return true;
		} else if (item.getItemId() == R.id.menu_story_order) {
            StoryOrder currentValue = getStoryOrder();
            StoryOrderDialogFragment storyOrder = StoryOrderDialogFragment.newInstance(currentValue);
            storyOrder.show(getFragmentManager(), STORY_ORDER);
            return true;
        } else if (item.getItemId() == R.id.menu_read_filter) {
            ReadFilter currentValue = getReadFilter();
            ReadFilterDialogFragment readFilter = ReadFilterDialogFragment.newInstance(currentValue);
            readFilter.show(getFragmentManager(), READ_FILTER);
            return true;
        } else if (item.getItemId() == R.id.menu_default_view) {
            DefaultFeedView currentValue = PrefsUtils.getDefaultFeedView(this, fs);
            DefaultFeedViewDialogFragment readFilter = DefaultFeedViewDialogFragment.newInstance(currentValue);
            readFilter.show(getFragmentManager(), DEFAULT_FEED_VIEW);
            return true;
        }
	
		return false;
	}
	
    // TODO: can all of these be replaced with PrefsUtils queries via FeedSet?
	public abstract StoryOrder getStoryOrder();
	
	protected abstract ReadFilter getReadFilter();

    @Override
	public void handleUpdate(int updateType) {
        if ((updateType & UPDATE_REBUILD) != 0) {
            finish();
        }
        if ((updateType & UPDATE_STATUS) != 0) {
            updateStatusIndicators();
        }
		if ((updateType & UPDATE_STORY) != 0) {
            if (itemListFragment != null) {
			    itemListFragment.hasUpdated();
            }
        }
    }

    private void updateStatusIndicators() {
        boolean isLoading = NBSyncService.isFeedSetSyncing(this.fs, this);
        if (itemListFragment != null) {
            itemListFragment.setLoading(isLoading);
        }

        if (overlayStatusText != null) {
            String syncStatus = NBSyncService.getSyncStatusMessage(this, true);
            if (syncStatus != null)  {
                overlayStatusText.setText(syncStatus);
                overlayStatusText.setVisibility(View.VISIBLE);
            } else {
                overlayStatusText.setVisibility(View.GONE);
            }
        }
    }

	@Override
    public void storyOrderChanged(StoryOrder newValue) {
        updateStoryOrderPreference(newValue);
        FeedUtils.clearReadingSession(); 
        itemListFragment.resetEmptyState();
        itemListFragment.hasUpdated();
        itemListFragment.scrollToTop();
    }
	
	public abstract void updateStoryOrderPreference(StoryOrder newValue);

    @Override
    public void readFilterChanged(ReadFilter newValue) {
        updateReadFilterPreference(newValue);
        FeedUtils.clearReadingSession(); 
        itemListFragment.resetEmptyState();
        itemListFragment.hasUpdated();
        itemListFragment.scrollToTop();
    }

    protected abstract void updateReadFilterPreference(ReadFilter newValue);

    @Override
    public void finish() {
        super.finish();
        /*
         * Animate out the list by sliding it to the right and the Main activity in from
         * the left.  Do this when going back to Main as a subtle hint to the swipe gesture,
         * to make the gesture feel more natural, and to override the really ugly transition
         * used in some of the newer platforms.
         */
        overridePendingTransition(R.anim.slide_in_from_left, R.anim.slide_out_to_right);
    }
}
