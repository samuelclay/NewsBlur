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
import com.newsblur.compose.DailyBriefingScreen
import com.newsblur.databinding.ActivityDailyBriefingBinding
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.FeedSet
import com.newsblur.util.UIUtils
import com.newsblur.viewModel.DailyBriefingViewModel
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@AndroidEntryPoint
class DailyBriefingActivity : NbActivity() {
    private lateinit var binding: ActivityDailyBriefingBinding
    private lateinit var viewModel: DailyBriefingViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewModel = ViewModelProvider(this)[DailyBriefingViewModel::class.java]
        binding = ActivityDailyBriefingBinding.inflate(layoutInflater)
        applyView(binding)

        UIUtils.setupToolbar(this, R.drawable.ic_briefing, getString(R.string.daily_briefing_title), true)
        findViewById<View>(R.id.toolbar_settings_button)?.setOnClickListener {
            viewModel.showSettings()
        }

        binding.dailyBriefingCompose.setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
        binding.dailyBriefingCompose.setContent {
            val state by viewModel.uiState.collectAsStateWithLifecycle()
            NewsBlurTheme(
                variant = prefsRepo.getSelectedTheme().toVariant(),
                dynamic = false,
            ) {
                DailyBriefingScreen(
                    state = state,
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
                }
            }
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
