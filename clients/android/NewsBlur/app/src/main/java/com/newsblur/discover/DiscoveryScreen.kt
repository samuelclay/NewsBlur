package com.newsblur.discover

import android.widget.ImageView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.ViewList
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.newsblur.R
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.AppConstants
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefConstants.ThemeValue

@Composable
fun DiscoveryScreen(
    state: DiscoveryState,
    model: DiscoveryViewModel,
    theme: ThemeValue,
    loader: ImageLoader,
    onBack: () -> Unit,
    onQuickAdd: () -> Unit,
) {
    val colors = ReaderSheetPalette.colors(theme)
    CompositionLocalProvider(LocalContentColor provides colors.textPrimary) {
        Column(
            Modifier
                .fillMaxSize()
                .background(colors.background)
                .safeDrawingPadding()
                .imePadding(),
        ) {
            Row(Modifier.fillMaxWidth().padding(end = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "Back") }
                Text(
                    "Add + Discover Sites",
                    Modifier.weight(1f),
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                IconButton(onClick = model::toggleGrid) {
                    Icon(if (state.grid) Icons.Rounded.ViewList else Icons.Rounded.GridView, if (state.grid) "Show list" else "Show grid")
                }
                IconButton(onClick = onQuickAdd) { Icon(Icons.Rounded.Add, "Quick add site or folder") }
            }
            Row(
                Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                DiscoveryTab.entries.forEach { tab ->
                    FilterChip(
                        selected = state.tab == tab,
                        onClick = { model.selectTab(tab) },
                        label = { Text(tab.title) },
                        colors = chipColors(colors),
                    )
                }
            }
            HorizontalDivider(color = colors.border)
            if (state.busy) LinearProgressIndicator(Modifier.fillMaxWidth(), color = colors.accent)
            state.error?.let { Text(it, Modifier.padding(12.dp), color = colors.stale) }
            state.notice?.let { Text(it, Modifier.padding(horizontal = 12.dp, vertical = 4.dp), color = colors.accent) }
            key(state.tab) {
                val scroll = rememberLazyGridState()
                LazyVerticalGrid(
                    columns =
                        if (state.grid &&
                            state.tab !in listOf(DiscoveryTab.WEB, DiscoveryTab.GOOGLE)
                        ) {
                            GridCells.Adaptive(270.dp)
                        } else {
                            GridCells.Fixed(1)
                        },
                    state = scroll,
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        DiscoveryChoice(
                            "Add to",
                            if (state.folder == AppConstants.ROOT_FOLDER) "Top Level" else state.folder,
                            state.folders.map {
                                it.flatName() to
                                    (
                                        "    ".repeat(it.depth()) +
                                            if (it.name ==
                                                AppConstants.ROOT_FOLDER
                                            ) {
                                                "Top Level"
                                            } else {
                                                it.name
                                            }
                                    )
                            },
                            colors,
                            !state.busy,
                            model::chooseFolder,
                        )
                    }
                    when (state.tab) {
                        DiscoveryTab.WEB -> item { WebFeedForm(state, model, colors) }
                        DiscoveryTab.GOOGLE -> item { GoogleNewsForm(state, model, colors) }
                        else -> {
                            item(span = { GridItemSpan(maxLineSpan) }) {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    DiscoveryInput(state.page.query, state.tab.hint, colors, model::queryChanged, model::retry)
                                    if (state.tab == DiscoveryTab.NEWSLETTERS && state.page.platforms.isNotEmpty()) {
                                        DiscoveryChoice(
                                            "Platform",
                                            state.page.platform.ifBlank { "All" },
                                            listOf("" to "All") + state.page.platforms.map { it to it.replaceFirstChar(Char::uppercase) },
                                            colors,
                                        ) { model.filter(platform = it) }
                                    }
                                    if (state.page.categories.isNotEmpty()) {
                                        DiscoveryChoice(
                                            "Category",
                                            state.page.category.ifBlank { "All categories" },
                                            listOf("" to "All categories") + state.page.categories.map { it.name to it.name },
                                            colors,
                                        ) { model.filter(category = it) }
                                        val subs =
                                            state.page.categories
                                                .firstOrNull { it.name == state.page.category }
                                                ?.subcategories
                                                .orEmpty()
                                        if (subs.isNotEmpty()) {
                                            DiscoveryChoice(
                                                "Topic",
                                                state.page.subcategory.ifBlank { "All topics" },
                                                listOf("" to "All topics") + subs.map { it to it },
                                                colors,
                                            ) { model.filter(subcategory = it) }
                                        }
                                    }
                                    Text(
                                        if (state.tab == DiscoveryTab.SEARCH &&
                                            state.page.query.isBlank()
                                        ) {
                                            "Trending this week"
                                        } else if (state.page.query.isNotBlank()) {
                                            "Search results"
                                        } else {
                                            "Discover ${state.tab.title}"
                                        },
                                        style = MaterialTheme.typography.titleLarge,
                                    )
                                    if (state.tab == DiscoveryTab.SEARCH && DiscoveryViewModel.isAddress(state.page.query.trim())) {
                                        TextButton(enabled = !state.busy, onClick = {
                                            model.add(DiscoveryFeed(state.page.query.trim(), state.page.query.trim()))
                                        }) { Text("Add this URL", color = colors.siteLink) }
                                    }
                                }
                            }
                            items(state.page.feeds, key = { it.url }) { feed ->
                                DiscoveryCard(
                                    feed,
                                    feed.url in state.added,
                                    !state.busy,
                                    state.grid,
                                    colors,
                                    loader,
                                    { model.add(feed) },
                                    { model.preview(feed) },
                                )
                            }
                            item(span = { GridItemSpan(maxLineSpan) }) {
                                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                                    if (state.page.loading) {
                                        CircularProgressIndicator(
                                            Modifier.padding(16.dp).size(28.dp),
                                            color = colors.accent,
                                        )
                                    }
                                    state.page.error?.let {
                                        Text(it, color = colors.stale)
                                        TextButton(onClick = model::retry) { Text("Retry", color = colors.siteLink) }
                                    }
                                    if (!state.page.loading &&
                                        state.page.error == null &&
                                        state.page.feeds.isEmpty()
                                    ) {
                                        Text("No sites found. Try another search.", color = colors.textSecondary)
                                    }
                                    if (state.page.hasMore) TextButton(onClick = model::more) { Text("Load more", color = colors.siteLink) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DiscoveryCard(
    feed: DiscoveryFeed,
    added: Boolean,
    enabled: Boolean,
    grid: Boolean,
    colors: ReaderSheetPalette.Colors,
    loader: ImageLoader,
    onAdd: () -> Unit,
    onPreview: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(
                RoundedCornerShape(12.dp),
            ).background(colors.cardBackground)
            .border(1.dp, colors.border, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            AndroidView(modifier = Modifier.size(36.dp).clip(RoundedCornerShape(6.dp)), factory = {
                ImageView(it).apply {
                    scaleType =
                        ImageView.ScaleType.FIT_CENTER
                }
            }, update = { view ->
                val url =
                    feed.image.ifBlank {
                        if (feed.id.isNotBlank()) {
                            "${com.newsblur.network.APIConstants.buildUrl(
                                com.newsblur.network.APIConstants.PATH_FEED_FAVICON_URL,
                            )}${feed.id}"
                        } else {
                            ""
                        }
                    }
                if (view.tag !=
                    url
                ) {
                    view.tag = url
                    view.setImageResource(R.drawable.ic_world)
                    if (url.isNotBlank()) loader.displayImage(url, view)
                }
            })
            Column(Modifier.weight(1f)) {
                Text(feed.title, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(
                    feed.link,
                    color = colors.siteLink,
                    style = MaterialTheme.typography.bodySmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        if (feed.subscribers >
            0
        ) {
            Text(
                "${java.text.NumberFormat.getIntegerInstance().format(feed.subscribers)} subscribers",
                color = colors.textSecondary,
                style = MaterialTheme.typography.bodySmall,
            )
        }
        if (!grid) {
            feed.stories.take(3).forEach {
                Text(it, style = MaterialTheme.typography.bodyMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            TextButton(onClick = onPreview, enabled = enabled) { Text("Try", color = colors.siteLink) }
            Button(
                onClick = onAdd,
                enabled = enabled && !added,
                colors = ButtonDefaults.buttonColors(containerColor = colors.siteButton, contentColor = Color.White),
            ) {
                Text(if (added) "Added" else "Add")
            }
        }
    }
}

@Composable
internal fun DiscoveryChoice(
    label: String,
    selected: String,
    options: List<Pair<String, String>>,
    colors: ReaderSheetPalette.Colors,
    enabled: Boolean = true,
    onChoose: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(
                    RoundedCornerShape(8.dp),
                ).background(colors.cardBackground)
                .border(1.dp, colors.border, RoundedCornerShape(8.dp))
                .clickable(enabled = enabled) {
                    expanded =
                        true
                }.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("$label: ", color = colors.textSecondary, style = MaterialTheme.typography.bodyMedium)
            Text(selected, Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Icon(Icons.Rounded.ExpandMore, "Choose $label", Modifier.size(20.dp))
        }
        DropdownMenu(expanded, {
            expanded = false
        }, Modifier.heightIn(max = 360.dp).widthIn(max = 340.dp), containerColor = colors.cardBackground) {
            options.forEach { (value, title) ->
                DropdownMenuItem(text = { Text(title, color = colors.textPrimary) }, onClick = {
                    expanded =
                        false
                    ; onChoose(value)
                })
            }
        }
    }
}

@Composable
internal fun DiscoveryInput(
    value: String,
    hint: String,
    colors: ReaderSheetPalette.Colors,
    onChange: (String) -> Unit,
    onSubmit: () -> Unit = {},
    enabled: Boolean = true,
) {
    OutlinedTextField(
        value,
        onChange,
        Modifier.fillMaxWidth().semantics { contentDescription = hint },
        enabled = enabled,
        placeholder = { Text(hint) },
        singleLine = true,
        shape = RoundedCornerShape(10.dp),
        trailingIcon = { if (value.isNotEmpty()) IconButton(onClick = { onChange("") }) { Icon(Icons.Rounded.Close, "Clear $hint") } },
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
        keyboardActions = KeyboardActions(onSearch = { onSubmit() }),
        colors =
            OutlinedTextFieldDefaults.colors(
                focusedTextColor = colors.textPrimary,
                unfocusedTextColor = colors.textPrimary,
                focusedBorderColor = colors.siteLink,
                unfocusedBorderColor = colors.border,
                focusedContainerColor = colors.cardBackground,
                unfocusedContainerColor = colors.cardBackground,
                focusedPlaceholderColor = colors.textSecondary,
                unfocusedPlaceholderColor = colors.textSecondary,
            ),
    )
}

@Composable
private fun chipColors(colors: ReaderSheetPalette.Colors) =
    FilterChipDefaults.filterChipColors(
        containerColor = colors.cardBackground,
        labelColor = colors.textPrimary,
        selectedContainerColor = colors.siteButton,
        selectedLabelColor = Color.White,
    )

@Composable
private fun WebFeedForm(
    state: DiscoveryState,
    model: DiscoveryViewModel,
    colors: ReaderSheetPalette.Colors,
) {
    val web = state.web
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Follow any website", style = MaterialTheme.typography.headlineSmall)
        Text(
            "Create a feed from a page without RSS. NewsBlur finds its stories and checks for updates. Requires Premium Archive.",
            color = colors.textSecondary,
        )
        DiscoveryInput(web.url, "Web page URL", colors, { value -> model.webEdit { it.copy(url = value) } }, model::analyze, !state.busy)
        DiscoveryInput(web.hint, "Which stories? (optional)", colors, { value ->
            model.webEdit {
                it.copy(hint = value)
            }
        }, model::analyze, !state.busy)
        Button(
            onClick = model::analyze,
            enabled = web.url.isNotBlank() && !web.loading && !state.busy,
            colors = ButtonDefaults.buttonColors(containerColor = colors.siteButton, contentColor = Color.White),
        ) {
            Text(if (web.variants.isEmpty()) "Analyze page" else "Refine analysis")
        }
        if (web.loading) CircularProgressIndicator(Modifier.size(28.dp), color = colors.accent)
        if (web.message.isNotBlank()) Text(web.message, color = colors.textSecondary)
        web.error?.let { Text(it, color = colors.stale) }
        if (web.detectedFeed.isNotBlank()) {
            Button(
                onClick = { model.add(DiscoveryFeed(web.detectedFeed, web.detectedFeed)) },
                enabled =
                    !state.busy && web.detectedFeed !in state.added,
            ) { Text(if (web.detectedFeed in state.added) "Added" else "Add RSS feed") }
        }
        web.variants.forEachIndexed { index, variant ->
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(colors.cardBackground)
                    .border(
                        if (web.selected ==
                            index
                        ) {
                            2.dp
                        } else {
                            1.dp
                        },
                        if (web.selected ==
                            index
                        ) {
                            colors.accent
                        } else {
                            colors.border
                        },
                        RoundedCornerShape(10.dp),
                    ).clickable(enabled = !state.busy) { model.webEdit { it.copy(selected = index) } }
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(variant.label.ifBlank { "Pattern ${index + 1}" }, fontWeight = FontWeight.SemiBold)
                variant.stories.take(5).forEach { Text(it, style = MaterialTheme.typography.bodyMedium) }
            }
        }
        if (web.variants.isNotEmpty()) {
            DiscoveryInput(web.title, "Feed title", colors, { title -> model.webEdit { it.copy(title = title) } }, enabled = !state.busy)
            DiscoveryChoice(
                "Keep stories",
                "${web.staleness} days",
                listOf(7, 14, 30, 60, 90, 365).map {
                    "$it" to "$it days"
                },
                colors,
                !state.busy,
            ) { days -> model.webEdit { it.copy(staleness = days.toInt()) } }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(web.markUnread, { checked -> model.webEdit { it.copy(markUnread = checked) } }, enabled = !state.busy)
                Text("Mark updated stories unread", Modifier.weight(1f))
            }
            Button(
                onClick = model::subscribeWeb,
                enabled = !state.busy && "webfeed:${web.analyzedUrl}" !in state.added,
                colors = ButtonDefaults.buttonColors(containerColor = colors.siteButton, contentColor = Color.White),
            ) {
                Text(
                    if ("webfeed:${web.analyzedUrl}" in
                        state.added
                    ) {
                        "Added"
                    } else {
                        "Create web feed"
                    },
                )
            }
        }
    }
}

@Composable
private fun GoogleNewsForm(
    state: DiscoveryState,
    model: DiscoveryViewModel,
    colors: ReaderSheetPalette.Colors,
) {
    var category by rememberSaveable { mutableStateOf("") }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Follow news that matters to you", style = MaterialTheme.typography.headlineSmall)
        Text("Choose a topic or create a Google News feed for any search.", color = colors.textSecondary)
        DiscoveryInput(state.newsQuery, "Search a news topic", colors, { model.news(query = it) }, model::addNews, !state.busy)
        DiscoveryChoice(
            "Top stories",
            state.newsTopic
                .lowercase()
                .replaceFirstChar(Char::uppercase)
                .ifBlank { "Choose a topic" },
            listOf("WORLD", "NATION", "BUSINESS", "TECHNOLOGY", "ENTERTAINMENT", "SPORTS", "SCIENCE", "HEALTH").map {
                it to
                    it.lowercase().replaceFirstChar(Char::uppercase)
            },
            colors,
            !state.busy,
        ) { model.news(query = "", topic = it) }
        DiscoveryChoice(
            "Category",
            category.ifBlank {
                "Choose a category"
            },
            GoogleNewsCatalog.categories.keys.map { it to it },
            colors,
            !state.busy,
        ) {
            category =
                it
            ; model.news(query = it)
        }
        if (category.isNotBlank()) {
            DiscoveryChoice(
                "Topic",
                state.newsQuery,
                GoogleNewsCatalog.categories[category].orEmpty().map {
                    it to it
                },
                colors,
                !state.busy,
            ) { model.news(query = it) }
        }
        DiscoveryChoice(
            "Language",
            GoogleNewsCatalog.languages
                .firstOrNull {
                    it.first == state.language
                }?.second ?: state.language,
            GoogleNewsCatalog.languages,
            colors,
            !state.busy,
        ) {
            model.news(
                topic = state.newsTopic,
                language = it,
            )
        }
        Button(
            onClick = model::addNews,
            enabled = !state.busy && (state.newsQuery.isNotBlank() || state.newsTopic.isNotBlank()),
            colors = ButtonDefaults.buttonColors(containerColor = colors.siteButton, contentColor = Color.White),
        ) {
            Text("Add Google News feed")
        }
    }
}
