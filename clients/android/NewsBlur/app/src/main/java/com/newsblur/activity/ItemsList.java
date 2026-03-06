package com.newsblur.activity;

import static com.newsblur.service.NbSyncManager.UPDATE_REBUILD;
import static com.newsblur.service.NbSyncManager.UPDATE_STATUS;
import static com.newsblur.service.NbSyncManager.UPDATE_STORY;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.ValueAnimator;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.os.Bundle;
import android.os.Trace;
import android.text.TextUtils;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnKeyListener;
import android.view.ViewGroup;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.DecelerateInterpolator;

import androidx.activity.result.ActivityResult;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;
import androidx.lifecycle.ViewModelProvider;

import com.google.android.material.color.MaterialColors;
import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.databinding.ActivityItemslistBinding;
import com.newsblur.delegate.ItemListContextMenuDelegate;
import com.newsblur.delegate.ItemListContextMenuDelegateImpl;
import com.newsblur.fragment.ItemSetFragment;
import com.newsblur.service.SyncServiceState;
import com.newsblur.util.EdgeToEdgeUtil;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.Log;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.PendingTransitionUtils;
import com.newsblur.util.ReadingActionListener;
import com.newsblur.util.Session;
import com.newsblur.util.SessionDataSource;
import com.newsblur.util.StateFilter;
import com.newsblur.util.UIUtils;
import com.newsblur.viewModel.ItemListViewModel;

import org.jetbrains.annotations.NotNull;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public abstract class ItemsList extends NbActivity implements ReadingActionListener {

    @Inject
    BlurDatabaseHelper dbHelper;

    @Inject
    FeedUtils feedUtils;

    @Inject
    SyncServiceState syncServiceState;

    public static final String EXTRA_FEED_SET = "feed_set";
    public static final String EXTRA_STORY_HASH = "story_hash";
    public static final String EXTRA_WIDGET_STORY = "widget_story";
    public static final String EXTRA_VISIBLE_SEARCH = "visibleSearch";
    public static final String EXTRA_SESSION_DATA = "session_data";
    private static final String BUNDLE_ACTIVE_SEARCH_QUERY = "activeSearchQuery";
    private static final long STORY_STATUS_FETCH_DELAY_MS = 1000L;
    private static final long STORY_STATUS_SHOW_DURATION_MS = 300L;
    private static final long STORY_STATUS_HIDE_DURATION_MS = 250L;
    private static final DecelerateInterpolator STORY_STATUS_SHOW_INTERPOLATOR = new DecelerateInterpolator();
    private static final AccelerateInterpolator STORY_STATUS_HIDE_INTERPOLATOR = new AccelerateInterpolator();

    protected ItemListViewModel viewModel;
    protected FeedSet fs;

    private ItemSetFragment itemSetFragment;
    private ActivityItemslistBinding binding;
    private ItemListContextMenuDelegate contextMenuDelegate;
    @Nullable
    private SessionDataSource sessionDataSource;
    @Nullable
    private ValueAnimator storyStatusBannerAnimator;
    private boolean awaitingInitialFetchingBanner = false;
    private boolean fetchingBannerDelayElapsed = false;
    private final Runnable showFetchingBannerRunnable = () -> {
        fetchingBannerDelayElapsed = true;
        updateStatusIndicators();
    };

    private enum StoryStatusBannerStyle {
        FETCHING,
        OFFLINE,
    }

    @NonNull
    protected ActivityResultLauncher<Intent> readingActivityLaunch = registerForActivityResult(
            new ActivityResultContracts.StartActivityForResult(), this::handleReadingActivityResult
    );

    @Override
    protected void onCreate(Bundle bundle) {
        Trace.beginSection("ItemsListOnCreate");
        super.onCreate(bundle);

        PendingTransitionUtils.overrideEnterTransition(this);

        contextMenuDelegate = new ItemListContextMenuDelegateImpl(this, feedUtils, prefsRepo, syncServiceState);
        viewModel = new ViewModelProvider(this).get(ItemListViewModel.class);
        fs = (FeedSet) getIntent().getSerializableExtra(EXTRA_FEED_SET);
        sessionDataSource = (SessionDataSource) getIntent().getSerializableExtra(EXTRA_SESSION_DATA);

        // this is not strictly necessary, since our first refresh with the fs will swap in
        // the correct session, but that can be delayed by sync backup, so we try here to
        // reduce UI lag, or in case somehow we got redisplayed in a zero-story state
        feedUtils.prepareReadingSession(fs, false);
        if (getIntent().getBooleanExtra(EXTRA_WIDGET_STORY, false)) {
            String hash = (String) getIntent().getSerializableExtra(EXTRA_STORY_HASH);
            UIUtils.startReadingActivity(this, fs, hash, readingActivityLaunch);
        } else if (prefsRepo.isAutoOpenFirstUnread()) {
            StateFilter intelState = prefsRepo.getStateFilter();
            if (dbHelper.getUnreadCount(fs, intelState) > 0) {
                UIUtils.startReadingActivity(this, fs, Reading.FIND_FIRST_UNREAD, readingActivityLaunch);
            }
        }

        getWindow().setBackgroundDrawableResource(android.R.color.transparent);

        binding = ActivityItemslistBinding.inflate(getLayoutInflater());
        EdgeToEdgeUtil.applyView(this, binding);

        FragmentManager fragmentManager = getSupportFragmentManager();
        itemSetFragment = (ItemSetFragment) fragmentManager.findFragmentByTag(ItemSetFragment.class.getName());
        if (itemSetFragment == null) {
            itemSetFragment = ItemSetFragment.newInstance();
			FragmentTransaction transaction = fragmentManager.beginTransaction();
			transaction.add(R.id.activity_itemlist_container, itemSetFragment, ItemSetFragment.class.getName());
			transaction.commitNow();
		}

        String activeSearchQuery;
        if (bundle != null) {
            activeSearchQuery = bundle.getString(BUNDLE_ACTIVE_SEARCH_QUERY);
        } else {
            activeSearchQuery = fs.getSearchQuery();
        }
        if (activeSearchQuery != null) {
            binding.itemlistSearchQuery.setText(activeSearchQuery);
            binding.itemlistSearchQuery.setVisibility(View.VISIBLE);
        } else if (getIntent().getBooleanExtra(EXTRA_VISIBLE_SEARCH, false)) {
            binding.itemlistSearchQuery.setVisibility(View.VISIBLE);
            binding.itemlistSearchQuery.requestFocus();
        }

        binding.itemlistSearchQuery.setOnKeyListener(new OnKeyListener() {
            public boolean onKey(View v, int keyCode, KeyEvent event) {
                if ((keyCode == KeyEvent.KEYCODE_BACK) && (event.getAction() == KeyEvent.ACTION_DOWN)) {
                    binding.itemlistSearchQuery.setVisibility(View.GONE);
                    binding.itemlistSearchQuery.setText("");
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
        scheduleInitialFetchingBanner();
        Trace.endSection();
    }

    @Override
    protected void onSaveInstanceState(@NotNull Bundle savedInstanceState) {
        super.onSaveInstanceState(savedInstanceState);
        String q = binding.itemlistSearchQuery.getText().toString().trim();
        if (!q.isEmpty()) {
            savedInstanceState.putString(BUNDLE_ACTIVE_SEARCH_QUERY, q);
        }
    }

    public FeedSet getFeedSet() {
        return this.fs;
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (syncServiceState.isHousekeepingRunning()) finish();
        updateStatusIndicators();
        if (itemSetFragment != null) {
            itemSetFragment.refreshLoadingIndicators();
        }
        // Reading activities almost certainly changed the read/unread state of some stories. Ensure
        // we reflect those changes promptly.
        itemSetFragment.hasUpdated();
    }

    @Override
    protected void onPause() {
        cancelPendingFetchingBanner();
        cancelStoryStatusBannerAnimation();
        super.onPause();
        syncServiceState.addRecountCandidate(fs);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        return contextMenuDelegate.onCreateMenuOptions(menu, getMenuInflater(), fs);
    }

    @Override
    public boolean onPrepareOptionsMenu(Menu menu) {
        super.onPrepareOptionsMenu(menu);
        boolean showSavedSearch = !TextUtils.isEmpty(binding.itemlistSearchQuery.getText());
        return contextMenuDelegate.onPrepareMenuOptions(menu, fs, showSavedSearch);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        return contextMenuDelegate.onOptionsItemSelected(item, itemSetFragment, fs, binding.itemlistSearchQuery, getSaveSearchFeedId());
    }

    // infix fun Int.has(flag: Int) = (this and flag) != 0
    @Override
    public void handleUpdate(int updateType) {
        if ((updateType & UPDATE_REBUILD) != 0) {
            finish();
        }
        if ((updateType & UPDATE_STATUS) != 0) {
            updateStatusIndicators();
            if (itemSetFragment != null) {
                itemSetFragment.refreshLoadingIndicators();
            }
        }
        if ((updateType & UPDATE_STORY) != 0) {
            if (itemSetFragment != null) {
                itemSetFragment.hasUpdated();
            }
        }
    }

    @Override
    public void onReadingActionCompleted() {
        if (sessionDataSource != null) {
            Session session = sessionDataSource.getNextSession();
            if (session != null) {
                // set the next session on the parent activity
                fs = session.getFeedSet();
                feedUtils.prepareReadingSession(fs, false);
                triggerSync();
                scheduleInitialFetchingBanner();

                // set the next session on the child activity
                viewModel.updateSession(session);

                // update item set fragment
                itemSetFragment.resetEmptyState();
                itemSetFragment.hasUpdated();
                itemSetFragment.scrollToTop();
            } else finish();
        } else finish();
    }

    private void updateStatusIndicators() {
        if (!NetworkUtils.isOnline(this)) {
            cancelPendingFetchingBanner();
            showStoryStatusBanner(getString(R.string.sync_status_offline), StoryStatusBannerStyle.OFFLINE);
            return;
        }

        boolean isInitialFetchPending = awaitingInitialFetchingBanner && syncServiceState.isFeedSetSyncing(fs);
        if (isInitialFetchPending && fetchingBannerDelayElapsed && itemSetFragment != null && itemSetFragment.hasStories()) {
            showStoryStatusBanner("Fetching recent stories...", StoryStatusBannerStyle.FETCHING);
            return;
        }

        if (!syncServiceState.isFeedSetSyncing(fs)) {
            awaitingInitialFetchingBanner = false;
            fetchingBannerDelayElapsed = false;
            cancelPendingFetchingBanner();
        }

        hideStoryStatusBanner(true);
    }

    public void refreshStoryStatusIndicators() {
        updateStatusIndicators();
    }

    private void checkSearchQuery() {
        String q = binding.itemlistSearchQuery.getText().toString().trim();
        if (q.length() < 1) {
            updateFleuron(false);
            q = null;
        } else if (!prefsRepo.hasSubscription()) {
            updateFleuron(true);
            return;
        }

        String oldQuery = fs.getSearchQuery();
        fs.setSearchQuery(q);
        if (!TextUtils.equals(q, oldQuery)) {
            feedUtils.prepareReadingSession(fs, true);
            triggerSync();
            scheduleInitialFetchingBanner();
            itemSetFragment.resetEmptyState();
            itemSetFragment.hasUpdated();
            itemSetFragment.scrollToTop();
        }
    }

    private void updateFleuron(boolean requiresPremium) {
        FragmentTransaction transaction = getSupportFragmentManager()
                .beginTransaction()
                .setCustomAnimations(android.R.animator.fade_in, android.R.animator.fade_out);

        if (requiresPremium) {
            transaction.hide(itemSetFragment);
            binding.footerFleuron.textSubscription.setText(R.string.premium_subscribers_search);
            binding.footerFleuron.containerSubscribe.setVisibility(View.VISIBLE);
            binding.footerFleuron.getRoot().setVisibility(View.VISIBLE);
            binding.footerFleuron.containerSubscribe.setOnClickListener(view -> UIUtils.startSubscriptionActivity(this));
        } else {
            transaction.show(itemSetFragment);
            binding.footerFleuron.containerSubscribe.setVisibility(View.GONE);
            binding.footerFleuron.getRoot().setVisibility(View.GONE);
            binding.footerFleuron.containerSubscribe.setOnClickListener(null);
        }
	    transaction.commitNow();
    }

    public void restartReadingSession() {
        syncServiceState.resetFetchState(fs);
        feedUtils.prepareReadingSession(fs, true);
        triggerSync();
        scheduleInitialFetchingBanner();
        itemSetFragment.resetEmptyState();
        itemSetFragment.hasUpdated();
        itemSetFragment.scrollToTop();
    }

    public void startReadingActivity(FeedSet feedSet, String storyHash) {
        UIUtils.startReadingActivity(this, feedSet, storyHash, readingActivityLaunch);
    }

    private void handleReadingActivityResult(ActivityResult result) {
        if (result.getData() != null) {
            int lastReadingPosition = result.getData().getIntExtra(Reading.LAST_READING_POS, -1);
            if (lastReadingPosition > 1) {
                Log.d(this.getClass().getName(), "Scrolling to last reading position " + lastReadingPosition);
                itemSetFragment.scrollToPosition(lastReadingPosition);
            }
        }
    }

    @Override
    public void finish() {
        cancelPendingFetchingBanner();
        cancelStoryStatusBannerAnimation();
        super.finish();
        PendingTransitionUtils.overrideExitTransition(this);
    }

    private void scheduleInitialFetchingBanner() {
        awaitingInitialFetchingBanner = true;
        fetchingBannerDelayElapsed = false;
        cancelPendingFetchingBanner();
        hideStoryStatusBanner(false);
        binding.itemlistStoryStatusBanner.postDelayed(showFetchingBannerRunnable, STORY_STATUS_FETCH_DELAY_MS);
    }

    private void cancelPendingFetchingBanner() {
        if (binding != null) {
            binding.itemlistStoryStatusBanner.removeCallbacks(showFetchingBannerRunnable);
        }
    }

    private void showStoryStatusBanner(String title, StoryStatusBannerStyle style) {
        applyStoryStatusBannerStyle(title, style);

        if (binding.itemlistStoryStatusBanner.getVisibility() == View.VISIBLE) {
            return;
        }

        cancelStoryStatusBannerAnimation();

        View banner = binding.itemlistStoryStatusBanner;
        ViewGroup.LayoutParams layoutParams = banner.getLayoutParams();
        layoutParams.height = 0;
        banner.setLayoutParams(layoutParams);
        banner.setVisibility(View.VISIBLE);

        int expandedHeight = measureStoryStatusBannerHeight();
        animateStoryStatusBannerHeight(0, expandedHeight, true);
    }

    private void hideStoryStatusBanner(boolean animated) {
        View banner = binding.itemlistStoryStatusBanner;
        if (banner.getVisibility() != View.VISIBLE) {
            return;
        }

        cancelStoryStatusBannerAnimation();

        if (!animated) {
            banner.setVisibility(View.GONE);
            ViewGroup.LayoutParams layoutParams = banner.getLayoutParams();
            layoutParams.height = ViewGroup.LayoutParams.WRAP_CONTENT;
            banner.setLayoutParams(layoutParams);
            return;
        }

        int currentHeight = banner.getHeight();
        if (currentHeight == 0) {
            currentHeight = measureStoryStatusBannerHeight();
        }
        animateStoryStatusBannerHeight(currentHeight, 0, false);
    }

    private void animateStoryStatusBannerHeight(int startHeight, int endHeight, boolean showing) {
        ValueAnimator animator = ValueAnimator.ofInt(startHeight, endHeight);
        animator.setDuration(showing ? STORY_STATUS_SHOW_DURATION_MS : STORY_STATUS_HIDE_DURATION_MS);
        animator.setInterpolator(showing ? STORY_STATUS_SHOW_INTERPOLATOR : STORY_STATUS_HIDE_INTERPOLATOR);
        animator.addUpdateListener(valueAnimator -> {
            ViewGroup.LayoutParams layoutParams = binding.itemlistStoryStatusBanner.getLayoutParams();
            layoutParams.height = (int) valueAnimator.getAnimatedValue();
            binding.itemlistStoryStatusBanner.setLayoutParams(layoutParams);
        });
        animator.addListener(new AnimatorListenerAdapter() {
            @Override
            public void onAnimationEnd(Animator animation) {
                if (storyStatusBannerAnimator != animation) {
                    return;
                }
                ViewGroup.LayoutParams layoutParams = binding.itemlistStoryStatusBanner.getLayoutParams();
                if (showing) {
                    layoutParams.height = ViewGroup.LayoutParams.WRAP_CONTENT;
                    binding.itemlistStoryStatusBanner.setLayoutParams(layoutParams);
                } else {
                    binding.itemlistStoryStatusBanner.setVisibility(View.GONE);
                    layoutParams.height = ViewGroup.LayoutParams.WRAP_CONTENT;
                    binding.itemlistStoryStatusBanner.setLayoutParams(layoutParams);
                }
                storyStatusBannerAnimator = null;
            }

            @Override
            public void onAnimationCancel(Animator animation) {
                if (storyStatusBannerAnimator == animation) {
                    storyStatusBannerAnimator = null;
                }
            }
        });
        storyStatusBannerAnimator = animator;
        animator.start();
    }

    private void cancelStoryStatusBannerAnimation() {
        if (storyStatusBannerAnimator != null) {
            storyStatusBannerAnimator.cancel();
            storyStatusBannerAnimator = null;
        }
        binding.itemlistStoryStatusBanner.animate().cancel();
    }

    private int measureStoryStatusBannerHeight() {
        View banner = binding.itemlistStoryStatusBanner;
        int width = binding.content.getWidth();
        if (width <= 0) {
            width = getResources().getDisplayMetrics().widthPixels;
        }
        int widthSpec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY);
        int heightSpec = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED);
        banner.measure(widthSpec, heightSpec);
        return banner.getMeasuredHeight();
    }

    private void applyStoryStatusBannerStyle(String title, StoryStatusBannerStyle style) {
        binding.itemlistStoryStatusText.setText(title);
        binding.itemlistStoryStatusSpinner.setVisibility(style == StoryStatusBannerStyle.FETCHING ? View.VISIBLE : View.GONE);
        binding.itemlistStoryStatusOfflineIcon.setVisibility(style == StoryStatusBannerStyle.OFFLINE ? View.VISIBLE : View.GONE);

        int backgroundAttr = style == StoryStatusBannerStyle.OFFLINE
                ? R.attr.storyStatusOfflineBackgroundColor
                : R.attr.storyStatusFetchingBackgroundColor;
        int textAttr = style == StoryStatusBannerStyle.OFFLINE
                ? R.attr.storyStatusOfflineTextColor
                : R.attr.storyStatusFetchingTextColor;
        int borderAttr = style == StoryStatusBannerStyle.OFFLINE
                ? R.attr.storyStatusOfflineBorderColor
                : R.attr.storyStatusFetchingBorderColor;

        int backgroundColor = MaterialColors.getColor(binding.itemlistStoryStatusBanner, backgroundAttr);
        int textColor = MaterialColors.getColor(binding.itemlistStoryStatusBanner, textAttr);
        int borderColor = MaterialColors.getColor(binding.itemlistStoryStatusBanner, borderAttr);

        binding.itemlistStoryStatusBanner.setBackgroundColor(backgroundColor);
        binding.itemlistStoryStatusBannerContent.setBackgroundColor(backgroundColor);
        binding.itemlistStoryStatusText.setTextColor(textColor);
        binding.itemlistStoryStatusBorder.setBackgroundColor(borderColor);
        binding.itemlistStoryStatusOfflineIcon.setImageTintList(ColorStateList.valueOf(textColor));
        binding.itemlistStoryStatusSpinner.setIndicatorColor(textColor);
    }

    abstract String getSaveSearchFeedId();

}
