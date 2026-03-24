package com.newsblur.activity;

import static com.newsblur.service.NbSyncManager.UPDATE_DB_READY;
import static com.newsblur.service.NbSyncManager.UPDATE_METADATA;
import static com.newsblur.service.NbSyncManager.UPDATE_REBUILD;
import static com.newsblur.service.NbSyncManager.UPDATE_STATUS;

import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.os.Trace;
import android.view.KeyEvent;
import android.view.View;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.DecelerateInterpolator;
import android.widget.AbsListView;

import androidx.annotation.NonNull;
import androidx.annotation.StringRes;
import androidx.fragment.app.FragmentManager;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

import com.newsblur.NbApplication;
import com.newsblur.R;
import com.newsblur.databinding.ActivityMainBinding;
import com.newsblur.delegate.MainContextMenuDelegate;
import com.newsblur.delegate.MainContextMenuDelegateImpl;
import com.newsblur.fragment.FeedSelectorFragment;
import com.newsblur.fragment.FeedsShortcutFragment;
import com.newsblur.fragment.FolderListFragment;
import com.newsblur.keyboard.KeyboardEvent;
import com.newsblur.keyboard.KeyboardListener;
import com.newsblur.keyboard.KeyboardManager;
import com.newsblur.service.BootReceiver;
import com.newsblur.util.AppConstants;
import com.newsblur.util.EdgeToEdgeUtil;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ShortcutUtils;
import com.newsblur.util.StateFilter;
import com.newsblur.util.UIUtils;
import com.newsblur.view.StateToggleButton.StateChangedListener;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class Main extends NbActivity implements StateChangedListener, SwipeRefreshLayout.OnRefreshListener, AbsListView.OnScrollListener, KeyboardListener {
    private static final long SYNC_STATUS_ANIMATION_DURATION_MS = 500L;
    private static final long SYNC_STATUS_DONE_DURATION_MS = 5000L;
    private static final DecelerateInterpolator SYNC_STATUS_SHOW_INTERPOLATOR = new DecelerateInterpolator();
    private static final AccelerateInterpolator SYNC_STATUS_HIDE_INTERPOLATOR = new AccelerateInterpolator();

    private enum SyncStatusAccessory {
        NONE,
        SPINNER,
        DONE,
    }

    @Inject
    FeedUtils feedUtils;

    public static final String EXTRA_FORCE_SHOW_FEED_ID = "force_show_feed_id";

    private FolderListFragment folderFeedList;
    private FeedSelectorFragment feedSelectorFragment;
    private boolean wasSwipeEnabled = false;
    private ActivityMainBinding binding;
    private MainContextMenuDelegate contextMenuDelegate;
    private KeyboardManager keyboardManager;
    private boolean hasSeenActiveSyncStatus = false;
    private boolean isShowingDoneSyncStatus = false;
    private boolean isShowingLoadingSyncPlaceholder = true;
    private boolean shouldTrackActiveSyncStatus = false;
    private int lastForegroundSessionId = 0;
    private final Runnable hideSyncStatusRunnable = () -> {
        isShowingDoneSyncStatus = false;
        hideSyncStatusIndicator(true);
    };

    @Override
    public void onCreate(Bundle savedInstanceState) {
        Trace.beginSection("MainOnCreate");

        super.onCreate(savedInstanceState);
        getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        binding = ActivityMainBinding.inflate(getLayoutInflater());
        contextMenuDelegate = new MainContextMenuDelegateImpl(this, prefsRepo);
        keyboardManager = new KeyboardManager();
        EdgeToEdgeUtil.applyView(this, binding);

        // Show a placeholder sync status while the service warms up.
        binding.mainSyncStatusText.setText(R.string.loading);
        binding.mainSyncStatusSpinner.setVisibility(View.VISIBLE);
        binding.mainSyncStatusDoneIcon.setVisibility(View.GONE);
        updateSyncStatusIndicatorBackground(SyncStatusAccessory.SPINNER);
        binding.mainSyncStatusContainer.setAlpha(1f);
        binding.mainSyncStatusContainer.setTranslationX(0f);
        binding.mainSyncStatusContainer.setVisibility(View.VISIBLE);

        binding.content.setColorSchemeResources(R.color.refresh_1, R.color.refresh_2, R.color.refresh_3, R.color.refresh_4);
        binding.content.setProgressBackgroundColorSchemeColor(
                UIUtils.getThemedColor(this, R.attr.actionbarBackground, android.R.attr.background)
        );
        binding.content.setOnRefreshListener(this);

        FragmentManager fragmentManager = getSupportFragmentManager();
        folderFeedList = (FolderListFragment) fragmentManager.findFragmentByTag("folderFeedListFragment");
        feedSelectorFragment = ((FeedSelectorFragment) fragmentManager.findFragmentByTag("feedIntelligenceSelector"));
        feedSelectorFragment.setState(folderFeedList.currentState);

        // make sure the interval sync is scheduled, since we are the root Activity
        BootReceiver.scheduleSyncService(this);

        setUserImageAndName();

        feedUtils.currentFolderName = null;

        binding.mainMenuButton.setOnClickListener(v -> onClickMenuButton());
        binding.mainAddButton.setOnClickListener(v -> onClickAddButton());
        binding.mainUserImage.setOnClickListener(v -> onClickUserButton());

        // Check whether it's a shortcut intent
        String shortcutExtra = getIntent().getStringExtra(ShortcutUtils.SHORTCUT_EXTRA);
        if (shortcutExtra != null && shortcutExtra.startsWith(ShortcutUtils.SHORTCUT_ALL_STORIES)) {
            boolean isAllStoriesSearch = shortcutExtra.equals(ShortcutUtils.SHORTCUT_ALL_STORIES_SEARCH);
            openAllStories(isAllStoriesSearch);
        }

        Trace.endSection();
        reportFullyDrawn();
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

        int foregroundSessionId = NbApplication.getForegroundSessionId();
        shouldTrackActiveSyncStatus = foregroundSessionId != lastForegroundSessionId;
        lastForegroundSessionId = foregroundSessionId;

        // triggerSync() might not actually do enough to push a UI update if background sync has been
        // behaving itself. because the system will re-use the activity, at least one update on resume
        // will be required, however inefficient
        folderFeedList.hasUpdated();

        syncServiceState.resetReadingSession(dbHelper); // TODO suspend
        syncServiceState.flushRecounts();

        updateStatusIndicators();
        folderFeedList.pushUnreadCounts();
        folderFeedList.checkOpenFolderPreferences();
        keyboardManager.addListener(this);
        triggerSync();
    }

    @Override
    protected void onPause() {
        keyboardManager.removeListener();
        cancelPendingSyncStatusHide();
        hasSeenActiveSyncStatus = false;
        isShowingDoneSyncStatus = false;
        shouldTrackActiveSyncStatus = false;
        hideSyncStatusIndicator(false);
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        cancelPendingSyncStatusHide();
        super.onDestroy();
    }

    @Override
    public void changedState(StateFilter state) {
        if (!((state == StateFilter.ALL) ||
                (state == StateFilter.SOME) ||
                (state == StateFilter.BEST))) {
            folderFeedList.setSearchQuery(null);
        }

        folderFeedList.changeState(state);
    }

    @Override
    public void handleUpdate(int updateType) {
        if ((updateType & UPDATE_REBUILD) != 0) {
            folderFeedList.reset();
        }
        if ((updateType & UPDATE_DB_READY) != 0) {
            folderFeedList.loadData();
        }
        if ((updateType & UPDATE_STATUS) != 0) {
            updateStatusIndicators();
        }
        if ((updateType & UPDATE_METADATA) != 0) {
            folderFeedList.hasUpdated();
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (KeyboardManager.hasHardwareKeyboard(this)) {
            boolean isKnownKeyCode = keyboardManager.isKnownKeyCode(keyCode);
            if (isKnownKeyCode) return true;
            else return super.onKeyDown(keyCode, event);
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        if (KeyboardManager.hasHardwareKeyboard(this)) {
            boolean handledKeyCode = keyboardManager.onKeyUp(keyCode, event);
            if (handledKeyCode) return true;
            else return super.onKeyUp(keyCode, event);
        }
        return super.onKeyUp(keyCode, event);
    }

    private void setUserImageAndName() {
        ExecutorService executor = Executors.newSingleThreadExecutor();
        executor.execute(() -> {
            Bitmap rawImage = prefsRepo.getUserImage(this);
            final Bitmap roundedImage = (rawImage != null)
                    ? UIUtils.clipAndRound(rawImage, true, false)
                    : null;

            String username = prefsRepo.getUserName();

            runOnUiThread(() -> {
                if (roundedImage != null) {
                    binding.mainUserImage.setImageBitmap(roundedImage);
                }
                binding.mainUserName.setText(username);
            });
        });
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
        if (folderFeedList.firstCursorSeenYet && isShowingLoadingSyncPlaceholder && !syncServiceState.isFeedCountSyncRunning()) {
            updateStatusIndicators();
        }

        if (feedCount < 1) {
            if (syncServiceState.isFeedCountSyncRunning() || (!folderFeedList.firstCursorSeenYet)) {
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
        String rawSyncStatus = syncServiceState.getSyncStatusMessage(this, false);
        boolean isOfflineSyncStatus = isOfflineSyncStatus(rawSyncStatus);
        boolean isShowingActiveSyncPill = rawSyncStatus != null && !isOfflineSyncStatus;
        binding.content.setRefreshing(syncServiceState.isFeedFolderSyncRunning() && !isShowingActiveSyncPill);

        String displayedSyncStatus = rawSyncStatus;
        if (displayedSyncStatus != null) {
            if (AppConstants.VERBOSE_LOG) {
                displayedSyncStatus = displayedSyncStatus + UIUtils.getMemoryUsageDebug(this);
            }
            isShowingLoadingSyncPlaceholder = false;
            isShowingDoneSyncStatus = false;
            if (isOfflineSyncStatus) {
                hasSeenActiveSyncStatus = false;
                showSyncStatusIndicator(displayedSyncStatus, SyncStatusAccessory.NONE);
            } else {
                if (shouldTrackActiveSyncStatus) {
                    hasSeenActiveSyncStatus = true;
                }
                showSyncStatusIndicator(displayedSyncStatus, SyncStatusAccessory.SPINNER);
            }
            return;
        }

        if (hasSeenActiveSyncStatus) {
            if (!folderFeedList.firstCursorSeenYet) {
                isShowingLoadingSyncPlaceholder = true;
                showSyncStatusIndicator(getString(R.string.loading), SyncStatusAccessory.SPINNER);
                return;
            }
            hasSeenActiveSyncStatus = false;
            shouldTrackActiveSyncStatus = false;
            isShowingLoadingSyncPlaceholder = false;
            showSyncStatusIndicator(getString(R.string.sync_status_done), SyncStatusAccessory.DONE);
            scheduleDoneSyncStatusHide();
        } else if (isShowingLoadingSyncPlaceholder) {
            isShowingLoadingSyncPlaceholder = false;
            hideSyncStatusIndicator(false);
        } else if (!isShowingDoneSyncStatus) {
            hideSyncStatusIndicator(false);
        }
    }

    private boolean isOfflineSyncStatus(String syncStatus) {
        return getString(R.string.sync_status_offline).equals(syncStatus);
    }

    private void showSyncStatusIndicator(String syncStatus, SyncStatusAccessory accessory) {
        cancelPendingSyncStatusHide();
        isShowingDoneSyncStatus = accessory == SyncStatusAccessory.DONE;

        binding.mainSyncStatusText.setText(syncStatus);
        binding.mainSyncStatusSpinner.setVisibility(accessory == SyncStatusAccessory.SPINNER ? View.VISIBLE : View.GONE);
        binding.mainSyncStatusDoneIcon.setVisibility(accessory == SyncStatusAccessory.DONE ? View.VISIBLE : View.GONE);
        updateSyncStatusIndicatorBackground(accessory);

        View container = binding.mainSyncStatusContainer;
        container.animate().cancel();
        if (container.getVisibility() != View.VISIBLE) {
            container.setVisibility(View.VISIBLE);
            container.post(() -> {
                container.setTranslationX(getShownSyncStatusStartTranslation());
                container.setAlpha(0f);
                container.animate()
                        .translationX(0f)
                        .alpha(1f)
                        .setInterpolator(SYNC_STATUS_SHOW_INTERPOLATOR)
                        .setDuration(SYNC_STATUS_ANIMATION_DURATION_MS)
                        .start();
            });
            return;
        }

        container.animate()
                .translationX(0f)
                .alpha(1f)
                .setInterpolator(SYNC_STATUS_SHOW_INTERPOLATOR)
                .setDuration(SYNC_STATUS_ANIMATION_DURATION_MS)
                .start();
    }

    private void updateSyncStatusIndicatorBackground(SyncStatusAccessory accessory) {
        binding.mainSyncStatusContainer.setBackgroundResource(
                accessory == SyncStatusAccessory.DONE
                        ? R.drawable.shape_sync_status_pill_done
                        : R.drawable.shape_sync_status_pill
        );
    }

    private void hideSyncStatusIndicator(boolean animated) {
        cancelPendingSyncStatusHide();

        View container = binding.mainSyncStatusContainer;
        container.animate().cancel();
        if (container.getVisibility() != View.VISIBLE) {
            return;
        }

        if (!animated) {
            container.setVisibility(View.GONE);
            container.setTranslationX(0f);
            container.setAlpha(1f);
            return;
        }

        container.post(() -> container.animate()
                .translationX(getHiddenSyncStatusTranslation())
                .alpha(0f)
                .setInterpolator(SYNC_STATUS_HIDE_INTERPOLATOR)
                .setDuration(SYNC_STATUS_ANIMATION_DURATION_MS)
                .withEndAction(() -> {
                    container.setVisibility(View.GONE);
                    container.setTranslationX(0f);
                    container.setAlpha(1f);
                })
                .start());
    }

    private int getHiddenSyncStatusTranslation() {
        return binding.mainSyncStatusContainer.getWidth() + UIUtils.dp2px(this, 20);
    }

    private int getShownSyncStatusStartTranslation() {
        return binding.mainSyncStatusContainer.getWidth() + UIUtils.dp2px(this, 20);
    }

    private void scheduleDoneSyncStatusHide() {
        binding.mainSyncStatusContainer.removeCallbacks(hideSyncStatusRunnable);
        binding.mainSyncStatusContainer.postDelayed(hideSyncStatusRunnable, SYNC_STATUS_DONE_DURATION_MS);
    }

    private void cancelPendingSyncStatusHide() {
        if (binding != null) {
            binding.mainSyncStatusContainer.removeCallbacks(hideSyncStatusRunnable);
        }
    }

    @Override
    public void onRefresh() {
        shouldTrackActiveSyncStatus = true;
        syncServiceState.forceFeedsFolders();
        triggerSync();
        folderFeedList.clearRecents();
    }

    private void onClickMenuButton() {
        contextMenuDelegate.onMenuClick(binding.mainMenuButton, folderFeedList);
    }

    private void onClickAddButton() {
        Intent i = new Intent(this, FeedSearchActivity.class);
        startActivity(i);
    }

    private void onClickUserButton() {
        Intent i = new Intent(this, Profile.class);
        startActivity(i);
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
                binding.content.setEnabled(enable);
                wasSwipeEnabled = enable;
            }
        }
    }

    private void openAllStories(boolean isAllStoriesSearch) {
        Intent intent = new Intent(this, AllStoriesItemsList.class);
        intent.putExtra(ItemsList.EXTRA_FEED_SET, FeedSet.allFeeds());
        intent.putExtra(ItemsList.EXTRA_VISIBLE_SEARCH, isAllStoriesSearch);
        startActivity(intent);
    }

    private void switchViewStateLeft() {
        StateFilter currentState = folderFeedList.currentState;
        if (currentState.equals(StateFilter.SAVED)) {
            setAndNotifySelectorState(StateFilter.BEST, R.string.focused_stories);
        } else if (currentState.equals(StateFilter.BEST)) {
            setAndNotifySelectorState(StateFilter.SOME, R.string.unread_stories);
        } else if (currentState.equals(StateFilter.SOME)) {
            setAndNotifySelectorState(StateFilter.ALL, R.string.all_stories);
        }
    }

    private void switchViewStateRight() {
        StateFilter currentState = folderFeedList.currentState;
        if (currentState.equals(StateFilter.ALL)) {
            setAndNotifySelectorState(StateFilter.SOME, R.string.unread_stories);
        } else if (currentState.equals(StateFilter.SOME)) {
            setAndNotifySelectorState(StateFilter.BEST, R.string.focused_stories);
        } else if (currentState.equals(StateFilter.BEST)) {
            setAndNotifySelectorState(StateFilter.SAVED, R.string.saved_stories);
        }
    }

    private void setAndNotifySelectorState(StateFilter state, @StringRes int notifyMsgRes) {
        feedSelectorFragment.setState(state);
        UIUtils.showSnackBar(binding.getRoot(), getString(notifyMsgRes));
    }

    private void showFeedShortcuts() {
        FeedsShortcutFragment newFragment = new FeedsShortcutFragment();
        newFragment.show(getSupportFragmentManager(), FeedsShortcutFragment.class.getName());
    }

    @Override
    public void onKeyboardEvent(@NonNull KeyboardEvent event) {
        if (event instanceof KeyboardEvent.AddFeed) {
            onClickAddButton();
        } else if (event instanceof KeyboardEvent.OpenAllStories) {
            openAllStories(false);
        } else if (event instanceof KeyboardEvent.SwitchViewLeft) {
            switchViewStateLeft();
        } else if (event instanceof KeyboardEvent.SwitchViewRight) {
            switchViewStateRight();
        } else if (event instanceof KeyboardEvent.Tutorial) {
            showFeedShortcuts();
        }
    }
}
