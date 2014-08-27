package com.newsblur.activity;

import android.app.ActionBar;
import android.content.Intent;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.app.DialogFragment;
import android.app.FragmentManager;
import android.support.v4.widget.SwipeRefreshLayout;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.Window;
import android.widget.AbsListView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.fragment.FolderListFragment;
import com.newsblur.fragment.LogoutDialogFragment;
import com.newsblur.service.BootReceiver;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public class Main extends NbActivity implements StateChangedListener, SwipeRefreshLayout.OnRefreshListener, AbsListView.OnScrollListener {

	private ActionBar actionBar;
	private FolderListFragment folderFeedList;
	private FragmentManager fragmentManager;
	private Menu menu;
    private TextView overlayStatusText;
    private boolean isLightTheme;
    private SwipeRefreshLayout swipeLayout;

    @Override
	public void onCreate(Bundle savedInstanceState) {

        PreferenceManager.setDefaultValues(this, R.layout.activity_settings, false);

        isLightTheme = PrefsUtils.isLightThemeSelected(this);

		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(savedInstanceState);

		setContentView(R.layout.activity_main);
		setupActionBar();

        swipeLayout = (SwipeRefreshLayout)findViewById(R.id.swipe_container);
        swipeLayout.setColorScheme(R.color.refresh_1, R.color.refresh_2, R.color.refresh_3, R.color.refresh_4);
        swipeLayout.setOnRefreshListener(this);

		fragmentManager = getFragmentManager();
		folderFeedList = (FolderListFragment) fragmentManager.findFragmentByTag("folderFeedListFragment");
		folderFeedList.setRetainInstance(true);

        this.overlayStatusText = (TextView) findViewById(R.id.main_sync_status);

        // make sure the interval sync is scheduled, since we are the root Activity
        BootReceiver.scheduleSyncService(this);
	}

    @Override
    protected void onResume() {
        super.onResume();
        updateStatusIndicators();
        // this view doesn't show stories, it is safe to perform cleanup
        NBSyncService.holdStories(false);
        triggerSync();

        if (PrefsUtils.isLightThemeSelected(this) != isLightTheme) {
            UIUtils.restartActivity(this);
        }
    }

	private void setupActionBar() {
		actionBar = getActionBar();
		actionBar.setNavigationMode(ActionBar.NAVIGATION_MODE_STANDARD);
	}
	
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getMenuInflater();
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
            NBSyncService.forceFeedsFolders();
			triggerSync();
			return true;
		} else if (item.getItemId() == R.id.menu_add_feed) {
			Intent intent = new Intent(this, SearchForFeeds.class);
			startActivityForResult(intent, 0);
			return true;
		} else if (item.getItemId() == R.id.menu_logout) {
			DialogFragment newFragment = new LogoutDialogFragment();
			newFragment.show(getFragmentManager(), "dialog");
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
			folderFeedList.hasUpdated();
		}
	}

    @Override
	public void handleUpdate() {
		folderFeedList.hasUpdated();
        updateStatusIndicators();
	}

    private void updateStatusIndicators() {
        if (NBSyncService.isFeedFolderSyncRunning()) {
            swipeLayout.setRefreshing(true);
            setRefreshEnabled(false);
        } else {
            swipeLayout.setRefreshing(false);
            setRefreshEnabled(true);
        }

        if (overlayStatusText != null) {
            String syncStatus = NBSyncService.getSyncStatusMessage();
            if (syncStatus != null)  {
                overlayStatusText.setText(syncStatus);
                overlayStatusText.setVisibility(View.VISIBLE);
            } else {
                overlayStatusText.setVisibility(View.GONE);
            }
        }
    }

    private void setRefreshEnabled(boolean enabled) {
        if (menu != null) {
            MenuItem item = menu.findItem(R.id.menu_refresh);
            if (item != null) {
                item.setEnabled(enabled);
            }
        }
    }

    @Override
    public void onRefresh() {
        NBSyncService.forceFeedsFolders();
        triggerSync();
    }

    @Override
    public void onScrollStateChanged(AbsListView absListView, int i) {
        // not required
    }

    @Override
    public void onScroll(AbsListView absListView, int i, int i2, int i3) {
        // TODO: this method is too expensive to be called each time the list moves by a pixel.
        boolean enable = false;

        if( absListView.getChildCount() > 0){
            // check if the first item of the list is visible
            boolean firstItemVisible = absListView.getFirstVisiblePosition() == 0;
            // check if the top of the first item is visible
            boolean topOfFirstItemVisible = absListView.getChildAt(0).getTop() == 0;
            // enabling or disabling the refresh layout
            enable = firstItemVisible && topOfFirstItemVisible;
        }

        if (swipeLayout != null) {
            swipeLayout.setEnabled(enable);
        }
    }
}
