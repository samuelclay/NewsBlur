package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentManager;

import com.actionbarsherlock.app.ActionBar;
import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.fragment.FolderListFragment;
import com.newsblur.fragment.LogoutDialogFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public class Main extends SherlockFragmentActivity implements StateChangedListener, SyncUpdateFragment.SyncUpdateFragmentInterface {

	private ActionBar actionBar;
	private FolderListFragment folderFeedList;
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
		folderFeedList = (FolderListFragment) fragmentManager.findFragmentByTag("folderFeedListFragment");
		folderFeedList.setRetainInstance(true);
		
		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncUpdateFragment.TAG).commit();
			triggerFullRefresh();
		}
	}

	
	private void triggerFullRefresh() {
		setSupportProgressBarIndeterminateVisibility(true);
		if (menu != null) {
			menu.findItem(R.id.menu_refresh).setEnabled(false);
		}
		
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_FOLDER_UPDATE);
		startService(intent);
	}
	
	private void triggerRecount() {
		setSupportProgressBarIndeterminateVisibility(true);
		if (menu != null) {
			menu.findItem(R.id.menu_refresh).setEnabled(false);
		}

		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_FOLDER_UPDATE_WITH_COUNT);
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
			triggerRecount();
			return true;
		case R.id.menu_add_feed:
			Intent intent = new Intent(this, SearchForFeeds.class);
			startActivityForResult(intent, 0);
			return true;	
		case R.id.menu_logout:
			DialogFragment newFragment = new LogoutDialogFragment();
			newFragment.show(getSupportFragmentManager(), "dialog");
		}
		return super.onOptionsItemSelected(item);
	}
	
	public void deleteFeed(long id, String foldername) {
		setSupportProgressBarIndeterminateVisibility(true);
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_DELETE_FEED);
		intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, id);
		startService(intent);
	}

	@Override
	public void changedState(int state) {
		folderFeedList.changeState(state);
	}
	
	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		if (resultCode == RESULT_OK) {
			folderFeedList.hasUpdated();
		}
	}

	@Override
	public void updateAfterSync() {
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