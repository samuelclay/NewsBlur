package com.newsblur.activity;

import static com.newsblur.service.NBSyncReceiver.UPDATE_DB_READY;
import static com.newsblur.service.NBSyncReceiver.UPDATE_METADATA;
import static com.newsblur.service.NBSyncReceiver.UPDATE_REBUILD;
import static com.newsblur.service.NBSyncReceiver.UPDATE_STATUS;

import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Bundle;
import android.preference.PreferenceManager;

import androidx.appcompat.widget.PopupMenu;
import androidx.fragment.app.DialogFragment;
import androidx.fragment.app.FragmentManager;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnKeyListener;
import android.widget.AbsListView;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.databinding.ActivityMainBinding;
import com.newsblur.fragment.FeedIntelligenceSelectorFragment;
import com.newsblur.fragment.FolderListFragment;
import com.newsblur.fragment.LoginAsDialogFragment;
import com.newsblur.fragment.LogoutDialogFragment;
import com.newsblur.service.BootReceiver;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants.ThemeValue;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ShortcutUtils;
import com.newsblur.util.SpacingStyle;
import com.newsblur.util.StateFilter;
import com.newsblur.util.ListTextSize;
import com.newsblur.util.UIUtils;
import com.newsblur.view.StateToggleButton.StateChangedListener;
import com.newsblur.widget.WidgetUtils;

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
	private FragmentManager fragmentManager;
    private SwipeRefreshLayout swipeLayout;
    private boolean wasSwipeEnabled = false;
    private ActivityMainBinding binding;

    @Override
	public void onCreate(Bundle savedInstanceState) {
        PreferenceManager.setDefaultValues(this, R.xml.activity_settings, false);

		super.onCreate(savedInstanceState);
        getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        binding = ActivityMainBinding.inflate(getLayoutInflater());
		setContentView(binding.getRoot());

        // set the status bar to an generic loading message when the activity is first created so
        // that something is displayed while the service warms up
        binding.mainSyncStatus.setText(R.string.loading);
        binding.mainSyncStatus.setVisibility(View.VISIBLE);

        swipeLayout = (SwipeRefreshLayout)findViewById(R.id.swipe_container);
        swipeLayout.setColorSchemeResources(R.color.refresh_1, R.color.refresh_2, R.color.refresh_3, R.color.refresh_4);
        swipeLayout.setProgressBackgroundColorSchemeResource(UIUtils.getThemedResource(this, R.attr.actionbarBackground, android.R.attr.background));
        swipeLayout.setOnRefreshListener(this);

		fragmentManager = getSupportFragmentManager();
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
        if (NBSyncService.isFeedFolderSyncRunning()) {
            swipeLayout.setRefreshing(true);
        } else {
            swipeLayout.setRefreshing(false);
        }

        if (binding.mainSyncStatus != null) {
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
    }

    @Override
    public void onRefresh() {
        NBSyncService.forceFeedsFolders();
        triggerSync();
        folderFeedList.clearRecents();
    }

    private void onClickMenuButton() {
        PopupMenu pm = new PopupMenu(this, binding.mainMenuButton);
        Menu menu = pm.getMenu();
        pm.getMenuInflater().inflate(R.menu.main, menu);

        MenuItem loginAsItem = menu.findItem(R.id.menu_loginas);
        if (NBSyncService.isStaff == Boolean.TRUE) {
            loginAsItem.setVisible(true);
        } else {
            loginAsItem.setVisible(false);
        }

        ThemeValue themeValue = PrefsUtils.getSelectedTheme(this);
        if (themeValue == ThemeValue.LIGHT) {
            menu.findItem(R.id.menu_theme_light).setChecked(true);
        } else if (themeValue == ThemeValue.DARK) {
            menu.findItem(R.id.menu_theme_dark).setChecked(true);
        } else if (themeValue == ThemeValue.BLACK) {
            menu.findItem(R.id.menu_theme_black).setChecked(true);
        } else if (themeValue == ThemeValue.AUTO) {
            menu.findItem(R.id.menu_theme_auto).setChecked(true);
        }

        SpacingStyle spacingStyle = PrefsUtils.getSpacingStyle(this);
        if (spacingStyle == SpacingStyle.COMFORTABLE) {
            menu.findItem(R.id.menu_spacing_comfortable).setChecked(true);
        } else if (spacingStyle == SpacingStyle.COMPACT) {
            menu.findItem(R.id.menu_spacing_compact).setChecked(true);
        }

        ListTextSize listTextSize = ListTextSize.fromSize(PrefsUtils.getListTextSize(this));
        if (listTextSize == ListTextSize.XS) {
            menu.findItem(R.id.menu_text_size_xs).setChecked(true);
        } else if (listTextSize == ListTextSize.S) {
            menu.findItem(R.id.menu_text_size_s).setChecked(true);
        } else if (listTextSize == ListTextSize.M) {
            menu.findItem(R.id.menu_text_size_m).setChecked(true);
        } else if (listTextSize == ListTextSize.L) {
            menu.findItem(R.id.menu_text_size_l).setChecked(true);
        } else if (listTextSize == ListTextSize.XL) {
            menu.findItem(R.id.menu_text_size_xl).setChecked(true);
        } else if (listTextSize == ListTextSize.XXL) {
            menu.findItem(R.id.menu_text_size_xxl).setChecked(true);
        }
        
        menu.findItem(R.id.menu_widget).setVisible(WidgetUtils.hasActiveAppWidgets(this));

        pm.setOnMenuItemClickListener(this);
        pm.show();
    }

    @Override
    public boolean onMenuItemClick(MenuItem item) {
		if (item.getItemId() == R.id.menu_logout) {
			DialogFragment newFragment = new LogoutDialogFragment();
			newFragment.show(getSupportFragmentManager(), "dialog");
		} else if (item.getItemId() == R.id.menu_settings) {
            Intent settingsIntent = new Intent(this, Settings.class);
            startActivity(settingsIntent);
            return true;
        } else if (item.getItemId() == R.id.menu_widget) {
            Intent widgetIntent = new Intent(this, WidgetConfig.class);
            startActivity(widgetIntent);
            return true;
		} else if (item.getItemId() == R.id.menu_feedback_email) {
            PrefsUtils.sendLogEmail(this, dbHelper);
            return true;
        } else if (item.getItemId() == R.id.menu_feedback_post) {
            try {
                Intent i = new Intent(Intent.ACTION_VIEW);
                i.setData(Uri.parse(PrefsUtils.createFeedbackLink(this, dbHelper)));
                startActivity(i);
            } catch (Exception e) {
                Log.wtf(this.getClass().getName(), "device cannot even open URLs to report feedback");
            }
            return true;
		} else if (item.getItemId() == R.id.menu_text_size_xs) {
		    folderFeedList.setListTextSize(ListTextSize.XS);
		    return true;
        } else if (item.getItemId() == R.id.menu_text_size_s) {
            folderFeedList.setListTextSize(ListTextSize.S);
            return true;
        } else if (item.getItemId() == R.id.menu_text_size_m) {
            folderFeedList.setListTextSize(ListTextSize.M);
            return true;
        } else if (item.getItemId() == R.id.menu_text_size_l) {
            folderFeedList.setListTextSize(ListTextSize.L);
            return true;
        } else if (item.getItemId() == R.id.menu_text_size_xl) {
            folderFeedList.setListTextSize(ListTextSize.XL);
            return true;
        } else if (item.getItemId() == R.id.menu_text_size_xxl) {
            folderFeedList.setListTextSize(ListTextSize.XXL);
			return true;
        } else if (item.getItemId() == R.id.menu_spacing_comfortable) {
		    folderFeedList.setSpacingStyle(SpacingStyle.COMFORTABLE);
		    return true;
        } else if (item.getItemId() == R.id.menu_spacing_compact) {
            folderFeedList.setSpacingStyle(SpacingStyle.COMPACT);
            return true;
        } else if (item.getItemId() == R.id.menu_loginas) {
            DialogFragment newFragment = new LoginAsDialogFragment();
            newFragment.show(getSupportFragmentManager(), "dialog");
            return true;
        } else if (item.getItemId() == R.id.menu_theme_auto) {
            PrefsUtils.setSelectedTheme(this, ThemeValue.AUTO);
		    UIUtils.restartActivity(this);
        } else if (item.getItemId() == R.id.menu_theme_light) {
            PrefsUtils.setSelectedTheme(this, ThemeValue.LIGHT);
            UIUtils.restartActivity(this);
        } else if (item.getItemId() == R.id.menu_theme_dark) {
            PrefsUtils.setSelectedTheme(this, ThemeValue.DARK);
            UIUtils.restartActivity(this);
        } else if (item.getItemId() == R.id.menu_theme_black) {
            PrefsUtils.setSelectedTheme(this, ThemeValue.BLACK);
            UIUtils.restartActivity(this);
        } else if (item.getItemId() == R.id.menu_premium_account) {
            Intent intent = new Intent(this, Premium.class);
            startActivity(intent);
            return true;
        } else if (item.getItemId() == R.id.menu_mute_sites) {
		    Intent intent = new Intent(this, MuteConfig.class);
		    startActivity(intent);
		    return true;
        } else if (item.getItemId() == R.id.menu_import_export) {
		    Intent intent = new Intent(this, ImportExportActivity.class);
		    startActivity(intent);
            return true;
        } else if (item.getItemId() == R.id.menu_notifications) {
            Intent intent = new Intent(this, NotificationsActivity.class);
            startActivity(intent);
            return true;
        }
		return false;
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
        if (swipeLayout != null) {
            boolean enable = (firstVisibleItem == 0);
            if (wasSwipeEnabled != enable) {
                swipeLayout.setEnabled(enable);
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
