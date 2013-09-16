package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentManager;
import android.util.Log;

import com.actionbarsherlock.app.ActionBar;
import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.fragment.FolderListFragment;
import com.newsblur.fragment.LogoutDialogFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;
import com.newsblur.util.PrefsUtils;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public class Main extends NbFragmentActivity implements StateChangedListener, SyncUpdateFragment.SyncUpdateFragmentInterface {

	private ActionBar actionBar;
	private FolderListFragment folderFeedList;
	private FragmentManager fragmentManager;
	private SyncUpdateFragment syncFragment;
	private static final String TAG = "MainActivity";
	private Menu menu;

	@Override
	public void onCreate(Bundle savedInstanceState) {

        PrefsUtils.checkForUpgrade(this);
        PreferenceManager.setDefaultValues(this, R.layout.activity_settings, false);

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
            // for our first sync, don't just trigger a heavyweight refresh, do it in two steps
            // so the UI appears more quickly (per the docs at newsblur.com/api)
			triggerFirstSync();
		}
	}

    @Override
    protected void onResume() {
        super.onResume();
        if (PrefsUtils.isTimeToAutoSync(this)) {
            triggerRefresh();
        }
    }

    /**
     * Triggers an initial two-phase sync, so the UI can display quickly using /reader/feeds and
     * then call /reader/refresh_feeds to get updated counts.
     */
	private void triggerFirstSync() {
        PrefsUtils.updateLastSyncTime(this);
		setSupportProgressBarIndeterminateVisibility(true);
		if (menu != null) {
			menu.findItem(R.id.menu_refresh).setEnabled(false);
		}
		
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.FOLDER_UPDATE_TWO_STEP);
		startService(intent);
	}
	
	/**
     * Triggers a full, manually requested refresh of feed/folder data and counts.
     */
    private void triggerRefresh() {
        PrefsUtils.updateLastSyncTime(this);
		setSupportProgressBarIndeterminateVisibility(true);
		if (menu != null) {
			menu.findItem(R.id.menu_refresh).setEnabled(false);
		}

		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.FOLDER_UPDATE_WITH_COUNT);
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
		if (item.getItemId() == R.id.menu_profile) {
			Intent profileIntent = new Intent(this, Profile.class);
			startActivity(profileIntent);
			return true;
		} else if (item.getItemId() == R.id.menu_refresh) {
			triggerRefresh();
			return true;
		} else if (item.getItemId() == R.id.menu_add_feed) {
			Intent intent = new Intent(this, SearchForFeeds.class);
			startActivityForResult(intent, 0);
			return true;
		} else if (item.getItemId() == R.id.menu_logout) {
			DialogFragment newFragment = new LogoutDialogFragment();
			newFragment.show(getSupportFragmentManager(), "dialog");
		} else if (item.getItemId() == R.id.menu_settings) {
            Intent settingsIntent = new Intent(this, Settings.class);
            startActivity(settingsIntent);
            return true;
        }
		return super.onOptionsItemSelected(item);
	}
	
	@Override
	public void changedState(int state) {
		folderFeedList.changeState(state);
	}
	
	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		if (resultCode == RESULT_OK) {
			Log.d(this.getClass().getName(), "onActivityResult:RESULT_OK" );
			folderFeedList.hasUpdated();
		}
	}

	/**
     * Called after the sync service completely finishes a task.
     */
    @Override
	public void updateAfterSync() {
		folderFeedList.hasUpdated();
		setSupportProgressBarIndeterminateVisibility(false);
		menu.findItem(R.id.menu_refresh).setEnabled(true);
	}

    /**
     * Called when the sync service has made enough progress to update the UI but not
     * enough to stop the progress indicator.
     */
    @Override
    public void updatePartialSync() {
        folderFeedList.hasUpdated();
    }
	
	@Override
	public void updateSyncStatus(boolean syncRunning) {
        // TODO: the progress bar is activated manually elsewhere in this activity. this
        //       interface method may be redundant.
		if (syncRunning) {
			setSupportProgressBarIndeterminateVisibility(true);
			if (menu != null) {
				menu.findItem(R.id.menu_refresh).setEnabled(true);
			}
		}
	}

	@Override
	public void setNothingMoreToUpdate() { }

}
