package com.newsblur.activity;

import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.app.DialogFragment;
import android.app.FragmentManager;
import android.net.Uri;
import android.support.v4.widget.SwipeRefreshLayout;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.Window;
import android.widget.AbsListView;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.PopupMenu;
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;
import android.widget.TextView;

import butterknife.ButterKnife;
import butterknife.Bind;
import butterknife.OnClick;

import com.newsblur.R;
import com.newsblur.fragment.FeedIntelligenceSelectorFragment;
import com.newsblur.fragment.FolderListFragment;
import com.newsblur.fragment.LoginAsDialogFragment;
import com.newsblur.fragment.LogoutDialogFragment;
import com.newsblur.fragment.MarkAllReadDialogFragment.MarkAllReadDialogListener;
import com.newsblur.fragment.TextSizeDialogFragment;
import com.newsblur.service.BootReceiver;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StateFilter;
import com.newsblur.util.UIUtils;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public class Main extends NbActivity implements StateChangedListener, SwipeRefreshLayout.OnRefreshListener, AbsListView.OnScrollListener, PopupMenu.OnMenuItemClickListener, MarkAllReadDialogListener, OnSeekBarChangeListener {

	private FolderListFragment folderFeedList;
	private FragmentManager fragmentManager;
    private boolean isLightTheme;
    private SwipeRefreshLayout swipeLayout;
    private boolean wasSwipeEnabled = false;
    @Bind(R.id.main_sync_status) TextView overlayStatusText;
    @Bind(R.id.empty_view_image) ImageView emptyViewImage;
    @Bind(R.id.empty_view_text) TextView emptyViewText;
    @Bind(R.id.main_menu_button) Button menuButton;
    @Bind(R.id.main_user_image) ImageView userImage;
    @Bind(R.id.main_user_name) TextView userName;
    @Bind(R.id.main_unread_count_neut_text) TextView unreadCountNeutText;
    @Bind(R.id.main_unread_count_posi_text) TextView unreadCountPosiText;

    @Override
	public void onCreate(Bundle savedInstanceState) {
        PreferenceManager.setDefaultValues(this, R.xml.activity_settings, false);

        isLightTheme = PrefsUtils.isLightThemeSelected(this);

		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(savedInstanceState);
        getWindow().setBackgroundDrawableResource(android.R.color.transparent);

		setContentView(R.layout.activity_main);
        ButterKnife.bind(this);

		getActionBar().hide();

        // set the status bar to an generic loading message when the activity is first created so
        // that something is displayed while the service warms up
        overlayStatusText.setText(R.string.loading);
        overlayStatusText.setVisibility(View.VISIBLE);

        swipeLayout = (SwipeRefreshLayout)findViewById(R.id.swipe_container);
        swipeLayout.setColorScheme(R.color.refresh_1, R.color.refresh_2, R.color.refresh_3, R.color.refresh_4);
        swipeLayout.setOnRefreshListener(this);

		fragmentManager = getFragmentManager();
		folderFeedList = (FolderListFragment) fragmentManager.findFragmentByTag("folderFeedListFragment");
		folderFeedList.setRetainInstance(true);
        ((FeedIntelligenceSelectorFragment) fragmentManager.findFragmentByTag("feedIntelligenceSelector")).setState(folderFeedList.currentState);

        // make sure the interval sync is scheduled, since we are the root Activity
        BootReceiver.scheduleSyncService(this);

        Bitmap userPicture = PrefsUtils.getUserImage(this);
        if (userPicture != null) {
            userPicture = UIUtils.clipAndRound(userPicture, 5, false);
            userImage.setImageBitmap(userPicture);
        }
        userName.setText(PrefsUtils.getUserDetails(this).username);
	}

    @Override
    protected void onResume() {
        super.onResume();

        // immediately clear the story session to prevent bleed-over into the next
        FeedUtils.clearStorySession();
        // also queue a clear right before the feedset switches, so no in-flight stoires bleed
        NBSyncService.resetReadingSession();

        NBSyncService.flushRecounts();

        updateStatusIndicators();
        folderFeedList.pushUnreadCounts();
        folderFeedList.checkOpenFolderPreferences();
        triggerSync();

        if (PrefsUtils.isLightThemeSelected(this) != isLightTheme) {
            UIUtils.restartActivity(this);
        }
    }

	@Override
	public void changedState(StateFilter state) {
		folderFeedList.changeState(state);
	}
	
    @Override
	public void handleUpdate(int updateType) {
        if ((updateType & UPDATE_REBUILD) != 0) {
            folderFeedList.reset();
        }
        if ((updateType & UPDATE_DB_READY) != 0) {
            try {
                folderFeedList.startLoaders();
            } catch (IllegalStateException ex) {
                ; // this might be called multiple times, and startLoaders is *not* idempotent
            }
        }
        if ((updateType & UPDATE_STATUS) != 0) {
            updateStatusIndicators();
        }
		if ((updateType & UPDATE_METADATA) != 0) {
            folderFeedList.hasUpdated();
        }
	}

    public void updateUnreadCounts(int neutCount, int posiCount) {
        unreadCountNeutText.setText(Integer.toString(neutCount));
        unreadCountPosiText.setText(Integer.toString(posiCount));

        if ((neutCount+posiCount) <= 0) {
            if (NBSyncService.isFeedCountSyncRunning() || (!folderFeedList.firstCursorSeenYet)) {
                emptyViewImage.setVisibility(View.INVISIBLE);
                emptyViewText.setVisibility(View.INVISIBLE);
            } else {
                emptyViewImage.setVisibility(View.VISIBLE);
                if (folderFeedList.currentState == StateFilter.BEST) {
                    emptyViewText.setText(R.string.empty_list_view_no_focus_stories);
                } else {
                    emptyViewText.setText(R.string.empty_list_view_no_unread_stories);
                }
                emptyViewText.setVisibility(View.VISIBLE);
            }
        } else {
            emptyViewImage.setVisibility(View.INVISIBLE);
            emptyViewText.setVisibility(View.INVISIBLE);
        }
    }

    private void updateStatusIndicators() {
        if (NBSyncService.isFeedFolderSyncRunning()) {
            swipeLayout.setRefreshing(true);
        } else {
            swipeLayout.setRefreshing(false);
        }

        if (overlayStatusText != null) {
            String syncStatus = NBSyncService.getSyncStatusMessage(this, false);
            if (syncStatus != null)  {
                if (AppConstants.VERBOSE_LOG) {
                    syncStatus = syncStatus + UIUtils.getMemoryUsageDebug(this);
                }
                overlayStatusText.setText(syncStatus);
                overlayStatusText.setVisibility(View.VISIBLE);
            } else {
                overlayStatusText.setVisibility(View.GONE);
            }
        }
    }

    @Override
    public void onRefresh() {
        NBSyncService.forceFeedsFolders();
        triggerSync();
    }

    @OnClick(R.id.main_menu_button) void onClickMenuButton() {
        PopupMenu pm = new PopupMenu(this, menuButton);
        Menu menu = pm.getMenu();
        pm.getMenuInflater().inflate(R.menu.main, menu);

        MenuItem loginAsItem = menu.findItem(R.id.menu_loginas);
        if (NBSyncService.isStaff == Boolean.TRUE) {
            loginAsItem.setVisible(true);
        } else {
            loginAsItem.setVisible(false);
        }

        MenuItem feedbackItem = menu.findItem(R.id.menu_feedback);
        if (AppConstants.ENABLE_FEEDBACK) {
            feedbackItem.setTitle(feedbackItem.getTitle() + " (v" + PrefsUtils.getVersion(this) + ")");
        } else {
            feedbackItem.setVisible(false);
        }

        pm.setOnMenuItemClickListener(this);
        pm.show();
    }

    @Override
    public boolean onMenuItemClick(MenuItem item) {
		if (item.getItemId() == R.id.menu_profile) {
			Intent i = new Intent(this, Profile.class);
			startActivity(i);
			return true;
		} else if (item.getItemId() == R.id.menu_refresh) {
            NBSyncService.forceFeedsFolders();
			triggerSync();
			return true;
		} else if (item.getItemId() == R.id.menu_add_feed) {
			Intent i = new Intent(this, SearchForFeeds.class);
            startActivity(i);
			return true;
		} else if (item.getItemId() == R.id.menu_logout) {
			DialogFragment newFragment = new LogoutDialogFragment();
			newFragment.show(getFragmentManager(), "dialog");
		} else if (item.getItemId() == R.id.menu_settings) {
            Intent settingsIntent = new Intent(this, Settings.class);
            startActivity(settingsIntent);
            return true;
        } else if (item.getItemId() == R.id.menu_feedback) {
            try {
                Intent i = new Intent(Intent.ACTION_VIEW);
                i.setData(Uri.parse(PrefsUtils.createFeedbackLink(this)));
                startActivity(i);
            } catch (Exception e) {
                Log.wtf(this.getClass().getName(), "device cannot even open URLs to report feedback");
            }
            return true;
		} else if (item.getItemId() == R.id.menu_textsize) {
			TextSizeDialogFragment textSize = TextSizeDialogFragment.newInstance(PrefsUtils.getListTextSize(this), TextSizeDialogFragment.TextSizeType.ListText);
			textSize.show(getFragmentManager(), TextSizeDialogFragment.class.getName());
			return true;
        } else if (item.getItemId() == R.id.menu_loginas) {
            DialogFragment newFragment = new LoginAsDialogFragment();
            newFragment.show(getFragmentManager(), "dialog");
            return true;
        }
		return false;
    }

    @OnClick(R.id.main_add_button) void onClickAddButton() {
        Intent i = new Intent(this, SearchForFeeds.class);
        startActivity(i);
    }

    @OnClick(R.id.main_profile_button) void onClickProfileButton() {
        Intent i = new Intent(this, Profile.class);
        startActivity(i);
    }

    @OnClick(R.id.main_user_image) void onClickUserButton() {
        Intent i = new Intent(this, Profile.class);
        startActivity(i);
    }

    @Override
    public void onScrollStateChanged(AbsListView absListView, int i) {
        // not required
    }

    @Override
    public void onScroll(AbsListView view, int firstVisibleItem, int visibleItemCount, int totalItemCount) {
        if (swipeLayout != null) {
            boolean enable = (firstVisibleItem == 0);
            if (wasSwipeEnabled != enable) {
                swipeLayout.setEnabled(enable);
                wasSwipeEnabled = enable;
            }
        }
    }

    @Override
    public void onMarkAllRead(FeedSet feedSet) {
        FeedUtils.markFeedsRead(feedSet, null, null, this);
    }

    // NB: this callback is for the text size slider
	@Override
	public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
        float size = AppConstants.LIST_FONT_SIZE[progress];
	    PrefsUtils.setListTextSize(this, size);
        if (folderFeedList != null) folderFeedList.setTextSize(size);
	}

    // unused OnSeekBarChangeListener method
	@Override
	public void onStartTrackingTouch(SeekBar seekBar) {
	}

    // unused OnSeekBarChangeListener method
	@Override
	public void onStopTrackingTouch(SeekBar seekBar) {
	}
}
