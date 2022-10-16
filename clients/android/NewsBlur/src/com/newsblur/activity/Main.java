package com.newsblur.activity;

import static com.newsblur.service.NBSyncReceiver.UPDATE_DB_READY;
import static com.newsblur.service.NBSyncReceiver.UPDATE_METADATA;
import static com.newsblur.service.NBSyncReceiver.UPDATE_REBUILD;
import static com.newsblur.service.NBSyncReceiver.UPDATE_STATUS;

import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.preference.PreferenceManager;

import androidx.appcompat.widget.PopupMenu;
import androidx.fragment.app.FragmentManager;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.KeyEvent;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnKeyListener;
import android.widget.AbsListView;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.databinding.ActivityMainBinding;
import com.newsblur.delegate.MainContextMenuDelegate;
import com.newsblur.delegate.MainContextMenuDelegateImpl;
import com.newsblur.fragment.FeedIntelligenceSelectorFragment;
import com.newsblur.fragment.FolderListFragment;
import com.newsblur.service.BootReceiver;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ShortcutUtils;
import com.newsblur.util.StateFilter;
import com.newsblur.util.UIUtils;
import com.newsblur.view.StateToggleButton.StateChangedListener;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class Main extends NbActivity implements StateChangedListener, SwipeRefreshLayout.OnRefreshListener, AbsListView.OnScrollListener, PopupMenu.OnMenuItemClickListener {

    @Inject
    FeedUtils feedUtils;

    @Inject
    BlurDatabaseHelper dbHelper;

    public static final String EXTRA_FORCE_SHOW_FEED_ID = "force_show_feed_id";

	private FolderListFragment folderFeedList;
    private boolean wasSwipeEnabled = false;
    private ActivityMainBinding binding;
    private MainContextMenuDelegate contextMenuDelegate;

    @Override
	public void onCreate(Bundle savedInstanceState) {
        PreferenceManager.setDefaultValues(this, R.xml.activity_settings, false);

		super.onCreate(savedInstanceState);
        getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        binding = ActivityMainBinding.inflate(getLayoutInflater());
        contextMenuDelegate = new MainContextMenuDelegateImpl(this, dbHelper);
		setContentView(binding.getRoot());

        // set the status bar to an generic loading message when the activity is first created so
        // that something is displayed while the service warms up
        binding.mainSyncStatus.setText(R.string.loading);
        binding.mainSyncStatus.setVisibility(View.VISIBLE);

        binding.swipeContainer.setColorSchemeResources(R.color.refresh_1, R.color.refresh_2, R.color.refresh_3, R.color.refresh_4);
        binding.swipeContainer.setProgressBackgroundColorSchemeResource(UIUtils.getThemedResource(this, R.attr.actionbarBackground, android.R.attr.background));
        binding.swipeContainer.setOnRefreshListener(this);

        FragmentManager fragmentManager = getSupportFragmentManager();
		folderFeedList = (FolderListFragment) fragmentManager.findFragmentByTag("folderFeedListFragment");
        ((FeedIntelligenceSelectorFragment) fragmentManager.findFragmentByTag("feedIntelligenceSelector")).setState(folderFeedList.currentState);

        // make sure the interval sync is scheduled, since we are the root Activity
        BootReceiver.scheduleSyncService(this);

        Bitmap userPicture = PrefsUtils.getUserImage(this);
        if (userPicture != null) {
            userPicture = UIUtils.clipAndRound(userPicture, true, false);
            binding.mainUserImage.setImageBitmap(userPicture);
        }
        binding.mainUserName.setText(PrefsUtils.getUserDetails(this).username);
        binding.feedlistSearchQuery.setOnKeyListener(new OnKeyListener() {
            public boolean onKey(View v, int keyCode, KeyEvent event) {
                if ((keyCode == KeyEvent.KEYCODE_BACK) && (event.getAction() == KeyEvent.ACTION_DOWN)) {
                    binding.feedlistSearchQuery.setVisibility(View.GONE);
                    binding.feedlistSearchQuery.setText("");
                    checkSearchQuery();
                    return true;
                }
                if ((keyCode == KeyEvent.KEYCODE_ENTER) && (event.getAction() == KeyEvent.ACTION_DOWN)) {
                    checkSearchQuery();
                    return true;
                }
                return false;
            }
        });
        binding.feedlistSearchQuery.addTextChangedListener(new TextWatcher() {
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                checkSearchQuery();
            }
            public void afterTextChanged(Editable s) {}
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
        });

        feedUtils.currentFolderName = null;

        binding.mainMenuButton.setOnClickListener(v -> onClickMenuButton());
        binding.mainAddButton.setOnClickListener(v -> onClickAddButton());
        binding.mainProfileButton.setOnClickListener(v -> onClickProfileButton());
        binding.mainUserImage.setOnClickListener(v -> onClickUserButton());
        binding.mainSearchFeedsButton.setOnClickListener(v -> onClickSearchFeedsButton());

        // Check whether it's a shortcut intent
        String shortcutExtra = getIntent().getStringExtra(ShortcutUtils.SHORTCUT_EXTRA);
        if (shortcutExtra != null && shortcutExtra.startsWith(ShortcutUtils.SHORTCUT_ALL_STORIES)) {
            Intent intent = new Intent(this, AllStoriesItemsList.class);
            intent.putExtra(ItemsList.EXTRA_FEED_SET, FeedSet.allFeeds());
            if (shortcutExtra.equals(ShortcutUtils.SHORTCUT_ALL_STORIES_SEARCH)) {
                intent.putExtra(ItemsList.EXTRA_VISIBLE_SEARCH, true);
            }
            startActivity(intent);
        }
	}

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
    }

    @Override
    protected void onResume() {
        try {
            // due to weird backstack operations coming from notified reading activities,
            // sometimes we fail to reload. do everything in our power to log
            super.onResume();
        } catch (Exception e) {
            com.newsblur.util.Log.e(getClass().getName(), "error resuming Main", e);
            finish();
        }

        String forceShowFeedId = getIntent().getStringExtra(EXTRA_FORCE_SHOW_FEED_ID);
        if (forceShowFeedId != null) {
            folderFeedList.forceShowFeed(forceShowFeedId);
        }

        if (folderFeedList.getSearchQuery() != null) {
            binding.feedlistSearchQuery.setText(folderFeedList.getSearchQuery());
            binding.feedlistSearchQuery.setVisibility(View.VISIBLE);
        }

        // triggerSync() might not actually do enough to push a UI update if background sync has been
        // behaving itself. because the system will re-use the activity, at least one update on resume
        // will be required, however inefficient
        folderFeedList.hasUpdated();

        NBSyncService.resetReadingSession(dbHelper);
        NBSyncService.flushRecounts();

        updateStatusIndicators();
        folderFeedList.pushUnreadCounts();
        folderFeedList.checkOpenFolderPreferences();
        triggerSync();
    }

	@Override
	public void changedState(StateFilter state) {
        if ( !( (state == StateFilter.ALL) ||
                (state == StateFilter.SOME) ||
                (state == StateFilter.BEST) ) ) {
            binding.feedlistSearchQuery.setText("");
            binding.feedlistSearchQuery.setVisibility(View.GONE);
            checkSearchQuery();
        }

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
        binding.mainUnreadCountNeutText.setText(Integer.toString(neutCount));
        binding.mainUnreadCountPosiText.setText(Integer.toString(posiCount));
    }

    /**
     * A callback for the feed list fragment so it can tell us how many feeds (not folders)
     * are being displayed based on mode, etc.  This lets us adjust our wrapper UI without
     * having to expensively recalculate those totals from the DB.
     */
    public void updateFeedCount(int feedCount) {
        if (feedCount < 1 ) {
            if (NBSyncService.isFeedCountSyncRunning() || (!folderFeedList.firstCursorSeenYet)) {
                binding.emptyViewImage.setVisibility(View.INVISIBLE);
                binding.emptyViewText.setVisibility(View.INVISIBLE);
            } else {
                binding.emptyViewImage.setVisibility(View.VISIBLE);
                if (folderFeedList.currentState == StateFilter.BEST) {
                    binding.emptyViewText.setText(R.string.empty_list_view_no_focus_stories);
                } else if (folderFeedList.currentState == StateFilter.SAVED) {
                    binding.emptyViewText.setText(R.string.empty_list_view_no_saved_stories);
                } else {
                    binding.emptyViewText.setText(R.string.empty_list_view_no_unread_stories);
                }
                binding.emptyViewText.setVisibility(View.VISIBLE);
            }
        } else {
            binding.emptyViewImage.setVisibility(View.INVISIBLE);
            binding.emptyViewText.setVisibility(View.INVISIBLE);
        }
    }

    private void updateStatusIndicators() {
        binding.swipeContainer.setRefreshing(NBSyncService.isFeedFolderSyncRunning());

        String syncStatus = NBSyncService.getSyncStatusMessage(this, false);
        if (syncStatus != null)  {
            if (AppConstants.VERBOSE_LOG) {
                syncStatus = syncStatus + UIUtils.getMemoryUsageDebug(this);
            }
            binding.mainSyncStatus.setText(syncStatus);
            binding.mainSyncStatus.setVisibility(View.VISIBLE);
        } else {
            binding.mainSyncStatus.setVisibility(View.GONE);
        }
    }

    @Override
    public void onRefresh() {
        NBSyncService.forceFeedsFolders();
        triggerSync();
        folderFeedList.clearRecents();
    }

    private void onClickMenuButton() {
        contextMenuDelegate.onMenuClick(binding.mainMenuButton, this);
    }

    @Override
    public boolean onMenuItemClick(MenuItem item) {
        return contextMenuDelegate.onMenuItemClick(item, folderFeedList);
    }

    private void onClickAddButton() {
        Intent i = new Intent(this, FeedSearchActivity.class);
        startActivity(i);
    }

    private void onClickProfileButton() {
        Intent i = new Intent(this, Profile.class);
        startActivity(i);
    }

    private void onClickUserButton() {
        Intent i = new Intent(this, Profile.class);
        startActivity(i);
    }

    private void onClickSearchFeedsButton() {
        if (binding.feedlistSearchQuery.getVisibility() != View.VISIBLE) {
            binding.feedlistSearchQuery.setVisibility(View.VISIBLE);
            binding.feedlistSearchQuery.requestFocus();
        } else {
            binding.feedlistSearchQuery.setText("");
            binding.feedlistSearchQuery.setVisibility(View.GONE);
            checkSearchQuery();
        }
    }

    @Override
    public void onScrollStateChanged(AbsListView absListView, int i) {
        // not required
    }

    @Override
    public void onScroll(AbsListView view, int firstVisibleItem, int visibleItemCount, int totalItemCount) {
        if (binding != null) {
            boolean enable = (firstVisibleItem == 0);
            if (wasSwipeEnabled != enable) {
                binding.swipeContainer.setEnabled(enable);
                wasSwipeEnabled = enable;
            }
        }
    }

    private void checkSearchQuery() {
        String q = binding.feedlistSearchQuery.getText().toString().trim();
        if (q.length() < 1) {
            q = null;
        }
        folderFeedList.setSearchQuery(q);
    }
}
