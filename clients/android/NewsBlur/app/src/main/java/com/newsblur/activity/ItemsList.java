package com.newsblur.activity;

import static com.newsblur.service.NbSyncManager.UPDATE_REBUILD;
import static com.newsblur.service.NbSyncManager.UPDATE_STATUS;
import static com.newsblur.service.NbSyncManager.UPDATE_STORY;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.ValueAnimator;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Trace;
import android.text.Editable;
import android.text.TextUtils;
import android.text.TextWatcher;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnKeyListener;
import android.view.ViewGroup;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.DecelerateInterpolator;
import android.widget.PopupMenu;

import androidx.activity.result.ActivityResult;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;
import androidx.lifecycle.ViewModelProvider;

import com.google.android.material.button.MaterialButton;
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
import com.newsblur.util.PrefConstants;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.ReadingActionListener;
import com.newsblur.util.Session;
import com.newsblur.util.SessionDataSource;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.UIUtils;
import com.newsblur.viewModel.ItemListViewModel;

import org.jetbrains.annotations.NotNull;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

import java.util.Locale;

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
    private static final long MILLIS_PER_DAY = 24L * 60L * 60L * 1000L;
    private static final int[] MARK_READ_CUTOFF_DAYS = new int[]{1, 3, 7, 14};
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
            binding.itemlistSearchContainer.setVisibility(View.VISIBLE);
        } else if (getIntent().getBooleanExtra(EXTRA_VISIBLE_SEARCH, false)) {
            binding.itemlistSearchContainer.setVisibility(View.VISIBLE);
            binding.itemlistSearchQuery.requestFocus();
        }

        binding.itemlistSearchQuery.setOnKeyListener(new OnKeyListener() {
            public boolean onKey(View v, int keyCode, KeyEvent event) {
                if ((keyCode == KeyEvent.KEYCODE_BACK) && (event.getAction() == KeyEvent.ACTION_DOWN)) {
                    hideStorySearch(true);
                    return true;
                }
                if ((keyCode == KeyEvent.KEYCODE_ENTER) && (event.getAction() == KeyEvent.ACTION_DOWN)) {
                    checkSearchQuery();
                    return true;
                }
                return false;
            }
        });
        setupStoryHeader();
        refreshStoryHeaderControls();
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
        applyStoryHeaderTheme();
        refreshStoryHeaderControls();
        updateStatusIndicators();
        if (itemSetFragment != null) {
            itemSetFragment.refreshLoadingIndicators();
        }
        // Reading activities almost certainly changed the read/unread state of some stories. Ensure
        // we reflect those changes promptly.
        itemSetFragment.hasUpdated();
    }

    public void refreshStoryHeaderControls() {
        if (binding == null) return;

        Menu menu = buildItemListMenuModel();
        MenuItem searchItem = menu.findItem(R.id.menu_search_stories);
        MenuItem markReadItem = menu.findItem(R.id.menu_mark_all_as_read);

        updateOptionsPillTitle(menu);
        binding.itemlistSearchPill.setVisibility(searchItem != null && searchItem.isVisible() ? View.VISIBLE : View.GONE);
        binding.itemlistMarkReadContainer.setVisibility(markReadItem != null && markReadItem.isVisible() ? View.VISIBLE : View.GONE);

        if (searchItem != null && !searchItem.isVisible() && isStorySearchVisible()) {
            hideStorySearch(true);
        } else {
            updateStorySearchPillState();
        }
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
        return prepareItemListMenuModel(menu);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        return contextMenuDelegate.onOptionsItemSelected(item, itemSetFragment, fs, binding.itemlistSearchQuery, getSaveSearchFeedId());
    }

    protected boolean prepareItemListMenuModel(Menu menu) {
        boolean showSavedSearch = !TextUtils.isEmpty(binding.itemlistSearchQuery.getText());
        return contextMenuDelegate.onPrepareMenuOptions(menu, fs, showSavedSearch);
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
                refreshStoryHeaderControls();
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

    public void toggleStorySearch() {
        if (isStorySearchVisible()) {
            hideStorySearch(true);
        } else {
            showStorySearch(true);
        }
    }

    private void setupStoryHeader() {
        binding.itemlistOptionsPill.setOnClickListener(view -> {
            View toolbar = findViewById(R.id.toolbar);
            if (toolbar instanceof androidx.appcompat.widget.Toolbar) {
                ((androidx.appcompat.widget.Toolbar) toolbar).showOverflowMenu();
            }
        });
        binding.itemlistSearchPill.setOnClickListener(view -> toggleStorySearch());
        binding.itemlistMarkReadButton.setOnClickListener(view ->
                feedUtils.markRead(this, fs, null, null, R.array.mark_all_read_options, this)
        );
        binding.itemlistMarkReadMoreButton.setOnClickListener(this::showMarkReadCutoffMenu);
        binding.itemlistStoryHeaderBar.addOnLayoutChangeListener((view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) ->
                updateStorySearchPillLabel()
        );
        binding.itemlistSearchQuery.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable s) {
                refreshStoryHeaderControls();
            }
        });
        applyStoryHeaderTheme();
        updateStorySearchPillLabel();
        updateStorySearchPillState();
    }

    private void showStorySearch(boolean requestFocus) {
        binding.itemlistSearchContainer.setVisibility(View.VISIBLE);
        updateStorySearchPillState();
        if (requestFocus) {
            binding.itemlistSearchQuery.requestFocus();
        }
    }

    private void hideStorySearch(boolean clearText) {
        if (clearText) {
            binding.itemlistSearchQuery.setText("");
        }
        binding.itemlistSearchContainer.setVisibility(View.GONE);
        binding.itemlistSearchQuery.clearFocus();
        updateStorySearchPillState();
        checkSearchQuery();
    }

    private boolean isStorySearchVisible() {
        return binding.itemlistSearchContainer.getVisibility() == View.VISIBLE;
    }

    private void updateStorySearchPillState() {
        StoryHeaderPalette palette = storyHeaderPalette();
        boolean isActive = isStorySearchVisible();
        applyPillStyle(
                binding.itemlistSearchPill,
                isActive ? palette.selectedBackgroundColor : palette.pillBackgroundColor,
                isActive ? palette.selectedBorderColor : palette.pillBorderColor,
                isActive ? palette.selectedTextColor : palette.pillTextColor
        );
    }

    private void updateStorySearchPillLabel() {
        if (binding.itemlistStoryHeaderBar.getWidth() <= 0) return;

        int compactThreshold = UIUtils.dp2px(this, 344);
        boolean useCompactLabel = binding.itemlistStoryHeaderBar.getWidth() < compactThreshold;
        binding.itemlistSearchPill.setText(useCompactLabel ? "" : getString(R.string.story_header_search));
    }

    private void updateOptionsPillTitle(Menu menu) {
        StoryOrder storyOrder = prefsRepo.getStoryOrder(fs);
        ReadFilter readFilter = prefsRepo.getReadFilter(fs);
        boolean showOrder = menu.findItem(R.id.menu_story_order) != null && menu.findItem(R.id.menu_story_order).isVisible();
        boolean showReadFilter = menu.findItem(R.id.menu_read_filter) != null && menu.findItem(R.id.menu_read_filter).isVisible();

        String orderText = storyOrder == StoryOrder.OLDEST ? getString(R.string.oldest) : getString(R.string.newest);
        String filterText = readFilter == ReadFilter.UNREAD ? "Unread" : "All";
        String title;
        if (showOrder && showReadFilter) {
            title = filterText + " \u00B7 " + orderText;
        } else if (showReadFilter) {
            title = filterText;
        } else if (showOrder) {
            title = orderText;
        } else {
            title = getString(R.string.story_header_options);
        }
        binding.itemlistOptionsPill.setText(title.toUpperCase(Locale.US));
        applyPillStyle(binding.itemlistOptionsPill, storyHeaderPalette().pillBackgroundColor, storyHeaderPalette().pillBorderColor, storyHeaderPalette().pillTextColor);
    }

    private void showMarkReadCutoffMenu(View anchor) {
        PopupMenu popupMenu = new PopupMenu(this, anchor);
        for (int i = 0; i < MARK_READ_CUTOFF_DAYS.length; i++) {
            int days = MARK_READ_CUTOFF_DAYS[i];
            popupMenu.getMenu().add(Menu.NONE, days, i, getResources().getQuantityString(R.plurals.story_header_mark_read_older_than_days, days, days));
        }
        popupMenu.setOnMenuItemClickListener(item -> {
            int days = item.getItemId();
            long olderThan = System.currentTimeMillis() - (days * MILLIS_PER_DAY);
            feedUtils.markRead(this, fs, olderThan, null, R.array.mark_older_read_options, this);
            return true;
        });
        popupMenu.show();
    }

    private Menu buildItemListMenuModel() {
        PopupMenu popupMenu = new PopupMenu(this, findViewById(R.id.toolbar));
        contextMenuDelegate.onCreateMenuOptions(popupMenu.getMenu(), popupMenu.getMenuInflater(), fs);
        prepareItemListMenuModel(popupMenu.getMenu());
        return popupMenu.getMenu();
    }

    private void applyStoryHeaderTheme() {
        StoryHeaderPalette palette = storyHeaderPalette();
        binding.itemlistStoryHeader.setBackgroundColor(palette.headerBackgroundColor);
        binding.itemlistSearchContainer.setBackgroundColor(palette.headerBackgroundColor);
        binding.itemlistMarkReadDivider.setBackgroundColor(palette.markReadDividerColor);

        applyPillStyle(binding.itemlistOptionsPill, palette.pillBackgroundColor, palette.pillBorderColor, palette.pillTextColor);
        updateStorySearchPillState();

        GradientDrawable markReadBackground = new GradientDrawable();
        markReadBackground.setShape(GradientDrawable.RECTANGLE);
        markReadBackground.setCornerRadius(UIUtils.dp2px(this, 14));
        markReadBackground.setColor(palette.markReadBackgroundColor);
        binding.itemlistMarkReadContainer.setBackground(markReadBackground);
        binding.itemlistMarkReadMoreButton.setColorFilter(ContextCompat.getColor(this, android.R.color.white));
        binding.itemlistMarkReadButton.setColorFilter(ContextCompat.getColor(this, android.R.color.white));
    }

    private void applyPillStyle(MaterialButton button, int backgroundColor, int borderColor, int textColor) {
        button.setBackgroundTintList(ColorStateList.valueOf(backgroundColor));
        button.setStrokeColor(ColorStateList.valueOf(borderColor));
        button.setStrokeWidth(UIUtils.dp2px(this, 1));
        button.setCornerRadius(UIUtils.dp2px(this, 14));
        button.setTextColor(textColor);
        button.setIconTint(ColorStateList.valueOf(textColor));
        button.setInsetTop(0);
        button.setInsetBottom(0);
    }

    private StoryHeaderPalette storyHeaderPalette() {
        PrefConstants.ThemeValue theme = prefsRepo.getSelectedTheme();
        if (theme == PrefConstants.ThemeValue.AUTO) {
            int nightModeFlags = getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK;
            theme = nightModeFlags == Configuration.UI_MODE_NIGHT_YES ? PrefConstants.ThemeValue.DARK : PrefConstants.ThemeValue.LIGHT;
        }

        if (theme == PrefConstants.ThemeValue.SEPIA) {
            return new StoryHeaderPalette(
                    ContextCompat.getColor(this, R.color.bar_background_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_background_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_border_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_text_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_selected_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_border_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_selected_text_sepia),
                    ContextCompat.getColor(this, R.color.premium_feature_red),
                    ContextCompat.getColor(this, R.color.story_status_offline_border_sepia)
            );
        } else if (theme == PrefConstants.ThemeValue.DARK) {
            return new StoryHeaderPalette(
                    ContextCompat.getColor(this, R.color.dark_bar_background),
                    ContextCompat.getColor(this, R.color.segmented_control_background_dark),
                    ContextCompat.getColor(this, R.color.segmented_control_border_dark),
                    ContextCompat.getColor(this, R.color.segmented_control_text_dark),
                    ContextCompat.getColor(this, R.color.segmented_control_selected_dark),
                    ContextCompat.getColor(this, R.color.segmented_control_border_dark),
                    ContextCompat.getColor(this, R.color.segmented_control_selected_text_dark),
                    ContextCompat.getColor(this, R.color.premium_feature_red),
                    ContextCompat.getColor(this, R.color.story_status_offline_border_dark)
            );
        } else if (theme == PrefConstants.ThemeValue.BLACK) {
            return new StoryHeaderPalette(
                    ContextCompat.getColor(this, R.color.black),
                    ContextCompat.getColor(this, R.color.segmented_control_background_black),
                    ContextCompat.getColor(this, R.color.segmented_control_border_black),
                    ContextCompat.getColor(this, R.color.segmented_control_text_black),
                    ContextCompat.getColor(this, R.color.segmented_control_selected_black),
                    ContextCompat.getColor(this, R.color.segmented_control_border_black),
                    ContextCompat.getColor(this, R.color.segmented_control_selected_text_black),
                    ContextCompat.getColor(this, R.color.premium_feature_red),
                    ContextCompat.getColor(this, R.color.story_status_offline_border_black)
            );
        }

        return new StoryHeaderPalette(
                ContextCompat.getColor(this, R.color.bar_background),
                ContextCompat.getColor(this, R.color.segmented_control_background_light),
                ContextCompat.getColor(this, R.color.segmented_control_border_light),
                ContextCompat.getColor(this, R.color.segmented_control_text_light),
                ContextCompat.getColor(this, R.color.segmented_control_selected_light),
                ContextCompat.getColor(this, R.color.segmented_control_border_light),
                ContextCompat.getColor(this, R.color.segmented_control_selected_text_light),
                ContextCompat.getColor(this, R.color.premium_feature_red),
                ContextCompat.getColor(this, R.color.story_status_offline_border_light)
        );
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
        refreshStoryHeaderControls();
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
        refreshStoryHeaderControls();
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

    private static class StoryHeaderPalette {
        final int headerBackgroundColor;
        final int pillBackgroundColor;
        final int pillBorderColor;
        final int pillTextColor;
        final int selectedBackgroundColor;
        final int selectedBorderColor;
        final int selectedTextColor;
        final int markReadBackgroundColor;
        final int markReadDividerColor;

        StoryHeaderPalette(
                int headerBackgroundColor,
                int pillBackgroundColor,
                int pillBorderColor,
                int pillTextColor,
                int selectedBackgroundColor,
                int selectedBorderColor,
                int selectedTextColor,
                int markReadBackgroundColor,
                int markReadDividerColor
        ) {
            this.headerBackgroundColor = headerBackgroundColor;
            this.pillBackgroundColor = pillBackgroundColor;
            this.pillBorderColor = pillBorderColor;
            this.pillTextColor = pillTextColor;
            this.selectedBackgroundColor = selectedBackgroundColor;
            this.selectedBorderColor = selectedBorderColor;
            this.selectedTextColor = selectedTextColor;
            this.markReadBackgroundColor = markReadBackgroundColor;
            this.markReadDividerColor = markReadDividerColor;
        }
    }

    abstract String getSaveSearchFeedId();

}
