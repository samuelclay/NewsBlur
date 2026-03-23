package com.newsblur.activity

import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.activity.viewModels
import androidx.core.view.isVisible
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.newsblur.R
import com.newsblur.databinding.ActivityDiscoverFeedsBinding
import com.newsblur.databinding.ViewDiscoverToolbarToggleBinding
import com.newsblur.di.IconLoader
import com.newsblur.domain.DiscoverFeedPayload
import com.newsblur.domain.Feed
import com.newsblur.fragment.AddFeedFragment
import com.newsblur.util.DiscoverThemePalette
import com.newsblur.util.ImageLoader
import com.newsblur.util.TryFeedStore
import com.newsblur.util.UIUtils
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.discoverThemePalette
import com.newsblur.viewModel.DiscoverFeedViewMode
import com.newsblur.viewModel.DiscoverFeedsUiState
import com.newsblur.viewModel.DiscoverFeedsViewModel
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class DiscoverFeedsActivity :
    NbActivity(),
    DiscoverFeedAdapter.Listener,
    AddFeedFragment.AddFeedProgressListener {
    @Inject
    @IconLoader
    lateinit var iconLoader: ImageLoader

    @Inject
    lateinit var tryFeedStore: TryFeedStore

    private val viewModel: DiscoverFeedsViewModel by viewModels()

    private lateinit var binding: ActivityDiscoverFeedsBinding
    private lateinit var toolbarToggleBinding: ViewDiscoverToolbarToggleBinding
    private lateinit var toolbarActionContainer: FrameLayout
    private lateinit var toolbarIconView: ImageView
    private lateinit var adapter: DiscoverFeedAdapter
    private lateinit var palette: DiscoverThemePalette

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityDiscoverFeedsBinding.inflate(layoutInflater)
        applyView(binding)
        UIUtils.setupToolbar(this, R.drawable.ic_discover, getString(R.string.discover_related_sites_title), true)
        toolbarActionContainer = findViewById(R.id.toolbar_action_container)
        toolbarIconView = findViewById(R.id.toolbar_icon)
        toolbarToggleBinding =
            ViewDiscoverToolbarToggleBinding.inflate(layoutInflater, toolbarActionContainer, true)
        toolbarActionContainer.isVisible = true
        findViewById<View>(R.id.toolbar_settings_button).isVisible = false

        palette = discoverThemePalette(this, prefsRepo)
        adapter = DiscoverFeedAdapter(layoutInflater, iconLoader, palette, dbHelper.allFeeds, this)

        binding.discoverRecycler.layoutManager = LinearLayoutManager(this)
        binding.discoverRecycler.adapter = adapter
        binding.discoverRecycler.addOnScrollListener(
            object : RecyclerView.OnScrollListener() {
                override fun onScrolled(
                    recyclerView: RecyclerView,
                    dx: Int,
                    dy: Int,
                ) {
                    if (dy <= 0) return
                    val layoutManager = recyclerView.layoutManager as? LinearLayoutManager ?: return
                    val lastVisible = layoutManager.findLastVisibleItemPosition()
                    if (lastVisible >= adapter.itemCount - LOAD_MORE_THRESHOLD) {
                        viewModel.loadNextPage()
                    }
                }
            },
        )

        toolbarToggleBinding.discoverToolbarGridButton.setOnClickListener {
            viewModel.setViewMode(DiscoverFeedViewMode.GRID)
        }
        toolbarToggleBinding.discoverToolbarListButton.setOnClickListener {
            viewModel.setViewMode(DiscoverFeedViewMode.LIST)
        }

        applyPalette()
        observeState()
        loadDiscoverFeeds()
    }

    override fun onTryFeed(payload: DiscoverFeedPayload) {
        tryFeedStore.set(payload.feed)
        FeedItemsList.startTryFeedActivity(this, payload.feed)
        finish()
    }

    override fun onAddFeed(payload: DiscoverFeedPayload) {
        val feedUrl = payload.feed.address.takeIf { it.isNotBlank() } ?: payload.feed.feedLink
        if (feedUrl.isBlank()) {
            return
        }
        AddFeedFragment
            .newInstance(feedUrl, payload.feed.title)
            .show(supportFragmentManager, AddFeedFragment::class.java.name)
    }

    override fun addFeedStarted() {
        // AddFeedFragment owns its own progress UI.
    }

    private fun observeState() {
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect(::render)
            }
        }
    }

    private fun render(state: DiscoverFeedsUiState) {
        palette = discoverThemePalette(this, prefsRepo)
        applyPalette()
        styleToggleButton(
            toolbarToggleBinding.discoverToolbarGridButton,
            state.viewMode == DiscoverFeedViewMode.GRID,
        )
        styleToggleButton(
            toolbarToggleBinding.discoverToolbarListButton,
            state.viewMode == DiscoverFeedViewMode.LIST,
        )
        adapter.submit(state.feeds, state.viewMode, palette, dbHelper.allFeeds)

        binding.discoverRecycler.isVisible = state.feeds.isNotEmpty()
        binding.discoverLoadingContainer.isVisible = state.isLoadingInitial && state.feeds.isEmpty()
        binding.discoverLoadingMore.isVisible = state.isLoadingMore && state.feeds.isNotEmpty()
        val showEmptyState = !state.isLoadingInitial && state.feeds.isEmpty()
        binding.discoverEmptyState.isVisible = showEmptyState
        if (showEmptyState) {
            binding.discoverEmptyState.text = state.errorMessage ?: getString(R.string.discover_no_related_sites)
        }
    }

    private fun loadDiscoverFeeds() {
        val singleFeedId = intent.getStringExtra(EXTRA_FEED_ID)
        val sourceFeed = intent.getSerializableExtra(EXTRA_SOURCE_FEED) as? Feed
        val feedIds = intent.getStringArrayListExtra(EXTRA_FEED_IDS)
        if (sourceFeed != null) {
            viewModel.load(sourceFeed)
        } else if (singleFeedId != null) {
            viewModel.load(singleFeedId)
        } else if (!feedIds.isNullOrEmpty()) {
            viewModel.load(feedIds)
        } else {
            binding.discoverLoadingContainer.visibility = View.GONE
            binding.discoverEmptyState.visibility = View.VISIBLE
            binding.discoverEmptyState.text = getString(R.string.discover_no_related_sites)
        }
    }

    private fun applyPalette() {
        binding.discoverContent.setBackgroundColor(palette.backgroundColor)
        toolbarIconView.imageTintList = ColorStateList.valueOf(palette.textSecondaryColor)
        binding.discoverLoadingView.setIndicatorColor(palette.accentColor)
        binding.discoverLoadingText.setTextColor(palette.textSecondaryColor)
        binding.discoverEmptyState.setTextColor(palette.textSecondaryColor)
        binding.discoverLoadingMore.indeterminateTintList = ColorStateList.valueOf(palette.accentColor)
    }

    private fun styleToggleButton(
        button: MaterialButton,
        isSelected: Boolean,
    ) {
        button.backgroundTintList =
            ColorStateList.valueOf(
                if (isSelected) {
                    palette.segmentedSelectedColor
                } else {
                    palette.segmentedBackgroundColor
                },
            )
        button.strokeColor = ColorStateList.valueOf(palette.segmentedBorderColor)
        val textColor =
            if (isSelected) {
                palette.segmentedSelectedTextColor
            } else {
                palette.segmentedTextColor
            }
        button.setTextColor(textColor)
        button.iconTint = ColorStateList.valueOf(textColor)
    }

    companion object {
        private const val EXTRA_FEED_ID = "discover_feed_id"
        private const val EXTRA_FEED_IDS = "discover_feed_ids"
        private const val EXTRA_SOURCE_FEED = "discover_source_feed"
        private const val LOAD_MORE_THRESHOLD = 4

        @JvmStatic
        fun startForFeed(
            context: Context,
            feed: Feed,
        ) {
            context.startActivity(
                Intent(context, DiscoverFeedsActivity::class.java).apply {
                    putExtra(EXTRA_FEED_ID, feed.feedId)
                    putExtra(EXTRA_SOURCE_FEED, feed)
                },
            )
        }

        @JvmStatic
        fun startForFeed(
            context: Context,
            feedId: String,
        ) {
            context.startActivity(
                Intent(context, DiscoverFeedsActivity::class.java).apply {
                    putExtra(EXTRA_FEED_ID, feedId)
                },
            )
        }

        @JvmStatic
        fun startForFeeds(
            context: Context,
            feedIds: Collection<String>,
        ) {
            context.startActivity(
                Intent(context, DiscoverFeedsActivity::class.java).apply {
                    putStringArrayListExtra(EXTRA_FEED_IDS, ArrayList(feedIds))
                },
            )
        }
    }
}
