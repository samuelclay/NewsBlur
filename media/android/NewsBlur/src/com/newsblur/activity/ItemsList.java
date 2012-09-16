package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.util.Log;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.fragment.FeedIntelligenceSelectorFragment;
import com.newsblur.fragment.ItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public abstract class ItemsList extends SherlockFragmentActivity implements SyncUpdateFragment.SyncUpdateFragmentInterface, StateChangedListener {

	public static final String EXTRA_STATE = "currentIntelligenceState";
	public static final String EXTRA_BLURBLOG_USERNAME = "blurblogName";
	public static final String EXTRA_BLURBLOG_USERID = "blurblogId";
	public static final String EXTRA_BLURBLOG_USER_ICON = "userIcon";
	public static final String RESULT_EXTRA_READ_STORIES = "storiesToMarkAsRead";

	protected ItemListFragment itemListFragment;
	protected FragmentManager fragmentManager;
	protected SyncUpdateFragment syncFragment;
	private FeedIntelligenceSelectorFragment intelligenceSelectorFragment;
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

		currentState = getIntent().getIntExtra(EXTRA_STATE, 0);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);

		intelligenceSelectorFragment = (FeedIntelligenceSelectorFragment) fragmentManager.findFragmentByTag(FeedIntelligenceSelectorFragment.FRAGMENT_TAG);
		intelligenceSelectorFragment.setState(currentState);
	}


	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		Log.d(TAG, "Returned okay.");
		if (resultCode == RESULT_OK) {
			itemListFragment.hasUpdated();
		}
	}

	public abstract void triggerRefresh();
	public abstract void triggerRefresh(int page);

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
			case android.R.id.home:
				finish();
				return true;
	
			case R.id.menu_mark_all_as_read:
				markItemListAsRead();
				return true;
		}
	
		return false;
	}
	
	public abstract void markItemListAsRead();
	

	@Override
	public void updateAfterSync() {
		Log.d(TAG , "Redrawing UI");
		if (itemListFragment != null) {
			itemListFragment.hasUpdated();
		} else {
			Log.e(TAG, "Error updating list as it doesn't exist.");
		}
		setSupportProgressBarIndeterminateVisibility(false);
	}

	@Override
	public void updateSyncStatus(boolean syncRunning) {
		if (syncRunning) {
			setSupportProgressBarIndeterminateVisibility(true);
		}
	}

	@Override
	public void changedState(int state) {
		Log.d(TAG, "Changed state.");
		itemListFragment.changeState(state);
	}



}