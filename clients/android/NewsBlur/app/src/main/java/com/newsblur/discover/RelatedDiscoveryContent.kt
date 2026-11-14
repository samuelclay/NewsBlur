package com.newsblur.discover

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.newsblur.activity.NbActivity
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.ImageLoader
import com.newsblur.util.TryFeedStore
import com.newsblur.viewModel.DiscoverFeedsViewModel
import kotlinx.coroutines.flow.distinctUntilChanged

// RelatedDiscoveryContent.kt supplies related results to the same complete card used by DiscoveryScreen.kt.
@Composable
internal fun RelatedDiscoveryContent(
    activity: NbActivity,
    relatedModel: DiscoverFeedsViewModel,
    actions: DiscoveryViewModel,
    iconLoader: ImageLoader,
    thumbnailLoader: ImageLoader,
    tryFeedStore: TryFeedStore,
    modifier: Modifier = Modifier,
) {
    val related by relatedModel.uiState.collectAsStateWithLifecycle()
    val state by actions.state.collectAsStateWithLifecycle()
    val colors = ReaderSheetPalette.colors(activity.prefsRepo.getResolvedTheme(activity))
    val cards = remember(related.feeds) { related.feeds.map { it.asDiscoveryFeed() }.filter { it.url.isNotBlank() } }
    val list = rememberLazyListState()
    DiscoveryActionEffects(activity, actions, tryFeedStore)
    LaunchedEffect(list, cards.size) {
        snapshotFlow { list.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1 }
            .distinctUntilChanged().collect { index ->
                if (cards.isNotEmpty() && index >= cards.size - 2) relatedModel.loadNextPage()
            }
    }
    Column(modifier.fillMaxSize()) {
        if (state.busy) LinearProgressIndicator(Modifier.fillMaxWidth(), color = colors.accent)
        state.error?.let { Text(it, Modifier.padding(horizontal = 14.dp, vertical = 8.dp), color = colors.stale) }
        state.notice?.let { Text(it, Modifier.padding(horizontal = 14.dp, vertical = 8.dp), color = colors.textSecondary) }
        LazyColumn(
            state = list,
            contentPadding = PaddingValues(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(cards, key = { it.id.ifBlank { it.url } }) { feed ->
                DiscoveryFeedCard(
                    feed = feed,
                    added = feed.url in state.added,
                    enabled = !state.busy,
                    grid = state.grid,
                    colors = colors,
                    loader = iconLoader,
                    thumbnailLoader = thumbnailLoader,
                    onAdd = { actions.add(feed) },
                    onPreview = { actions.preview(feed) },
                    state = state,
                    onChooseFolder = actions::chooseFolder,
                    onOpenStory = { actions.preview(feed, it) },
                )
            }
            item {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    if (related.isLoadingInitial || related.isLoadingMore) {
                        CircularProgressIndicator(Modifier.padding(16.dp).size(28.dp), color = colors.accent)
                    } else if (cards.isEmpty()) {
                        Text(related.errorMessage ?: "No related sites found", color = colors.textSecondary)
                    }
                    if (related.errorMessage != null) {
                        if (cards.isNotEmpty()) Text(related.errorMessage!!, color = colors.stale)
                    }
                }
            }
        }
    }
}
