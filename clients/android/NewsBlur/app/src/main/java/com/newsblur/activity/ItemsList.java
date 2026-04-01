package com.newsblur.activity;

import static com.newsblur.service.NbSyncManager.UPDATE_REBUILD;
import static com.newsblur.service.NbSyncManager.UPDATE_STATUS;
import static com.newsblur.service.NbSyncManager.UPDATE_STORY;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.ValueAnimator;
import android.content.Context;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
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
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.PopupMenu;
import android.widget.PopupWindow;

import androidx.activity.BackEventCompat;
import androidx.activity.OnBackPressedCallback;
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
import com.newsblur.delegate.ItemListMenuPopup;
import com.newsblur.fragment.ItemSetFragment;
import com.newsblur.service.SyncServiceState;
import com.newsblur.util.AppConstants;
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
import com.newsblur.util.StoryHeaderPillAppearanceResolver;
import com.newsblur.util.StoryHeaderOptionsTitleFormatter;
import com.newsblur.util.StoryHeaderPillLayoutDecider;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.TryFeedSessionResetter;
import com.newsblur.util.UIUtils;
import com.newsblur.viewModel.ItemListViewModel;

import org.jetbrains.annotations.NotNull;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

import java.lang.ref.WeakReference;
@AndroidEntryPoint
public abstract class ItemsList extends NbActivity implements ReadingActionListener {

    private static WeakReference<ItemsList> readingLaunchParentRef = new WeakReference<>(null);

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
    private static final long STORY_SEARCH_DEBOUNCE_MS = 350L;
    private static final long MILLIS_PER_DAY = 24L * 60L * 60L * 1000L;
    private static final int STORY_HEADER_COMPACT_PILL_HORIZONTAL_PADDING_DP = 8;
    private static final int[] MARK_READ_CUTOFF_DAYS = new int[]{1, 3, 7, 14};
    private static final DecelerateInterpolator STORY_STATUS_SHOW_INTERPOLATOR = new DecelerateInterpolator();
    private static final AccelerateInterpolator STORY_STATUS_HIDE_INTERPOLATOR = new AccelerateInterpolator();
    private static final DecelerateInterpolator STORY_LIST_SWIPE_INTERPOLATOR = new DecelerateInterpolator();
    private static final long STORY_LIST_SWIPE_SETTLE_DURATION_MS = 180L;
    private static final float STORY_LIST_SWIPE_ELEVATION_DP = 12f;

    protected ItemListViewModel viewModel;
    protected FeedSet fs;

    private ItemSetFragment itemSetFragment;
    protected ActivityItemslistBinding binding;
    private ItemListContextMenuDelegate contextMenuDelegate;
    @Nullable
    private SessionDataSource sessionDataSource;
    @Nullable
    private ValueAnimator storyStatusBannerAnimator;
    @Nullable
    private PopupWindow itemListMenuPopup;
    @Nullable
    private ItemListMenuPopup.Content itemListPopupContent;
    @Nullable
    private View interactiveSwipeSurface;
    @Nullable
    private Runnable storySearchRunnable;
    @Nullable
    private StoryHeaderPillAppearanceResolver.Appearance discoverPillExpandedAppearance;
    @Nullable
    private StoryHeaderPillAppearanceResolver.Appearance searchPillExpandedAppearance;
    private boolean updatingStoryHeaderPillLabels = false;
    private boolean storySearchRefreshInFlight = false;
    private boolean predictiveBackInProgress = false;
    private boolean suppressNextExitTransition = false;
    private boolean awaitingInitialFetchingBanner = false;
    private boolean fetchingBannerDelayElapsed = false;
    private final Handler storySearchHandler = new Handler(Looper.getMainLooper());
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

        if (shouldResetReadingSessionOnCreate()) {
            TryFeedSessionResetter.INSTANCE.reset(syncServiceState, dbHelper, fs);
        }

        // this is not strictly necessary, since our first refresh with the fs will swap in
        // the correct session, but that can be delayed by sync backup, so we try here to
        // reduce UI lag, or in case somehow we got redisplayed in a zero-story state
        feedUtils.prepareReadingSession(fs, false);
        if (getIntent().getBooleanExtra(EXTRA_WIDGET_STORY, false)) {
            String hash = (String) getIntent().getSerializableExtra(EXTRA_STORY_HASH);
            launchReadingActivity(fs, hash);
        } else if (prefsRepo.isAutoOpenFirstUnread()) {
            StateFilter intelState = prefsRepo.getStateFilter();
            if (dbHelper.getUnreadCount(fs, intelState) > 0) {
                launchReadingActivity(fs, Reading.FIND_FIRST_UNREAD);
            }
        }

        getWindow().setBackgroundDrawableResource(android.R.color.transparent);

        binding = ActivityItemslistBinding.inflate(getLayoutInflater());
        EdgeToEdgeUtil.applyView(this, binding);
        View toolbarSettingsButton = findViewById(R.id.toolbar_settings_button);
        if (toolbarSettingsButton != null) {
            toolbarSettingsButton.setOnClickListener(this::showItemListSettingsPopup);
        }

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
                return false;
            }
        });
        setupStoryHeader();
        refreshStoryHeaderControls();
        scheduleInitialFetchingBanner();
        setupOnBackPressed();
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
    protected boolean shouldUseTranslucentTheme() {
        return true;
    }

    protected boolean shouldResetReadingSessionOnCreate() {
        return false;
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
        boolean showDiscover = shouldShowDiscoverAction();
        MenuItem searchItem = menu.findItem(R.id.menu_search_stories);
        MenuItem markReadItem = menu.findItem(R.id.menu_mark_all_as_read);

        updateOptionsPillTitle(menu);
        binding.itemlistDiscoverPill.setVisibility(showDiscover ? View.VISIBLE : View.GONE);
        binding.itemlistSearchPill.setVisibility(searchItem != null && searchItem.isVisible() ? View.VISIBLE : View.GONE);
        binding.itemlistMarkReadContainer.setVisibility(markReadItem != null && markReadItem.isVisible() ? View.VISIBLE : View.GONE);
        updateStoryHeaderPillLabels();
        invalidateOptionsMenu();

        if (searchItem != null && !searchItem.isVisible() && isStorySearchVisible()) {
            hideStorySearch(true);
        } else {
            updateStorySearchLoadingIndicator();
            updateStorySearchPillState();
        }
    }

    @Override
    protected void onPause() {
        predictiveBackInProgress = false;
        setStorySearchRefreshInFlight(false);
        cancelPendingStorySearch();
        cancelPendingFetchingBanner();
        cancelStoryStatusBannerAnimation();
        dismissItemListMenuPopup();
        resetInteractiveStoryListSwipe(true);
        super.onPause();
        syncServiceState.addRecountCandidate(fs);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        return true;
    }

    @Override
    public boolean onPrepareOptionsMenu(Menu menu) {
        super.onPrepareOptionsMenu(menu);
        updateToolbarSettingsButtonVisibility();
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        if (item.getItemId() == R.id.menu_story_settings) {
            showItemListSettingsPopup(findViewById(R.id.toolbar));
            return true;
        }
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
            setStorySearchRefreshInFlight(false);
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
            setStorySearchRefreshInFlight(false);
            awaitingInitialFetchingBanner = false;
            fetchingBannerDelayElapsed = false;
            cancelPendingFetchingBanner();
        }

        updateStorySearchLoadingIndicator();
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
        discoverPillExpandedAppearance = captureStoryHeaderPillAppearance(binding.itemlistDiscoverPill);
        searchPillExpandedAppearance = captureStoryHeaderPillAppearance(binding.itemlistSearchPill);
        binding.itemlistDiscoverPill.setOnClickListener(view -> openDiscoverFeeds());
        binding.itemlistOptionsPill.setOnClickListener(this::showItemListMenuPopup);
        binding.itemlistSearchPill.setOnClickListener(view -> toggleStorySearch());
        binding.itemlistMarkReadButton.setOnClickListener(view ->
                feedUtils.markRead(this, fs, null, null, R.array.mark_all_read_options, this)
        );
        binding.itemlistMarkReadMoreButton.setOnClickListener(this::showMarkReadCutoffMenu);
        binding.itemlistClearSearchQuery.setOnClickListener(view -> {
            binding.itemlistSearchQuery.setText("");
            binding.itemlistSearchQuery.requestFocus();
        });
        binding.itemlistStoryHeaderBar.addOnLayoutChangeListener((view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) ->
                updateStoryHeaderPillLabels()
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
                setStorySearchRefreshInFlight(!TextUtils.equals(normalizeStorySearchQuery(s), fs.getSearchQuery()));
                updateStorySearchClearButton(s);
                refreshStoryHeaderControls();
                if (TextUtils.isEmpty(s)) {
                    runStorySearchNow();
                } else {
                    scheduleStorySearch();
                }
            }
        });
        binding.itemlistSearchQuery.setOnEditorActionListener((textView, actionId, event) -> {
            boolean isSearchAction =
                    actionId == EditorInfo.IME_ACTION_SEARCH ||
                    actionId == EditorInfo.IME_ACTION_DONE ||
                    ((event != null) &&
                     (event.getKeyCode() == KeyEvent.KEYCODE_ENTER) &&
                     (event.getAction() == KeyEvent.ACTION_DOWN));
            if (!isSearchAction) {
                return false;
            }
            runStorySearchNow();
            return true;
        });
        applyStoryHeaderTheme();
        updateStorySearchClearButton(binding.itemlistSearchQuery.getText());
        updateStorySearchLoadingIndicator();
        updateStoryHeaderPillLabels();
        updateStorySearchPillState();
    }

    private void showStorySearch(boolean requestFocus) {
        binding.itemlistSearchContainer.setVisibility(View.VISIBLE);
        updateStorySearchLoadingIndicator();
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
        updateStorySearchLoadingIndicator();
        updateStorySearchPillState();
        runStorySearchNow();
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

    private void updateStoryHeaderPillLabels() {
        if (updatingStoryHeaderPillLabels) return;
        if (binding.itemlistStoryHeaderBar.getWidth() <= 0) return;
        updatingStoryHeaderPillLabels = true;

        int availableWidth = binding.itemlistStoryHeaderBar.getWidth()
                - binding.itemlistStoryHeaderBar.getPaddingLeft()
                - binding.itemlistStoryHeaderBar.getPaddingRight();
        if (availableWidth <= 0) {
            updatingStoryHeaderPillLabels = false;
            return;
        }

        int optionsWidth = binding.itemlistOptionsPill.getVisibility() == View.VISIBLE
                ? measureDesiredWidth(binding.itemlistOptionsPill)
                : 0;
        StoryHeaderPillAppearanceResolver.Appearance discoverExpandedAppearance = getDiscoverPillExpandedAppearance();
        StoryHeaderPillAppearanceResolver.Appearance searchExpandedAppearance = getSearchPillExpandedAppearance();
        int markReadWidth = binding.itemlistMarkReadContainer.getVisibility() == View.VISIBLE
                ? measureDesiredWidth(binding.itemlistMarkReadContainer)
                : 0;
        int discoverFullWidth = binding.itemlistDiscoverPill.getVisibility() == View.VISIBLE
                ? measureDiscoverPillWidth(getString(R.string.story_header_related_sites), true, discoverExpandedAppearance)
                : 0;
        int discoverCompactWidth = binding.itemlistDiscoverPill.getVisibility() == View.VISIBLE
                ? measureDiscoverPillWidth("", false, discoverExpandedAppearance)
                : 0;
        int searchFullWidth = binding.itemlistSearchPill.getVisibility() == View.VISIBLE
                ? measureSearchPillWidth(getString(R.string.story_header_search), true, searchExpandedAppearance)
                : 0;
        int searchCompactWidth = binding.itemlistSearchPill.getVisibility() == View.VISIBLE
                ? measureSearchPillWidth("", false, searchExpandedAppearance)
                : 0;

        int discoverMargin = binding.itemlistDiscoverPill.getVisibility() == View.VISIBLE
                ? ((ViewGroup.MarginLayoutParams) binding.itemlistDiscoverPill.getLayoutParams()).getMarginEnd()
                : 0;
        int searchMargin = binding.itemlistSearchPill.getVisibility() == View.VISIBLE
                ? ((ViewGroup.MarginLayoutParams) binding.itemlistSearchPill.getLayoutParams()).getMarginStart()
                : 0;
        int markReadMargin = binding.itemlistMarkReadContainer.getVisibility() == View.VISIBLE
                ? ((ViewGroup.MarginLayoutParams) binding.itemlistMarkReadContainer.getLayoutParams()).getMarginStart()
                : 0;

        StoryHeaderPillLayoutDecider.Decision decision = StoryHeaderPillLayoutDecider.decide(
                availableWidth,
                optionsWidth,
                markReadWidth,
                discoverFullWidth,
                discoverCompactWidth,
                searchFullWidth,
                searchCompactWidth,
                discoverMargin,
                searchMargin,
                markReadMargin,
                binding.itemlistDiscoverPill.getVisibility() == View.VISIBLE,
                binding.itemlistSearchPill.getVisibility() == View.VISIBLE
        );

        if (binding.itemlistDiscoverPill.getVisibility() == View.VISIBLE) {
            applyStoryHeaderPillLabel(
                    binding.itemlistDiscoverPill,
                    getString(R.string.story_header_related_sites),
                    decision.showDiscoverText(),
                    discoverExpandedAppearance
            );
        }
        if (binding.itemlistSearchPill.getVisibility() == View.VISIBLE) {
            applyStoryHeaderPillLabel(
                    binding.itemlistSearchPill,
                    getString(R.string.story_header_search),
                    decision.showSearchText(),
                    searchExpandedAppearance
            );
        }
        // Reset the guard after the next layout pass to prevent the layout change
        // listener from re-entering this method and undoing the text we just set.
        binding.itemlistStoryHeaderBar.post(() -> updatingStoryHeaderPillLabels = false);
    }

    private int measureSearchPillWidth(
            CharSequence title,
            boolean showText,
            StoryHeaderPillAppearanceResolver.Appearance expandedAppearance
    ) {
        return measureStoryHeaderPillWidth(binding.itemlistSearchPill, title, showText, expandedAppearance);
    }

    private int measureDiscoverPillWidth(
            CharSequence title,
            boolean showText,
            StoryHeaderPillAppearanceResolver.Appearance expandedAppearance
    ) {
        return measureStoryHeaderPillWidth(binding.itemlistDiscoverPill, title, showText, expandedAppearance);
    }

    private int measureStoryHeaderPillWidth(
            MaterialButton button,
            CharSequence title,
            boolean showText,
            StoryHeaderPillAppearanceResolver.Appearance expandedAppearance
    ) {
        CharSequence previousTitle = button.getText();
        StoryHeaderPillAppearanceResolver.Appearance previousAppearance = captureStoryHeaderPillAppearance(button);
        applyStoryHeaderPillLabel(button, title, showText, expandedAppearance);
        int width = measureDesiredWidth(button);
        button.setText(previousTitle);
        applyStoryHeaderPillAppearance(button, previousAppearance);
        return width;
    }

    private void applyStoryHeaderPillLabel(
            MaterialButton button,
            CharSequence title,
            boolean showText,
            StoryHeaderPillAppearanceResolver.Appearance expandedAppearance
    ) {
        button.setText(showText ? title : "");
        if (showText) {
            button.setIconPadding(expandedAppearance.iconPadding());
        } else {
            button.setIconPadding(0);
            int compactPadding = UIUtils.dp2px(this, STORY_HEADER_COMPACT_PILL_HORIZONTAL_PADDING_DP);
            button.setPaddingRelative(compactPadding, 0, compactPadding, 0);
        }
    }

    private void applyStoryHeaderPillAppearance(
            MaterialButton button,
            StoryHeaderPillAppearanceResolver.Appearance appearance
    ) {
        button.setIconPadding(appearance.iconPadding());
    }

    private StoryHeaderPillAppearanceResolver.Appearance captureStoryHeaderPillAppearance(MaterialButton button) {
        return new StoryHeaderPillAppearanceResolver.Appearance(
                button.getPaddingStart(),
                button.getPaddingTop(),
                button.getPaddingEnd(),
                button.getPaddingBottom(),
                button.getIconPadding()
        );
    }

    private StoryHeaderPillAppearanceResolver.Appearance getDiscoverPillExpandedAppearance() {
        if (discoverPillExpandedAppearance == null) {
            discoverPillExpandedAppearance = captureStoryHeaderPillAppearance(binding.itemlistDiscoverPill);
        }
        return discoverPillExpandedAppearance;
    }

    private StoryHeaderPillAppearanceResolver.Appearance getSearchPillExpandedAppearance() {
        if (searchPillExpandedAppearance == null) {
            searchPillExpandedAppearance = captureStoryHeaderPillAppearance(binding.itemlistSearchPill);
        }
        return searchPillExpandedAppearance;
    }

    private int measureDesiredWidth(View view) {
        int widthSpec = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED);
        int heightSpec;
        ViewGroup.LayoutParams layoutParams = view.getLayoutParams();
        if (layoutParams != null && layoutParams.height > 0) {
            heightSpec = View.MeasureSpec.makeMeasureSpec(layoutParams.height, View.MeasureSpec.EXACTLY);
        } else {
            heightSpec = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED);
        }
        view.measure(widthSpec, heightSpec);
        return view.getMeasuredWidth();
    }

    private void updateOptionsPillTitle(Menu menu) {
        StoryOrder storyOrder = prefsRepo.getStoryOrder(fs);
        ReadFilter readFilter = prefsRepo.getReadFilter(fs);
        boolean showOrder = menu.findItem(R.id.menu_story_order) != null && menu.findItem(R.id.menu_story_order).isVisible();
        boolean showReadFilter = menu.findItem(R.id.menu_read_filter) != null && menu.findItem(R.id.menu_read_filter).isVisible();

        String orderText = storyOrder == StoryOrder.OLDEST ? getString(R.string.oldest) : getString(R.string.newest);
        String filterText = readFilter == ReadFilter.UNREAD ? getString(R.string.state_unread) : getString(R.string.state_all);
        String title = StoryHeaderOptionsTitleFormatter.INSTANCE.format(filterText, orderText, getString(R.string.story_header_options), showReadFilter, showOrder);
        binding.itemlistOptionsPill.setText(title);
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

    private void showItemListMenuPopup(View anchor) {
        showItemListPopup(anchor, ItemListMenuPopup.Content.VISUAL);
    }

    private void showItemListSettingsPopup(View anchor) {
        showItemListPopup(anchor, ItemListMenuPopup.Content.ACTIONS);
    }

    private void updateToolbarSettingsButtonVisibility() {
        View settingsButton = findViewById(R.id.toolbar_settings_button);
        if (settingsButton == null) {
            return;
        }
        boolean hasVisibleActions = ItemListMenuPopup.hasVisibleActions(buildItemListMenuModel());
        settingsButton.setVisibility(hasVisibleActions ? View.VISIBLE : View.INVISIBLE);
    }

    private void showItemListPopup(View anchor, ItemListMenuPopup.Content content) {
        Menu menuModel = buildItemListMenuModel();
        if ((content == ItemListMenuPopup.Content.ACTIONS) && !ItemListMenuPopup.hasVisibleActions(menuModel)) {
            dismissItemListMenuPopup();
            return;
        }

        if (itemListMenuPopup != null && itemListMenuPopup.isShowing()) {
            if (content == itemListPopupContent) {
                dismissItemListMenuPopup();
                return;
            }
            dismissItemListMenuPopup();
        }

        PopupWindow popup =
                new ItemListMenuPopup(this, new ItemListMenuPopup.Controller() {
                    @Override
                    public Menu buildMenuModel() {
                        return buildItemListMenuModel();
                    }

                    @Override
                    public boolean onMenuItemSelected(int itemId) {
                        MenuItem menuItem = buildItemListMenuModel().findItem(itemId);
                        return menuItem != null && ItemsList.this.onOptionsItemSelected(menuItem);
                    }
                }, content).show(anchor);
        popup.setOnDismissListener(() -> {
            if (itemListMenuPopup == popup) {
                itemListMenuPopup = null;
                itemListPopupContent = null;
            }
        });
        itemListMenuPopup = popup;
        itemListPopupContent = content;
    }

    private void dismissItemListMenuPopup() {
        if (itemListMenuPopup != null) {
            itemListMenuPopup.dismiss();
            itemListMenuPopup = null;
        }
        itemListPopupContent = null;
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

        applyPillStyle(binding.itemlistDiscoverPill, palette.pillBackgroundColor, palette.pillBorderColor, palette.pillTextColor);
        applyPillStyle(binding.itemlistOptionsPill, palette.pillBackgroundColor, palette.pillBorderColor, palette.pillTextColor);
        updateStorySearchPillState();

        GradientDrawable markReadBackground = new GradientDrawable();
        markReadBackground.setShape(GradientDrawable.RECTANGLE);
        markReadBackground.setCornerRadius(UIUtils.dp2px(this, 14));
        markReadBackground.setColor(palette.markReadBackgroundColor);
        markReadBackground.setStroke(UIUtils.dp2px(this, 1), palette.markReadDividerColor);
        binding.itemlistMarkReadContainer.setBackground(markReadBackground);
        binding.itemlistMarkReadMoreButton.setColorFilter(palette.pillTextColor);
        binding.itemlistMarkReadButton.setColorFilter(palette.pillTextColor);
    }

    public boolean shouldShowDiscoverAction() {
        if (fs == null) return false;
        if (fs.getSearchQuery() != null) return false;
        if (fs.isFilterSaved()) return false;
        if (fs.isSingleNormal()) return true;
        return fs.isFolder() && !AppConstants.ROOT_FOLDER.equals(fs.getFolderName());
    }

    public void openDiscoverFeeds() {
        if (!shouldShowDiscoverAction()) return;

        if (fs.isSingleNormal()) {
            String feedId = fs.getSingleFeed();
            com.newsblur.domain.Feed sourceFeed = dbHelper.getFeed(feedId);
            if (sourceFeed != null) {
                DiscoverFeedsActivity.startForFeed(this, sourceFeed);
            } else {
                DiscoverFeedsActivity.startForFeed(this, feedId);
            }
        } else if (fs.isFolder()) {
            DiscoverFeedsActivity.startForFeeds(this, fs.getAllFeeds());
        }
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
        PrefConstants.ThemeValue theme = prefsRepo.getResolvedTheme(this);

        if (theme == PrefConstants.ThemeValue.SEPIA) {
            return new StoryHeaderPalette(
                    ContextCompat.getColor(this, R.color.bar_background_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_background_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_border_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_text_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_selected_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_border_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_selected_text_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_background_sepia),
                    ContextCompat.getColor(this, R.color.segmented_control_border_sepia)
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
                    ContextCompat.getColor(this, R.color.segmented_control_background_dark),
                    ContextCompat.getColor(this, R.color.segmented_control_border_dark)
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
                    ContextCompat.getColor(this, R.color.segmented_control_background_black),
                    ContextCompat.getColor(this, R.color.segmented_control_border_black)
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
                ContextCompat.getColor(this, R.color.segmented_control_background_light),
                ContextCompat.getColor(this, R.color.segmented_control_border_light)
        );
    }

    private void scheduleStorySearch() {
        cancelPendingStorySearch();
        storySearchRunnable = this::checkSearchQuery;
        storySearchHandler.postDelayed(storySearchRunnable, STORY_SEARCH_DEBOUNCE_MS);
    }

    private void cancelPendingStorySearch() {
        if (storySearchRunnable != null) {
            storySearchHandler.removeCallbacks(storySearchRunnable);
            storySearchRunnable = null;
        }
    }

    private void runStorySearchNow() {
        cancelPendingStorySearch();
        checkSearchQuery();
    }

    @Nullable
    private String normalizeStorySearchQuery(@Nullable CharSequence query) {
        if (query == null) {
            return null;
        }
        String normalizedQuery = query.toString().trim();
        return normalizedQuery.isEmpty() ? null : normalizedQuery;
    }

    private void updateStorySearchClearButton(@Nullable CharSequence query) {
        binding.itemlistClearSearchQuery.setVisibility(TextUtils.isEmpty(query) ? View.GONE : View.VISIBLE);
    }

    private void setStorySearchRefreshInFlight(boolean isInFlight) {
        storySearchRefreshInFlight = isInFlight;
        updateStorySearchLoadingIndicator();
    }

    private void updateStorySearchLoadingIndicator() {
        binding.itemlistSearchProgress.setVisibility(
                storySearchRefreshInFlight && isStorySearchVisible() ? View.VISIBLE : View.GONE
        );
    }

    private void restoreStorySearchFieldFocus(int selectionEnd) {
        binding.itemlistSearchQuery.post(() -> {
            if (!isStorySearchVisible()) {
                return;
            }
            binding.itemlistSearchQuery.requestFocus();
            Editable query = binding.itemlistSearchQuery.getText();
            int safeSelectionEnd = Math.max(0, Math.min(selectionEnd, query.length()));
            binding.itemlistSearchQuery.setSelection(safeSelectionEnd);
            InputMethodManager inputMethodManager = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
            if (inputMethodManager != null) {
                inputMethodManager.showSoftInput(binding.itemlistSearchQuery, InputMethodManager.SHOW_IMPLICIT);
            }
        });
    }

    private void checkSearchQuery() {
        storySearchRunnable = null;
        boolean shouldRestoreFocus = isStorySearchVisible() && binding.itemlistSearchQuery.hasFocus();
        int selectionEnd = shouldRestoreFocus ? binding.itemlistSearchQuery.getSelectionEnd() : -1;
        String q = normalizeStorySearchQuery(binding.itemlistSearchQuery.getText());
        if (q == null) {
            updateFleuron(false);
        } else if (!prefsRepo.hasSubscription()) {
            setStorySearchRefreshInFlight(false);
            updateFleuron(true);
            return;
        }

        String oldQuery = fs.getSearchQuery();
        fs.setSearchQuery(q);
        boolean queryChanged = !TextUtils.equals(q, oldQuery);
        if (queryChanged) {
            feedUtils.prepareReadingSession(fs, true);
            triggerSync();
            scheduleInitialFetchingBanner();
            itemSetFragment.resetEmptyState();
            itemSetFragment.hasUpdated();
            itemSetFragment.scrollToTop();
        } else {
            setStorySearchRefreshInFlight(false);
        }
        refreshStoryHeaderControls();
        if (shouldRestoreFocus) {
            restoreStorySearchFieldFocus(selectionEnd);
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
        refreshStoryHeaderControls();
    }

    public void startReadingActivity(FeedSet feedSet, String storyHash) {
        launchReadingActivity(feedSet, storyHash);
    }

    public void animateBackToFeedListFromReading() {
        beginInteractiveStoryListSwipe();
        completeInteractiveStoryListSwipe();
    }

    @Nullable
    public static ItemsList peekReadingLaunchParent() {
        return readingLaunchParentRef.get();
    }

    private void launchReadingActivity(FeedSet feedSet, String storyHash) {
        readingLaunchParentRef = new WeakReference<>(this);
        UIUtils.startReadingActivity(this, feedSet, storyHash, readingActivityLaunch);
    }

    public void beginInteractiveStoryListSwipe() {
        View surface = getInteractiveSwipeSurface();
        surface.animate().cancel();
        surface.setTranslationZ(UIUtils.dp2px(this, STORY_LIST_SWIPE_ELEVATION_DP));
    }

    public void updateInteractiveStoryListSwipe(float offsetPx) {
        View surface = getInteractiveSwipeSurface();
        float clampedOffset = Math.max(0f, offsetPx);
        int width = surface.getWidth();
        if (width > 0) {
            clampedOffset = Math.min(clampedOffset, width);
        }
        surface.setTranslationX(clampedOffset);
        surface.setTranslationZ(clampedOffset > 0f ? UIUtils.dp2px(this, STORY_LIST_SWIPE_ELEVATION_DP) : 0f);
    }

    public void cancelInteractiveStoryListSwipe() {
        animateInteractiveStoryListSwipe(0f, false);
    }

    public void completeInteractiveStoryListSwipe() {
        View surface = getInteractiveSwipeSurface();
        float targetTranslation = surface.getWidth() > 0 ? surface.getWidth() : getResources().getDisplayMetrics().widthPixels;
        animateInteractiveStoryListSwipe(targetTranslation, true);
    }

    protected boolean interceptBackPress(boolean isGestureNavigation) {
        return false;
    }

    protected boolean shouldHandlePredictiveBack() {
        return true;
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
        predictiveBackInProgress = false;
        cancelPendingFetchingBanner();
        cancelStoryStatusBannerAnimation();
        super.finish();
        if (suppressNextExitTransition) {
            PendingTransitionUtils.overrideNoExitTransition(this);
        } else {
            PendingTransitionUtils.overrideExitTransition(this);
        }
        suppressNextExitTransition = false;
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

    private void setupOnBackPressed() {
        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackStarted(@NonNull BackEventCompat backEvent) {
                predictiveBackInProgress = supportsPredictiveStoryListBack()
                        && isInteractiveStoryListBackEnabled()
                        && shouldHandlePredictiveBack()
                        && backEvent.getSwipeEdge() == BackEventCompat.EDGE_LEFT;
                if (predictiveBackInProgress) {
                    beginInteractiveStoryListSwipe();
                }
            }

            @Override
            public void handleOnBackProgressed(@NonNull BackEventCompat backEvent) {
                if (!predictiveBackInProgress) return;
                updateInteractiveStoryListSwipe(backEvent.getProgress() * getInteractiveSwipeSurface().getWidth());
            }

            @Override
            public void handleOnBackCancelled() {
                if (!predictiveBackInProgress) return;
                predictiveBackInProgress = false;
                cancelInteractiveStoryListSwipe();
            }

            @Override
            public void handleOnBackPressed() {
                predictiveBackInProgress = false;
                View surface = getInteractiveSwipeSurface();
                boolean isGestureNavigation = surface.getTranslationX() > 0f;
                if (interceptBackPress(isGestureNavigation)) {
                    if (isGestureNavigation) {
                        cancelInteractiveStoryListSwipe();
                    }
                    return;
                }
                if (isGestureNavigation) {
                    completeInteractiveStoryListSwipe();
                } else {
                    finish();
                }
            }
        });
    }

    private void animateInteractiveStoryListSwipe(float targetTranslationX, boolean finishWhenComplete) {
        View surface = getInteractiveSwipeSurface();
        surface.animate()
                .translationX(targetTranslationX)
                .setDuration(STORY_LIST_SWIPE_SETTLE_DURATION_MS)
                .setInterpolator(STORY_LIST_SWIPE_INTERPOLATOR)
                .withEndAction(() -> {
                    if (finishWhenComplete) {
                        suppressNextExitTransition = true;
                        finish();
                    } else {
                        resetInteractiveStoryListSwipe(false);
                    }
                })
                .start();
    }

    private View getInteractiveSwipeSurface() {
        if (interactiveSwipeSurface == null) {
            interactiveSwipeSurface = findViewById(android.R.id.content);
        }
        return interactiveSwipeSurface;
    }

    private boolean isInteractiveStoryListBackEnabled() {
        return binding != null && !isTaskRoot() && !isFinishing();
    }

    @Override
    protected void onDestroy() {
        if (readingLaunchParentRef.get() == this) {
            readingLaunchParentRef.clear();
        }
        super.onDestroy();
    }

    private boolean supportsPredictiveStoryListBack() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE;
    }

    private void resetInteractiveStoryListSwipe(boolean cancelAnimation) {
        View surface = getInteractiveSwipeSurface();
        if (cancelAnimation) {
            surface.animate().cancel();
        }
        surface.setTranslationX(0f);
        surface.setTranslationZ(0f);
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
