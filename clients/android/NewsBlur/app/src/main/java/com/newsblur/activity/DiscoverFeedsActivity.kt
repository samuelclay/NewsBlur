package com.newsblur.activity

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.newsblur.R
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.design.toVariant
import com.newsblur.di.IconLoader
import com.newsblur.di.ThumbnailLoader
import com.newsblur.discover.DiscoveryViewModel
import com.newsblur.discover.RelatedDiscoveryContent
import com.newsblur.domain.Feed
import com.newsblur.util.ImageLoader
import com.newsblur.util.TryFeedStore
import com.newsblur.viewModel.DiscoverFeedsViewModel
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class DiscoverFeedsActivity : NbActivity() {
    @Inject @IconLoader lateinit var iconLoader: ImageLoader
    @Inject @ThumbnailLoader lateinit var thumbnailLoader: ImageLoader
    @Inject lateinit var tryFeedStore: TryFeedStore

    private val viewModel: DiscoverFeedsViewModel by viewModels()
    private val actions: DiscoveryViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val sourceFeed = intent.getSerializableExtra(EXTRA_SOURCE_FEED) as? Feed
        val singleFeedId = intent.getStringExtra(EXTRA_FEED_ID)
        when {
            sourceFeed != null -> viewModel.load(sourceFeed)
            singleFeedId != null -> viewModel.load(singleFeedId)
            else -> viewModel.load(intent.getStringArrayListExtra(EXTRA_FEED_IDS).orEmpty())
        }
        setContent {
            NewsBlurTheme(variant = prefsRepo.getSelectedTheme().toVariant(), dynamic = false) {
                val state by actions.state.collectAsStateWithLifecycle()
                val colors = ReaderSheetPalette.colors(prefsRepo.getResolvedTheme(this))
                Column(Modifier.fillMaxSize().background(colors.background).safeDrawingPadding()) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        IconButton(onClick = { finish() }) {
                            Icon(Icons.AutoMirrored.Rounded.ArrowBack, "Back", tint = colors.textPrimary)
                        }
                        Text(
                            stringResource(R.string.discover_related_sites_title),
                            Modifier.weight(1f), color = colors.textPrimary,
                            style = MaterialTheme.typography.titleLarge, maxLines = 1, overflow = TextOverflow.Ellipsis,
                        )
                        IconButton(onClick = actions::toggleGrid) {
                            Icon(
                                painterResource(if (state.grid) R.drawable.ic_discover_view_list else R.drawable.ic_discover_view_grid),
                                stringResource(if (state.grid) R.string.discover_show_list else R.string.discover_show_grid),
                                Modifier.size(24.dp), tint = colors.textPrimary,
                            )
                        }
                    }
                    HorizontalDivider(color = colors.border)
                    RelatedDiscoveryContent(this@DiscoverFeedsActivity, viewModel, actions, iconLoader, thumbnailLoader, tryFeedStore)
                }
            }
        }
    }

    companion object {
        private const val EXTRA_FEED_ID = "discover_feed_id"
        private const val EXTRA_FEED_IDS = "discover_feed_ids"
        private const val EXTRA_SOURCE_FEED = "discover_source_feed"

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
