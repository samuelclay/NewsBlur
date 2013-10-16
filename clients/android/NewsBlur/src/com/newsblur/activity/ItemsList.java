package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.util.Log;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.fragment.ItemListFragment;
import com.newsblur.fragment.ReadFilterDialogFragment;
import com.newsblur.fragment.StoryOrderDialogFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.ReadFilterChangedListener;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.StoryOrderChangedListener;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public abstract class ItemsList extends NbFragmentActivity implements SyncUpdateFragment.SyncUpdateFragmentInterface, StateChangedListener, StoryOrderChangedListener, ReadFilterChangedListener {

	public static final String EXTRA_STATE = "currentIntelligenceState";
	public static final String EXTRA_BLURBLOG_USERNAME = "blurblogName";
	public static final String EXTRA_BLURBLOG_USERID = "blurblogId";
	public static final String EXTRA_BLURBLOG_USER_ICON = "userIcon";
	public static final String EXTRA_BLURBLOG_TITLE = "blurblogTitle";
	private static final String STORY_ORDER = "storyOrder";
	private static final String READ_FILTER = "readFilter";

	protected ItemListFragment itemListFragment;
	protected FragmentManager fragmentManager;
	protected SyncUpdateFragment syncFragment;
	protected int currentState;
	private Menu menu;
	
	protected boolean stopLoading = false;
	
	@Override
	protected void onCreate(Bundle bundle) {
		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(bundle);

		setContentView(R.layout.activity_itemslist);
		fragmentManager = getSupportFragmentManager();

        // our intel state is entirely determined by the state of the Main view
		currentState = getIntent().getIntExtra(EXTRA_STATE, 0);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);

	}

    protected void onResume() {
        super.onResume();
        // Reading activities almost certainly changed the read/unread state of some stories. Ensure
        // we reflect those changes promptly.
        itemListFragment.hasUpdated();
    }

	public abstract void triggerRefresh(int page);
	public abstract void markItemListAsRead();
	
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
            storyOrder.show(getSupportFragmentManager(), STORY_ORDER);
            return true;
        } else if (item.getItemId() == R.id.menu_read_filter) {
            ReadFilter currentValue = getReadFilter();
            ReadFilterDialogFragment readFilter = ReadFilterDialogFragment.newInstance(currentValue);
            readFilter.show(getSupportFragmentManager(), READ_FILTER);
            return true;
        }
	
		return false;
	}
	
	protected abstract StoryOrder getStoryOrder();
	
	protected abstract ReadFilter getReadFilter();
	
	@Override
	public void updateAfterSync() {
		if (itemListFragment != null) {
			itemListFragment.hasUpdated();
		} else {
			Log.e(this.getClass().getName(), "Error updating list as it doesn't exist.");
		}
		setSupportProgressBarIndeterminateVisibility(false);
	}

	@Override
	public void updatePartialSync() {
		if (itemListFragment != null) {
			itemListFragment.hasUpdated();
		} else {
			Log.e(this.getClass().getName(), "Error updating list as it doesn't exist.");
		}
	}

	@Override
	public void updateSyncStatus(boolean syncRunning) {
		if (syncRunning) {
			setSupportProgressBarIndeterminateVisibility(true);
		}
	}
	
	@Override
    public void setNothingMoreToUpdate() {
        stopLoading = true;
    }

	@Override
	public void changedState(int state) {
		itemListFragment.changeState(state);
	}
	
	@Override
    public void storyOrderChanged(StoryOrder newValue) {
        updateStoryOrderPreference(newValue);
        itemListFragment.setStoryOrder(newValue);
        stopLoading = false;
        triggerRefresh(1);
    }
	
	public abstract void updateStoryOrderPreference(StoryOrder newValue);

    @Override
    public void readFilterChanged(ReadFilter newValue) {
        updateReadFilterPreference(newValue);
        stopLoading = false;
        triggerRefresh(1);
    }

    protected abstract void updateReadFilterPreference(ReadFilter newValue);
}
