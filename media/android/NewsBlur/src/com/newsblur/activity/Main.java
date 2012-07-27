package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.util.Log;

import com.actionbarsherlock.app.ActionBar;
import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.fragment.FolderFeedListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public class Main extends SherlockFragmentActivity implements StateChangedListener, SyncUpdateFragment.SyncUpdateFragmentInterface {

	private ActionBar actionBar;
	private FolderFeedListFragment folderFeedList;
	private FragmentManager fragmentManager;
	private SyncUpdateFragment syncFragment;
	private static final String TAG = "MainActivity";
	private Menu menu;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(savedInstanceState);

		setContentView(R.layout.activity_main);
		setupActionBar();

		fragmentManager = getSupportFragmentManager();
		folderFeedList = (FolderFeedListFragment) fragmentManager.findFragmentByTag("folderFeedListFragment");

		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncUpdateFragment.TAG).commit();
			triggerRefresh();
		}
	}

	private void triggerRefresh() {
		setSupportProgressBarIndeterminateVisibility(true);
		if (menu != null) {
			menu.findItem(R.id.menu_refresh).setEnabled(false);
		}

		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_REFRESH_COUNTS);
		startService(intent);
	}

	private void setupActionBar() {
		actionBar = getSupportActionBar();
		actionBar.setNavigationMode(ActionBar.NAVIGATION_MODE_STANDARD);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getSupportMenuInflater();
		inflater.inflate(R.menu.main, menu);
		this.menu = menu;
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		case R.id.menu_profile:
			Intent profileIntent = new Intent(this, Profile.class);
			startActivity(profileIntent);
			return true;
		case R.id.menu_refresh:
			triggerRefresh();
			return true;
		}
		return super.onOptionsItemSelected(item);
	}

	@Override
	public void changedState(int state) {
		Log.d(TAG, "State changed");
		folderFeedList.changeState(state);
	}

	@Override
	public void updateAfterSync() {
		Log.d(TAG, "Finished feed count refresh.");
		folderFeedList.hasUpdated();
		setSupportProgressBarIndeterminateVisibility(false);
		menu.findItem(R.id.menu_refresh).setEnabled(true);
	}

	@Override
	public void updateSyncStatus(boolean syncRunning) {
		if (syncRunning) {
			setSupportProgressBarIndeterminateVisibility(true);
			if (menu != null) {
				menu.findItem(R.id.menu_refresh).setEnabled(true);
			}
		}
	}			
}