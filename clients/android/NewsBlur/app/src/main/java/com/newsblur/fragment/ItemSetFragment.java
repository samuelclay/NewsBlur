package com.newsblur.fragment;

import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.os.Bundle;
import android.os.Parcelable;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver.OnGlobalLayoutListener;
import android.view.VelocityTracker;
import android.view.ViewConfiguration;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.NbActivity;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.database.StoryViewAdapter;
import com.newsblur.databinding.FragmentItemgridBinding;
import com.newsblur.databinding.RowFleuronBinding;
import com.newsblur.di.IconLoader;
import com.newsblur.di.ThumbnailLoader;
import com.newsblur.domain.Story;
import com.newsblur.preference.PrefsRepo;
import com.newsblur.service.SyncServiceState;
import com.newsblur.util.CursorFilters;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.GestureAction;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.SpacingStyle;
import com.newsblur.util.StoryListStyle;
import com.newsblur.util.ThumbnailStyle;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.util.ViewUtils;
import com.newsblur.viewModel.StoriesViewModel;

import org.jetbrains.annotations.NotNull;

import java.util.Collections;
import java.util.List;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class ItemSetFragment extends NbFragment {
    private static final float STORY_LIST_BACK_GESTURE_TRIGGER_RATIO = 0.33f;
    private static final float STORY_LIST_BACK_GESTURE_DIRECTION_RATIO = 1.2f;

    @Inject
    FeedUtils feedUtils;

    @Inject
    BlurDatabaseHelper dbHelper;

    @Inject
    @IconLoader
    ImageLoader iconLoader;

    @Inject
    @ThumbnailLoader
    ImageLoader thumbnailLoader;

    @Inject
    PrefsRepo prefsRepo;

    @Inject
    SyncServiceState syncServiceState;

    private static final String BUNDLE_GRIDSTATE = "gridstate";

    private boolean dataSeenYet = false;

    /**
     * Flag used to ensure that when the adapter resumes,
     * it omits any new stories that would disrupt the current order and cause the list to
     * unexpectedly jump, thereby preserving the scroll position. This flag specifically helps
     * manage the insertion of new stories that have been backfilled according to their timestamps.
     */
    private boolean skipBackFillingStories = false;

    private int itemGridWidthPx = 0;
    private int columnCount;

    private final static int GRID_SPACING_DP = 5;
    private int gridSpacingPx;

    private GridLayoutManager layoutManager;
    private StoryViewAdapter adapter;
    // an optional pending scroll state to restore.
    private Parcelable gridState;

    // loading indicator for when stories are absent or stale (at top of list)
    // R.id.top_loading_throb

    // the fleuron has padding that can't be calculated until after layout, but only changes
    // rarely thereafter
    private boolean fleuronResized = false;

    // de-dupe the massive stream of scrolling data to auto-mark read
    private int lastAutoMarkIndex = -1;

    public int indexOfLastUnread = -1;
    public boolean fullFlingComplete = false;

    private FragmentItemgridBinding binding;
    private RowFleuronBinding fleuronBinding;
    private StoriesViewModel storiesViewModel;

    public static ItemSetFragment newInstance() {
        ItemSetFragment fragment = new ItemSetFragment();
        Bundle arguments = new Bundle();
        fragment.setArguments(arguments);
        return fragment;
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        storiesViewModel = new ViewModelProvider(this).get(StoriesViewModel.class);
    }

    @Override
    public void onPause() {
        // a pause/resume cycle will depopulate and repopulate the list and trigger bad scroll
        // readings and cause zero-index refreshes, wasting massive cycles. hold the refresh logic
        // until the loaders reset
        dataSeenYet = false;
        skipBackFillingStories = true;
        super.onPause();
    }

    @Override
    public void onResume() {
        super.onResume();
        fleuronResized = false;
        updateLoadingIndicators();
    }

    @Override
    public void onViewStateRestored(Bundle savedInstanceState) {
        super.onViewStateRestored(savedInstanceState);
        if (savedInstanceState == null) return;
        gridState = savedInstanceState.getParcelable(BUNDLE_GRIDSTATE);
        // dont actually re-use the state yet, the adapter probably doesn't have any data
        // and won't know how to scroll. swapCursor() will pass this to the adapter when
        // data are ready.
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View v = inflater.inflate(R.layout.fragment_itemgrid, container, false);
        binding = FragmentItemgridBinding.bind(v);
        View fleuronView = inflater.inflate(R.layout.row_fleuron, null);
        fleuronBinding = RowFleuronBinding.bind(fleuronView);

        // disable the throbbers if animations are going to have a zero time scale
        boolean isDisableAnimations = ViewUtils.isPowerSaveMode(requireContext());

        binding.topLoadingIndicator.setEnabled(!isDisableAnimations);

        fleuronBinding.getRoot().setVisibility(View.INVISIBLE);
        fleuronBinding.containerSubscribe.setOnClickListener(view -> UIUtils.startSubscriptionActivity(requireContext()));
        fleuronBinding.buttonUpgrade.setOnClickListener(view -> UIUtils.startSubscriptionActivity(requireContext()));
        styleUpgradeBanner();

        binding.itemgridfragmentGrid.getViewTreeObserver().addOnGlobalLayoutListener(new OnGlobalLayoutListener() {
            @Override
            public void onGlobalLayout() {
                itemGridWidthPx = binding.itemgridfragmentGrid.getMeasuredWidth();
                binding.itemgridfragmentGrid.getViewTreeObserver().removeOnGlobalLayoutListener(this);
                updateListStyle();
            }
        });

        StoryListStyle listStyle = prefsRepo.getStoryListStyle(getFeedSet());

        calcColumnCount(listStyle);
        layoutManager = new GridLayoutManager(getActivity(), columnCount);
        binding.itemgridfragmentGrid.setLayoutManager(layoutManager);
        setupAnimSpeeds();

        calcGridSpacing(listStyle);
        binding.itemgridfragmentGrid.addItemDecoration(new RecyclerView.ItemDecoration() {
            @Override
            public void getItemOffsets(Rect outRect, View view, RecyclerView parent, RecyclerView.State state) {
                outRect.set(gridSpacingPx, gridSpacingPx, gridSpacingPx, gridSpacingPx);
            }
        });

        adapter = new StoryViewAdapter(((NbActivity) getActivity()), getFeedSet(), listStyle, iconLoader, thumbnailLoader, feedUtils, prefsRepo, getOnStoryClickListener());
        adapter.addFooterView(fleuronBinding.getRoot());
        binding.itemgridfragmentGrid.setAdapter(adapter);

        // the layout manager needs to know that the footer rows span all the way across
        layoutManager.setSpanSizeLookup(new GridLayoutManager.SpanSizeLookup() {
            @Override
            public int getSpanSize(int position) {
                switch (adapter.getItemViewType(position)) {
                    case StoryViewAdapter.VIEW_TYPE_FOOTER:
                        return columnCount;
                    default:
                        return 1;
                }
            }
        });

        binding.itemgridfragmentGrid.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrolled(@NonNull RecyclerView recyclerView, int dx, int dy) {
                ItemSetFragment.this.onScrolled(dy);
            }
        });
        binding.itemgridfragmentGrid.addOnItemTouchListener(new StoryListBackTouchListener());

        return v;
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        storiesViewModel.getActiveStories().observe(getViewLifecycleOwner(), this::setStories);

        FeedSet fs = getFeedSet();
        if (fs == null) {
            com.newsblur.util.Log.e(this.getClass().getName(), "can't create fragment, no feedset ready");
            // this is probably happening in a finalisation cycle or during a crash, pop the activity stack
            try {
                getActivity().finish();
            } catch (Exception ignored) {
            }
        }
    }

    private void setStories(StoriesViewModel.@NotNull StoryBatch storyBatch) {
        if (!dbHelper.isFeedSetReady(getFeedSet())) {
            com.newsblur.util.Log.i(this.getClass().getName(), "stale load");
            updateAdapter(Collections.emptyList(), storyBatch.getLoadId());
            triggerRefresh(1, null);
        } else {
            dataSeenYet = true;
            com.newsblur.util.Log.d(this.getClass().getName(), "loaded stories count: ${batch.stories.size}");
            updateAdapter(storyBatch.getStories(), storyBatch.getLoadId());
            if (storyBatch.getStories().isEmpty()) {
                triggerRefresh(1, 0);
            }
            storyThawCompleted(storyBatch.getIndexOfLastUnread());
        }
        updateLoadingIndicators();
        ItemsList activity = (ItemsList) getActivity();
        if (activity != null) {
            activity.refreshStoryStatusIndicators();
        }
    }

    protected void triggerRefresh(int desiredStoryCount, Integer totalSeen) {
        // ask the sync service for as many stories as we want
        FeedSet fs = getFeedSet();
        if (fs != null) {
            boolean gotSome = syncServiceState.requestMoreForFeed(fs, desiredStoryCount, totalSeen);
            // if the service thinks it can get more, or if we haven't even seen a cursor yet, start the service
            if (gotSome || (totalSeen == null)) triggerSync();
        }
    }

    /**
     * Indicate that the DB was cleared.
     */
    public void resetEmptyState() {
        updateAdapter(Collections.emptyList(), -1L);
        dataSeenYet = false;
        updateLoadingIndicators();
    }

    /**
     * A calback for our adapter that async thaws the story list so the fragment can have
     * some info about the story list when it is ready.
     */
    public void storyThawCompleted(int indexOfLastUnread) {
        this.indexOfLastUnread = (indexOfLastUnread >= 0) ? adapter.getDisplayPositionForStoryIndex(indexOfLastUnread) : -1;
        this.fullFlingComplete = false;
        // we don't actually calculate list speed until it has some stories
        setupAnimSpeeds();
    }

    public void scrollToTop() {
        layoutManager.scrollToPositionWithOffset(0, 0);
    }

    public void scrollToPosition(int position) {
        int layoutPosition = adapter.getDisplayPositionForStoryIndex(position);
        int layoutTotalPositions = layoutManager.getItemCount() - 1;
        if (layoutPosition > 0 && layoutPosition <= layoutTotalPositions) {
            layoutManager.scrollToPosition(layoutPosition);
        }
    }

    public void scrollToStoryHashIfOffScreen(@Nullable String storyHash) {
        int layoutPosition = adapter.getDisplayPositionForStoryHash(storyHash);
        int firstVisiblePosition = layoutManager.findFirstVisibleItemPosition();
        int lastVisiblePosition = layoutManager.findLastVisibleItemPosition();

        if (ReturnedStoryScrollDecider.shouldScrollToReturnedStory(layoutPosition, firstVisiblePosition, lastVisiblePosition)) {
            layoutManager.scrollToPosition(layoutPosition);
        }
    }

    protected FeedSet getFeedSet() {
        return ((ItemsList) requireActivity()).getFeedSet();
    }

    public void hasUpdated() {
        FeedSet fs = getFeedSet();
        if (isAdded() && fs != null) {
            storiesViewModel.loadActiveStories(fs, new CursorFilters(prefsRepo, fs));
        }
    }

    public void refreshLoadingIndicators() {
        if (!isAdded() || binding == null) return;
        updateLoadingIndicators();
    }

    public boolean hasStories() {
        return (adapter != null) && (adapter.getRawStoryCount() > 0);
    }

    private void updateAdapter(@NonNull List<Story> stories, Long loadId) {
        adapter.submitStories(stories, loadId, binding.itemgridfragmentGrid, gridState, skipBackFillingStories);
        gridState = null;
        adapter.updateFeedSet(getFeedSet());

        if (stories.isEmpty()) {
            binding.emptyView.setVisibility(View.VISIBLE);
        } else {
            binding.emptyView.setVisibility(View.INVISIBLE);
        }

        ensureSufficientStories();
    }

    private void updateLoadingIndicators() {
        calcFleuronPadding();
        boolean hasStories = hasStories();
        boolean isOffline = !NetworkUtils.isOnline(requireContext());
        boolean waitingForApiResult = !hasStories && !syncServiceState.isFeedSetExhausted(getFeedSet());

        if (dataSeenYet && adapter.getRawStoryCount() > 0 && UIUtils.needsSubscriptionAccess(getFeedSet(), prefsRepo)) {
            fleuronBinding.getRoot().setVisibility(View.VISIBLE);
            fleuronBinding.containerSubscribe.setVisibility(View.VISIBLE);
            updateUpgradeBannerText();
            binding.topLoadingIndicator.setVisibility(View.INVISIBLE);
            fleuronResized = false;
            return;
        }

        if ((!dataSeenYet) || syncServiceState.isFeedSetSyncing(getFeedSet()) || waitingForApiResult) {
            binding.emptyViewText.setText(R.string.empty_list_view_loading);
            binding.emptyViewText.setTypeface(binding.emptyViewText.getTypeface(), Typeface.NORMAL);
            binding.emptyViewText.setAlpha(0.4f);
            binding.emptyViewImage.setVisibility(View.INVISIBLE);

            if (isOffline || hasStories || syncServiceState.isFeedSetStoriesFresh(getFeedSet())) {
                binding.topLoadingIndicator.setVisibility(View.INVISIBLE);
            } else {
                binding.topLoadingIndicator.setVisibility(View.VISIBLE);
            }
            fleuronBinding.getRoot().setVisibility(View.INVISIBLE);
        } else {
            ReadFilter readFilter = prefsRepo.getReadFilter(getFeedSet());
            if (readFilter == ReadFilter.UNREAD) {
                binding.emptyViewText.setText(R.string.empty_list_view_no_stories_unread);
            } else {
                binding.emptyViewText.setText(R.string.empty_list_view_no_stories);
            }
            binding.emptyViewText.setTypeface(binding.emptyViewText.getTypeface(), Typeface.NORMAL);
            binding.emptyViewText.setAlpha(1.0f);
            binding.emptyViewImage.setVisibility(View.VISIBLE);

            binding.topLoadingIndicator.setVisibility(View.INVISIBLE);
            if (dataSeenYet && syncServiceState.isFeedSetExhausted(getFeedSet()) && (adapter.getRawStoryCount() > 0)) {
                fleuronBinding.containerSubscribe.setVisibility(View.GONE);
                fleuronBinding.getRoot().setVisibility(View.VISIBLE);
            }
        }
    }

    private void styleUpgradeBanner() {
        int cardBg, strokeColor, textColor, buttonBg;
        int goldColor = ContextCompat.getColor(requireContext(), R.color.premium_gold);

        PrefConstants.ThemeValue theme = prefsRepo.getResolvedTheme(requireContext());
        boolean isDark = theme == PrefConstants.ThemeValue.DARK || theme == PrefConstants.ThemeValue.BLACK;

        if (theme == PrefConstants.ThemeValue.SEPIA) {
            cardBg = ContextCompat.getColor(requireContext(), R.color.item_background_sepia);
            strokeColor = ContextCompat.getColor(requireContext(), R.color.row_border_sepia);
            textColor = ContextCompat.getColor(requireContext(), R.color.text_sepia);
            buttonBg = goldColor;
        } else if (isDark) {
            cardBg = Color.parseColor("#2C2C2E");
            strokeColor = Color.parseColor("#48484A");
            textColor = ContextCompat.getColor(requireContext(), R.color.gray85);
            buttonBg = goldColor;
        } else {
            cardBg = ContextCompat.getColor(requireContext(), R.color.white);
            strokeColor = ContextCompat.getColor(requireContext(), R.color.gray85);
            textColor = Color.parseColor("#1C1C1E");
            buttonBg = goldColor;
        }

        fleuronBinding.containerSubscribe.setCardBackgroundColor(cardBg);
        fleuronBinding.containerSubscribe.setStrokeColor(strokeColor);
        fleuronBinding.textSubscription.setTextColor(textColor);
        fleuronBinding.imgPremiumIcon.setImageTintList(ColorStateList.valueOf(goldColor));
        fleuronBinding.buttonUpgrade.setBackgroundTintList(ColorStateList.valueOf(buttonBg));
    }

    private void updateUpgradeBannerText() {
        FeedSet fs = getFeedSet();
        int textRes;
        if (fs.isAllNormal()) {
            textRes = R.string.premium_subscribers_allstories;
        } else if (fs.isSingleSavedTag()) {
            textRes = R.string.premium_subscribers_saved_tag;
        } else {
            textRes = R.string.premium_subscribers_folder;
        }
        fleuronBinding.textSubscription.setText(textRes);
    }

    public void notifyContentPrefsChanged() {
        adapter.notifyAllItemsChanged();
    }

    public void updateThumbnailStyle() {
        ThumbnailStyle thumbnailStyle = prefsRepo.getThumbnailStyle();
        adapter.setThumbnailStyle(thumbnailStyle);
        adapter.notifyAllItemsChanged();
    }

    public void updateListStyle() {
        StoryListStyle listStyle = prefsRepo.getStoryListStyle(getFeedSet());
        calcColumnCount(listStyle);
        calcGridSpacing(listStyle);
        layoutManager.setSpanCount(columnCount);
        adapter.setStyle(listStyle);
        adapter.notifyAllItemsChanged();
    }

    public void updateSpacingStyle() {
        SpacingStyle spacingStyle = prefsRepo.getSpacingStyle();
        adapter.setSpacingStyle(spacingStyle);
        adapter.notifyAllItemsChanged();
    }

    public void updateTextSize() {
        float textSize = prefsRepo.getListTextSize();
        adapter.setTextSize(textSize);
        adapter.notifyAllItemsChanged();
    }

    private void calcColumnCount(StoryListStyle listStyle) {
        // sensible defaults
        int colsFine = 3;
        int colsMed = 2;
        int colsCoarse = 1;

        // ensure we have measured
        if (itemGridWidthPx > 0) {
            int itemGridWidthDp = Math.round(UIUtils.px2dp(requireContext(), itemGridWidthPx));
            colsCoarse = itemGridWidthDp / 300;
            colsMed = itemGridWidthDp / 200;
            colsFine = itemGridWidthDp / 150;
            // sanity check the counts are strictly increasing
            if (colsCoarse < 1) colsCoarse = 1;
            if (colsMed <= colsCoarse) colsMed = colsCoarse + 1;
            if (colsFine <= colsMed) colsFine = colsMed + 1;
        }

        if (listStyle == StoryListStyle.GRID_F) {
            columnCount = colsFine;
        } else if (listStyle == StoryListStyle.GRID_M) {
            columnCount = colsMed;
        } else if (listStyle == StoryListStyle.GRID_C) {
            columnCount = colsCoarse;
        } else {
            columnCount = 1;
        }
    }

    private void calcGridSpacing(StoryListStyle listStyle) {
        if (listStyle == StoryListStyle.LIST) {
            gridSpacingPx = 0;
        } else {
            gridSpacingPx = UIUtils.dp2px(requireContext(), GRID_SPACING_DP);
        }
    }

    private void setupAnimSpeeds() {
        // to mitigate taps missed because of list pushdowns, RVs animate them. however, the speed
        // is device and settings dependent.  to keep the UI consistent across installs, take the
        // system default speed and tweak it towards a speed that looked and functioned well in
        // testing while still somewhat respecting the system's requested adjustments to speed.
        long targetAddDuration = 250L;
        // moves are especially jarring, and very rare
        long targetMovDuration = 500L;
        // if there are no stories in the list at all, let the first insert happen very quickly
        if ((adapter == null) || (adapter.getRawStoryCount() < 1)) {
            targetAddDuration = 0L;
            targetMovDuration = 0L;
        }

        RecyclerView.ItemAnimator anim = binding.itemgridfragmentGrid.getItemAnimator();
        anim.setAddDuration((anim.getAddDuration() + targetAddDuration) / 2L);
        anim.setMoveDuration((anim.getMoveDuration() + targetMovDuration) / 2L);
    }

    private void onScrolled(int dy) {
        // the framework likes to trigger this on init before we even known counts, so disregard those
        if (!dataSeenYet) return;

        // don't bother checking on scroll up
        if (dy < 1) return;

        // skip fetching more stories if premium access is required
        if (UIUtils.needsSubscriptionAccess(getFeedSet(), prefsRepo) && adapter.getItemCount() >= 3)
            return;

        ensureSufficientStories();

        // the list can be scrolled past the last item thanks to the offset footer, but don't fling
        // past the last item, which can be confusing to users who don't know about or need the offset
        if ((!fullFlingComplete) &&
                (layoutManager.findLastCompletelyVisibleItemPosition() >= adapter.getStoryCount())) {
            binding.itemgridfragmentGrid.stopScroll();
            // but after halting at the end once, do allow scrolling past the bottom
            fullFlingComplete = true;
        }

        // if flinging downwards, pause at the last unread as a convenience
        if ((indexOfLastUnread >= 0) &&
                (layoutManager.findLastCompletelyVisibleItemPosition() >= indexOfLastUnread)) {
            // but don't interrupt if already past the last unread
            if (indexOfLastUnread >= layoutManager.findFirstCompletelyVisibleItemPosition()) {
                binding.itemgridfragmentGrid.stopScroll();
            }
            indexOfLastUnread = -1;
        }

        if (prefsRepo.isMarkReadOnFeedScroll()) {
            // we want the top row of stories that is partially obscured. go back one from the first fully visible
            int markEnd = layoutManager.findFirstCompletelyVisibleItemPosition() - 1;
            // when scrolled to the bottom, the last story is fully visible but never scrolls off-screen,
            // so extend markEnd to include all remaining visible stories
            int lastCompletelyVisible = layoutManager.findLastCompletelyVisibleItemPosition();
            int storyCount = adapter.getStoryCount();
            if (storyCount > 0 && lastCompletelyVisible >= storyCount - 1) {
                markEnd = Math.max(markEnd, storyCount - 1);
            }
            if (markEnd > lastAutoMarkIndex) {
                int prevIndex = lastAutoMarkIndex;
                lastAutoMarkIndex = markEnd;
                // mark all stories between the previous mark position and the new one
                for (int i = prevIndex + 1; i <= markEnd; i++) {
                    Story story = adapter.getStory(i);
                    if (story != null) {
                        feedUtils.markStoryAsRead(story, requireContext());
                    }
                }
            }
        }
    }

    private void ensureSufficientStories() {
        // don't ask the list for how many rows it actually has - it may still be thawing from the cursor
        int totalCount = adapter.getRawStoryCount();
        int visibleCount = layoutManager.getChildCount();
        int lastVisible = layoutManager.findLastVisibleItemPosition();

        // load an extra page worth of stories past the viewport plus at least two rows to prime the height calc
        int desiredStoryCount = lastVisible + (visibleCount * 2) + (columnCount * 2);
        triggerRefresh(desiredStoryCount, totalCount);
        //com.newsblur.util.Log.d(this, String.format(" total:%d  bound:%d  last%d  desire:%d", totalCount, visibleCount, lastVisible, desiredStoryCount));
    }

    /**
     * if the story list bottom has been reached, add an amount of padding to the footer so that it can still
     * be scrolled until the bottom most story reaches to top, for those who mark-by-scrolling.
     */
    private void calcFleuronPadding() {
        // sanity check that we even have views yet
        if (fleuronResized || fleuronBinding.getRoot().getLayoutParams() == null) return;
        int listHeight = binding.itemgridfragmentGrid.getMeasuredHeight();
        ViewGroup.LayoutParams oldLayout = fleuronBinding.getRoot().getLayoutParams();
        FrameLayout.LayoutParams newLayout = new FrameLayout.LayoutParams(oldLayout);
        int marginPx_4dp = UIUtils.dp2px(requireContext(), 4);
        int fleuronFooterHeightPx = fleuronBinding.getRoot().getMeasuredHeight();
        if (listHeight > 1) {
            newLayout.setMargins(0, marginPx_4dp, 0, listHeight - fleuronFooterHeightPx);
            fleuronResized = true;
        } else {
            int defaultPx_100dp = UIUtils.dp2px(requireContext(), 100);
            newLayout.setMargins(0, marginPx_4dp, 0, defaultPx_100dp);
        }
        fleuronBinding.getRoot().setLayoutParams(newLayout);
    }

    private StoryViewAdapter.OnStoryClickListener getOnStoryClickListener() {
        return (feedSet, storyHash) -> {
            ItemsList activity = ((ItemsList) getActivity());
            if (activity != null) activity.startReadingActivity(feedSet, storyHash);
        };
    }

    private boolean isInteractiveStoryListSwipeEnabled() {
        ItemsList activity = (ItemsList) getActivity();
        return activity != null &&
                !activity.isTaskRoot() &&
                prefsRepo.getLeftToRightGestureAction() == GestureAction.GEST_ACTION_BACK;
    }

    private final class StoryListBackTouchListener implements RecyclerView.OnItemTouchListener {
        private final int touchSlopPx = ViewConfiguration.get(requireContext()).getScaledTouchSlop();
        private final int minimumFlingVelocityPx = ViewConfiguration.get(requireContext()).getScaledMinimumFlingVelocity();
        @Nullable
        private VelocityTracker velocityTracker;
        private float downRawX;
        private float downRawY;
        private boolean isDragging;
        private boolean gestureEligible;

        @Override
        public boolean onInterceptTouchEvent(@NonNull RecyclerView recyclerView, @NonNull MotionEvent event) {
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    gestureEligible = isInteractiveStoryListSwipeEnabled();
                    isDragging = false;
                    downRawX = event.getRawX();
                    downRawY = event.getRawY();
                    resetVelocityTracker();
                    velocityTracker = VelocityTracker.obtain();
                    trackMovement(event);
                    break;
                case MotionEvent.ACTION_MOVE:
                    if (!gestureEligible) return false;
                    trackMovement(event);
                    float deltaX = event.getRawX() - downRawX;
                    float deltaY = event.getRawY() - downRawY;
                    if (!isDragging &&
                            deltaX > touchSlopPx &&
                            deltaX > Math.abs(deltaY) * STORY_LIST_BACK_GESTURE_DIRECTION_RATIO) {
                        isDragging = true;
                        ItemsList activity = (ItemsList) getActivity();
                        if (activity != null) {
                            activity.beginInteractiveStoryListSwipe();
                            activity.updateInteractiveStoryListSwipe(deltaX);
                        }
                        recyclerView.requestDisallowInterceptTouchEvent(true);
                        return true;
                    }
                    break;
                case MotionEvent.ACTION_CANCEL:
                case MotionEvent.ACTION_UP:
                    resetGestureState();
                    break;
                default:
                    break;
            }
            return false;
        }

        @Override
        public void onTouchEvent(@NonNull RecyclerView recyclerView, @NonNull MotionEvent event) {
            if (!isDragging) return;
            trackMovement(event);

            ItemsList activity = (ItemsList) getActivity();
            if (activity == null) {
                resetGestureState();
                return;
            }

            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_MOVE:
                    activity.updateInteractiveStoryListSwipe(event.getRawX() - downRawX);
                    break;
                case MotionEvent.ACTION_UP:
                    float totalDeltaX = Math.max(0f, event.getRawX() - downRawX);
                    float xVelocity = getXVelocity();
                    boolean shouldComplete = totalDeltaX >= recyclerView.getWidth() * STORY_LIST_BACK_GESTURE_TRIGGER_RATIO;
                    if (!shouldComplete && xVelocity > minimumFlingVelocityPx * 4f) {
                        shouldComplete = true;
                    }
                    if (shouldComplete) {
                        activity.completeInteractiveStoryListSwipe();
                    } else {
                        activity.cancelInteractiveStoryListSwipe();
                    }
                    resetGestureState();
                    break;
                case MotionEvent.ACTION_CANCEL:
                    activity.cancelInteractiveStoryListSwipe();
                    resetGestureState();
                    break;
                default:
                    break;
            }
        }

        @Override
        public void onRequestDisallowInterceptTouchEvent(boolean disallowIntercept) {
        }

        private float getXVelocity() {
            if (velocityTracker == null) return 0f;
            velocityTracker.computeCurrentVelocity(1000);
            return velocityTracker.getXVelocity();
        }

        private void trackMovement(@NonNull MotionEvent event) {
            if (velocityTracker == null) return;
            MotionEvent screenEvent = MotionEvent.obtain(event);
            screenEvent.offsetLocation(event.getRawX() - event.getX(), event.getRawY() - event.getY());
            velocityTracker.addMovement(screenEvent);
            screenEvent.recycle();
        }

        private void resetGestureState() {
            isDragging = false;
            gestureEligible = false;
            resetVelocityTracker();
        }

        private void resetVelocityTracker() {
            if (velocityTracker != null) {
                velocityTracker.recycle();
                velocityTracker = null;
            }
        }
    }

    @Override
    public void onSaveInstanceState(@NonNull Bundle savedInstanceState) {
        super.onSaveInstanceState(savedInstanceState);
        savedInstanceState.putParcelable(BUNDLE_GRIDSTATE, binding.itemgridfragmentGrid.getLayoutManager().onSaveInstanceState());
    }

}
