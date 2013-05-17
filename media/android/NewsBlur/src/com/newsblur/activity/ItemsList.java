package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.util.Log;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.fragment.FeedIntelligenceSelectorFragment;
import com.newsblur.fragment.ItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public abstract class ItemsList extends NbFragmentActivity implements SyncUpdateFragment.SyncUpdateFragmentInterface, StateChangedListener {

	public static final String EXTRA_STATE = "currentIntelligenceState";
	public static final String EXTRA_BLURBLOG_USERNAME = "blurblogName";
	public static final String EXTRA_BLURBLOG_USERID = "blurblogId";
	public static final String EXTRA_BLURBLOG_USER_ICON = "userIcon";
	public static final String RESULT_EXTRA_READ_STORIES = "storiesToMarkAsRead";
	public static final String EXTRA_BLURBLOG_TITLE = "blurblogTitle";

	protected ItemListFragment itemListFragment;
	protected FragmentManager fragmentManager;
	protected SyncUpdateFragment syncFragment;
	protected String TAG = "ItemsList";
	protected int currentState;
	private Menu menu;

	@Override
	protected void onCreate(Bundle bundle) {
		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(bundle);
		setResult(RESULT_OK);

		setContentView(R.layout.activity_itemslist);
		fragmentManager = getSupportFragmentManager();

        // our intel state is entirely determined by the state of the Main view
		currentState = getIntent().getIntExtra(EXTRA_STATE, 0);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);

	}


	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		if (resultCode == RESULT_OK) {
			itemListFragment.hasUpdated();
		}
	}

	public abstract void triggerRefresh();
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
		}
	
		return false;
	}
	
	@Override
	public void updateAfterSync() {
		if (itemListFragment != null) {
			itemListFragment.hasUpdated();
		} else {
			Log.e(TAG, "Error updating list as it doesn't exist.");
		}
		setSupportProgressBarIndeterminateVisibility(false);
	}

	@Override
	public void updatePartialSync() {
		if (itemListFragment != null) {
			itemListFragment.hasUpdated();
		} else {
			Log.e(TAG, "Error updating list as it doesn't exist.");
		}
	}

	@Override
	public void updateSyncStatus(boolean syncRunning) {
		if (syncRunning) {
			setSupportProgressBarIndeterminateVisibility(true);
		}
	}

	@Override
	public void changedState(int state) {
		itemListFragment.changeState(state);
	}



}
