package com.newsblur.discover

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
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
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ExpandMore
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.newsblur.R
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefConstants.ThemeValue

@Composable
fun DiscoveryScreen(
    state: DiscoveryState,
    model: DiscoveryViewModel,
    theme: ThemeValue,
    loader: ImageLoader,
    thumbnailLoader: ImageLoader,
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
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, stringResource(R.string.contact_back)) }
                Text(
                    stringResource(R.string.i18n_add_discover_sites),
                    Modifier.weight(1f),
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                IconButton(onClick = model::toggleGrid) {
                    Icon(
                        painterResource(if (state.grid) R.drawable.ic_discover_view_list else R.drawable.ic_discover_view_grid),
                        stringResource(if (state.grid) R.string.discover_show_list else R.string.discover_show_grid),
                        Modifier.size(24.dp),
                    )
                }
                IconButton(onClick = onQuickAdd) { Icon(Icons.Rounded.Add, stringResource(R.string.discover_quick_add)) }
            }
            Row(
                Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                DiscoveryTab.entries.forEach { tab ->
                    val tabVisibility = remember { BringIntoViewRequester() }
                    LaunchedEffect(state.tab) {
                        if (state.tab == tab) {
                            withFrameNanos { }
                            tabVisibility.bringIntoView()
                        }
                    }
                    FilterChip(
                        modifier = Modifier.bringIntoViewRequester(tabVisibility),
                        selected = state.tab == tab,
                        onClick = { model.selectTab(tab) },
                        label = { Text(tabTitle(tab)) },
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
                    when (state.tab) {
                        DiscoveryTab.WEB -> item { WebFeedForm(state, model, colors) }
                        DiscoveryTab.GOOGLE -> item { GoogleNewsForm(state, model, colors) }
                        else -> {
                            item(span = { GridItemSpan(maxLineSpan) }) {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    DiscoveryInput(state.page.query, stringResource(tabHint(state.tab)), colors, model::queryChanged, model::retry)
                                    if (state.tab == DiscoveryTab.NEWSLETTERS && state.page.platforms.isNotEmpty()) {
                                        val allPlatforms = stringResource(R.string.discover_all_platforms)
                                        DiscoveryChoice(
                                            stringResource(R.string.discover_platform),
                                            state.page.platform.ifBlank { allPlatforms },
                                            listOf("" to allPlatforms) + state.page.platforms.map { it to it.replaceFirstChar(Char::uppercase) },
                                            colors,
                                        ) { model.filter(platform = it) }
                                    }
                                    if (state.page.categories.isNotEmpty()) {
                                        val allCategories = stringResource(R.string.discover_all_categories)
                                        DiscoveryChoice(
                                            stringResource(R.string.discover_category),
                                            state.page.category.ifBlank { allCategories },
                                            listOf("" to allCategories) + state.page.categories.map { it.name to it.name },
                                            colors,
                                        ) { model.filter(category = it) }
                                        val subs =
                                            state.page.categories
                                                .firstOrNull { it.name == state.page.category }
                                                ?.subcategories
                                                .orEmpty()
                                        if (subs.isNotEmpty()) {
                                            val allTopics = stringResource(R.string.discover_all_topics)
                                            DiscoveryChoice(
                                                stringResource(R.string.discover_topic),
                                                state.page.subcategory.ifBlank { allTopics },
                                                listOf("" to allTopics) + subs.map { it to it },
                                                colors,
                                            ) { model.filter(subcategory = it) }
                                        }
                                    }
                                    Text(
                                        if (state.tab == DiscoveryTab.SEARCH &&
                                            state.page.query.isBlank()
                                        ) {
                                            stringResource(R.string.discover_trending_this_week)
                                        } else if (state.page.query.isNotBlank()) {
                                            stringResource(R.string.discover_search_results)
                                        } else {
                                            stringResource(R.string.discover_tab_heading, tabTitle(state.tab))
                                        },
                                        style = MaterialTheme.typography.titleLarge,
                                    )
                                    if (state.tab == DiscoveryTab.SEARCH && DiscoveryViewModel.isAddress(state.page.query.trim())) {
                                        DiscoveryAddRow(state, model, colors) {
                                            val addUrlDescription = stringResource(R.string.discover_add_this_url)
                                            TextButton(modifier = Modifier.semantics { contentDescription = addUrlDescription }, enabled = !state.busy, onClick = {
                                                model.add(DiscoveryFeed(state.page.query.trim(), state.page.query.trim()))
                                            }) { Text(stringResource(R.string.i18n_add), color = colors.siteLink) }
                                        }
                                    }
                                }
                            }
                            items(state.page.feeds, key = { it.url }) { feed ->
                                DiscoveryFeedCard(
                                    feed,
                                    feed.url in state.added,
                                    !state.busy,
                                    state.grid,
                                    colors,
                                    loader,
                                    thumbnailLoader,
                                    { model.add(feed) },
                                    { model.preview(feed) },
                                    state,
                                    model::chooseFolder,
                                    { story -> model.preview(feed, story) },
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
                                        TextButton(onClick = model::retry) { Text(stringResource(R.string.i18n_retry), color = colors.siteLink) }
                                    }
                                    if (!state.page.loading &&
                                        state.page.error == null &&
                                        state.page.feeds.isEmpty()
                                    ) {
                                        Text(stringResource(R.string.i18n_no_sites_found_try_another_search), color = colors.textSecondary)
                                    }
                                    if (state.page.hasMore) TextButton(onClick = model::more) { Text(stringResource(R.string.i18n_load_more), color = colors.siteLink) }
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
private fun DiscoveryAddRow(
    state: DiscoveryState,
    model: DiscoveryViewModel,
    colors: ReaderSheetPalette.Colors,
    action: @Composable RowScope.() -> Unit,
) {
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        DiscoveryFolderPicker(state, colors, model::chooseFolder, Modifier.weight(1f))
        action()
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
            Text(
                stringResource(R.string.discover_choice_label, label),
                Modifier.padding(end = 4.dp),
                color = colors.textSecondary,
                style = MaterialTheme.typography.bodyMedium,
            )
            Text(selected, Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Icon(Icons.Rounded.ExpandMore, stringResource(R.string.discover_choose_option, label), Modifier.size(20.dp))
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
    val clearDescription = stringResource(R.string.discover_clear_input, hint)
    OutlinedTextField(
        value,
        onChange,
        Modifier.fillMaxWidth().semantics { contentDescription = hint },
        enabled = enabled,
        placeholder = { Text(hint) },
        singleLine = true,
        shape = RoundedCornerShape(10.dp),
        trailingIcon = { if (value.isNotEmpty()) IconButton(onClick = { onChange("") }) { Icon(Icons.Rounded.Close, clearDescription) } },
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
        Text(stringResource(R.string.i18n_follow_any_website), style = MaterialTheme.typography.headlineSmall)
        Text(
            stringResource(R.string.i18n_create_a_feed_from_a_page_without_rss_newsblur_finds_its_stories_and_checks_for_updates_requires_premium_archive),
            color = colors.textSecondary,
        )
        DiscoveryInput(web.url, stringResource(R.string.discover_web_page_url), colors, { value -> model.webEdit { it.copy(url = value) } }, model::analyze, !state.busy)
        DiscoveryInput(web.hint, stringResource(R.string.discover_which_stories_optional), colors, { value ->
            model.webEdit {
                it.copy(hint = value)
            }
        }, model::analyze, !state.busy)
        Button(
            onClick = model::analyze,
            enabled = web.url.isNotBlank() && !web.loading && !state.busy,
            colors = ButtonDefaults.buttonColors(containerColor = colors.siteButton, contentColor = Color.White),
        ) {
            Text(stringResource(if (web.variants.isEmpty()) R.string.discover_analyze_page else R.string.discover_refine_analysis))
        }
        if (web.loading) CircularProgressIndicator(Modifier.size(28.dp), color = colors.accent)
        if (web.message.isNotBlank()) Text(web.message, color = colors.textSecondary)
        web.error?.let { Text(it, color = colors.stale) }
        if (web.detectedFeed.isNotBlank()) {
            val addRssDescription = stringResource(R.string.discover_add_rss_feed)
            DiscoveryAddRow(state, model, colors) {
                Button(
                    onClick = { model.add(DiscoveryFeed(web.detectedFeed, web.detectedFeed)) },
                    modifier = Modifier.semantics { contentDescription = addRssDescription },
                    enabled = !state.busy && web.detectedFeed !in state.added,
                    colors = ButtonDefaults.buttonColors(containerColor = colors.siteButton, contentColor = Color.White),
                ) { Text(stringResource(if (web.detectedFeed in state.added) R.string.discover_added else R.string.i18n_add)) }
            }
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
                Text(variant.label.ifBlank { stringResource(R.string.discover_web_pattern, index + 1) }, fontWeight = FontWeight.SemiBold)
                variant.stories.take(5).forEach { Text(it, style = MaterialTheme.typography.bodyMedium) }
            }
        }
        if (web.variants.isNotEmpty()) {
            DiscoveryInput(web.title, stringResource(R.string.discover_feed_title), colors, { title -> model.webEdit { it.copy(title = title) } }, enabled = !state.busy)
            DiscoveryChoice(
                stringResource(R.string.discover_keep_stories),
                pluralStringResource(R.plurals.discover_keep_stories_days, web.staleness, web.staleness),
                listOf(7, 14, 30, 60, 90, 365).map {
                    "$it" to pluralStringResource(R.plurals.discover_keep_stories_days, it, it)
                },
                colors,
                !state.busy,
            ) { days -> model.webEdit { it.copy(staleness = days.toInt()) } }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(web.markUnread, { checked -> model.webEdit { it.copy(markUnread = checked) } }, enabled = !state.busy)
                Text(stringResource(R.string.i18n_mark_updated_stories_unread), Modifier.weight(1f))
            }
            val createWebFeedDescription = stringResource(R.string.discover_create_web_feed)
            DiscoveryAddRow(state, model, colors) {
                Button(
                    onClick = model::subscribeWeb,
                    modifier = Modifier.semantics { contentDescription = createWebFeedDescription },
                    enabled = !state.busy && "webfeed:${web.analyzedUrl}" !in state.added,
                    colors = ButtonDefaults.buttonColors(containerColor = colors.siteButton, contentColor = Color.White),
                ) {
                    Text(stringResource(if ("webfeed:${web.analyzedUrl}" in state.added) R.string.discover_added else R.string.i18n_subscribe))
                }
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
    val category = state.newsCategory
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(R.string.i18n_follow_news_that_matters_to_you), style = MaterialTheme.typography.headlineSmall)
        Text(stringResource(R.string.i18n_choose_a_topic_or_create_a_google_news_feed_for_any_search), color = colors.textSecondary)
        DiscoveryInput(state.newsQuery, stringResource(R.string.discover_search_news_topic), colors, { model.news(query = it) }, model::addNews, !state.busy)
        val topics = googleNewsTopics.map { (topic, title) -> topic to stringResource(title) }
        DiscoveryChoice(
            stringResource(R.string.discover_top_stories),
            topics.firstOrNull { it.first == state.newsTopic }?.second
                ?: state.newsTopic
                    .lowercase()
                    .replaceFirstChar(Char::uppercase)
                    .ifBlank { stringResource(R.string.discover_choose_a_topic) },
            topics,
            colors,
            !state.busy,
        ) { model.news(query = "", topic = it, category = "") }
        DiscoveryChoice(
            stringResource(R.string.discover_category),
            category.ifBlank {
                stringResource(R.string.discover_choose_a_category)
            },
            GoogleNewsCatalog.categories.keys.map { it to it },
            colors,
            !state.busy,
        ) { model.news(query = it, category = it) }
        if (category.isNotBlank()) {
            DiscoveryChoice(
                stringResource(R.string.discover_topic),
                state.newsQuery,
                GoogleNewsCatalog.categories[category].orEmpty().map {
                    it to it
                },
                colors,
                !state.busy,
            ) { model.news(query = it) }
        }
        DiscoveryChoice(
            stringResource(R.string.language_title),
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
        val addGoogleNewsDescription = stringResource(R.string.discover_add_google_news_feed)
        DiscoveryAddRow(state, model, colors) {
            Button(
                onClick = model::addNews,
                modifier = Modifier.semantics { contentDescription = addGoogleNewsDescription },
                enabled = !state.busy && (state.newsQuery.isNotBlank() || state.newsTopic.isNotBlank()),
                colors = ButtonDefaults.buttonColors(containerColor = colors.siteButton, contentColor = Color.White),
            ) {
                Text(stringResource(R.string.i18n_subscribe))
            }
        }
    }
}

// DiscoveryScreen.kt localizes tab labels here; DiscoveryTab keeps its English titles as stable identifiers.
@Composable
private fun tabTitle(tab: DiscoveryTab): String =
    when (tab) {
        DiscoveryTab.SEARCH -> stringResource(R.string.discover_tab_search)
        DiscoveryTab.WEB -> stringResource(R.string.discover_tab_web_feed)
        DiscoveryTab.POPULAR -> stringResource(R.string.discover_tab_popular)
        DiscoveryTab.NEWSLETTERS -> stringResource(R.string.discover_tab_newsletters)
        DiscoveryTab.PODCASTS -> stringResource(R.string.discover_tab_podcasts)
        // YouTube, Reddit and Google News are product names.
        DiscoveryTab.YOUTUBE, DiscoveryTab.REDDIT, DiscoveryTab.GOOGLE -> tab.title
    }

@StringRes
private fun tabHint(tab: DiscoveryTab): Int =
    when (tab) {
        DiscoveryTab.SEARCH -> R.string.discover_hint_search
        DiscoveryTab.WEB -> R.string.discover_web_page_url
        DiscoveryTab.POPULAR -> R.string.discover_hint_popular
        DiscoveryTab.YOUTUBE -> R.string.discover_hint_youtube
        DiscoveryTab.REDDIT -> R.string.discover_hint_reddit
        DiscoveryTab.NEWSLETTERS -> R.string.discover_hint_newsletters
        DiscoveryTab.PODCASTS -> R.string.discover_hint_podcasts
        DiscoveryTab.GOOGLE -> R.string.discover_search_news_topic
    }

// DiscoveryScreen.kt sends the Google News topic codes to the server and shows their translated names.
private val googleNewsTopics =
    listOf(
        "WORLD" to R.string.discover_news_topic_world,
        "NATION" to R.string.discover_news_topic_nation,
        "BUSINESS" to R.string.discover_news_topic_business,
        "TECHNOLOGY" to R.string.discover_news_topic_technology,
        "ENTERTAINMENT" to R.string.discover_news_topic_entertainment,
        "SPORTS" to R.string.discover_news_topic_sports,
        "SCIENCE" to R.string.discover_news_topic_science,
        "HEALTH" to R.string.discover_news_topic_health,
    )
