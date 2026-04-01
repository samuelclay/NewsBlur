package com.newsblur.activity

import android.os.Bundle
import android.view.View
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.ViewCompositionStrategy
import com.newsblur.R
import com.newsblur.compose.DailyBriefingStoryTableConfig
import com.newsblur.compose.DailyBriefingScreen
import com.newsblur.databinding.ActivityDailyBriefingBinding
import com.newsblur.di.IconLoader
import com.newsblur.di.ThumbnailLoader
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.util.DailyBriefingDeepLink
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.ImageLoader
import com.newsblur.util.UIUtils
import com.newsblur.viewModel.DailyBriefingViewModel
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@AndroidEntryPoint
class DailyBriefingActivity : NbActivity() {
    companion object {
        private const val STATE_PENDING_LINKED_STORY_HASH = "pending_linked_story_hash"
        private const val STATE_HAS_OPENED_LINKED_STORY = "has_opened_linked_story"
    }

    @Inject
    lateinit var feedUtils: FeedUtils

    @Inject
    @IconLoader
    lateinit var iconLoader: ImageLoader

    @Inject
    @ThumbnailLoader
    lateinit var thumbnailLoader: ImageLoader

    private lateinit var binding: ActivityDailyBriefingBinding
    private lateinit var viewModel: DailyBriefingViewModel
    private var pendingLinkedStoryHash: String? = null
    private var hasOpenedLinkedStory = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewModel = ViewModelProvider(this)[DailyBriefingViewModel::class.java]
        binding = ActivityDailyBriefingBinding.inflate(layoutInflater)
        applyView(binding)

        UIUtils.setupToolbar(this, R.drawable.ic_briefing, getString(R.string.daily_briefing_title), true)
        findViewById<View>(R.id.toolbar_settings_button)?.setOnClickListener {
            viewModel.showSettings()
        }
        pendingLinkedStoryHash =
            savedInstanceState?.getString(STATE_PENDING_LINKED_STORY_HASH)
                ?: intent.getStringExtra(DailyBriefingDeepLink.EXTRA_STORY_HASH)
                ?: DailyBriefingDeepLink.storyHash(intent?.data)
        hasOpenedLinkedStory = savedInstanceState?.getBoolean(STATE_HAS_OPENED_LINKED_STORY) ?: false

        binding.dailyBriefingCompose.setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
        binding.dailyBriefingCompose.setContent {
            val state by viewModel.uiState.collectAsStateWithLifecycle()
            NewsBlurTheme(
                variant = prefsRepo.getSelectedTheme().toVariant(),
                dynamic = false,
            ) {
                DailyBriefingScreen(
                    state = state,
                    storyTableConfig =
                        DailyBriefingStoryTableConfig(
                            activity = this@DailyBriefingActivity,
                            iconLoader = iconLoader,
                            thumbnailLoader = thumbnailLoader,
                            feedUtils = feedUtils,
                            prefsRepo = prefsRepo,
                        ),
                    onToggleGroup = viewModel::toggleGroup,
                    onLoadMoreIfNeeded = viewModel::loadMoreIfNeeded,
                    onStoryClick = ::openStory,
                    onPremiumClick = { UIUtils.startSubscriptionActivity(this@DailyBriefingActivity) },
                    onHideSettings = viewModel::hideSettings,
                    onSavePreferences = viewModel::savePreferences,
                )
            }
        }

        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collectLatest { state ->
                    findViewById<View>(R.id.toolbar_settings_button)?.visibility =
                        if (state.showSettingsAction) {
                            View.VISIBLE
                        } else {
                            View.GONE
                        }
                    handlePendingLinkedStory(state)
                }
            }
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString(STATE_PENDING_LINKED_STORY_HASH, pendingLinkedStoryHash)
        outState.putBoolean(STATE_HAS_OPENED_LINKED_STORY, hasOpenedLinkedStory)
    }

    private fun handlePendingLinkedStory(state: com.newsblur.viewModel.DailyBriefingUiState) {
        val storyHash = pendingLinkedStoryHash ?: return
        if (hasOpenedLinkedStory) return

        if (state.groups.any { group -> group.storyHashes.contains(storyHash) }) {
            hasOpenedLinkedStory = true
            pendingLinkedStoryHash = null
            openStory(storyHash)
            return
        }

        if (state.isLoadingInitialData || state.isLoadingMore) {
            return
        }

        val lastGroupId = state.groups.lastOrNull()?.briefingId
        if (state.hasNextPage && lastGroupId != null) {
            viewModel.loadMoreIfNeeded(lastGroupId)
        }
    }

    private fun openStory(storyHash: String) {
        lifecycleScope.launch {
            withContext(Dispatchers.IO) {
                viewModel.prepareReadingSession()
            }
            UIUtils.startReadingActivity(this@DailyBriefingActivity, FeedSet.dailyBriefing(), storyHash)
        }
    }
}
