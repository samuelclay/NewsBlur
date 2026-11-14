package com.newsblur.discover

import android.text.format.DateUtils
import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.RssFeed
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.newsblur.R
import com.newsblur.design.DescribePalette
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.design.withContentDirection
import com.newsblur.util.DiscoverFeedFreshnessFormatter
import com.newsblur.util.ImageLoader
import java.text.NumberFormat

// DescribeTab.kt renders the Describe tab of DiscoveryScreen.kt: the composer, the history rail, the phase stepper
// and the verdict-decorated result cards. It mirrors media/js/newsblur/views/describe_feeds_view.js on the web.
internal fun LazyGridScope.describeItems(
    state: DiscoveryState,
    model: DiscoveryViewModel,
    colors: ReaderSheetPalette.Colors,
    palette: DescribePalette.Colors,
    loader: ImageLoader,
    thumbnailLoader: ImageLoader,
    onUpgrade: () -> Unit,
) {
    val describe = state.describe
    val search = describe.search
    item(key = "describe-header", span = { GridItemSpan(maxLineSpan) }) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(stringResource(R.string.describe_upgrade_title), style = MaterialTheme.typography.titleLarge)
            if (describe.showsUpgrade) {
                DescribeUpgradeCard(describe.upgradeMessage.orEmpty(), colors, palette, onUpgrade)
            } else {
                DescribeComposer(describe, colors, palette, model)
            }
            describe.error?.let { Text(describeErrorText(it), color = colors.stale, style = MaterialTheme.typography.bodyMedium) }
        }
    }
    if (describe.history.isNotEmpty()) {
        item(key = "describe-history", span = { GridItemSpan(maxLineSpan) }) { DescribeHistoryRail(describe, colors, palette, model) }
    }
    if (describe.loading || search != null) {
        item(key = "describe-status", span = { GridItemSpan(maxLineSpan) }) { DescribeStatusCard(describe, colors, palette, model) }
    }
    if (search != null) {
        items(search.results, key = { "describe-result-${it.feedId}" }) { result ->
            DescribeResultCard(result, state, model, colors, palette, loader, thumbnailLoader)
        }
    }
    if (search == null && !describe.loading && !describe.showsUpgrade) {
        item(key = "describe-examples", span = { GridItemSpan(maxLineSpan) }) { DescribeExamples(describe, colors, palette, model) }
    }
}

@Composable
private fun DescribeComposer(
    describe: DescribeState,
    colors: ReaderSheetPalette.Colors,
    palette: DescribePalette.Colors,
    model: DiscoveryViewModel,
) {
    val placeholder = stringResource(R.string.describe_placeholder)
    DescribeCard(colors) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Top) {
            Icon(Icons.Rounded.AutoAwesome, null, Modifier.padding(top = 16.dp).size(20.dp), palette.sparkle)
            OutlinedTextField(
                describe.prompt,
                model::describeEdit,
                Modifier.weight(1f).semantics { contentDescription = placeholder },
                enabled = !describe.starting,
                placeholder = { Text(placeholder, color = colors.textSecondary) },
                minLines = 2,
                maxLines = 6,
                shape = RoundedCornerShape(10.dp),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { model.describeStart() }),
                colors =
                    OutlinedTextFieldDefaults.colors(
                        focusedTextColor = colors.textPrimary,
                        unfocusedTextColor = colors.textPrimary,
                        disabledTextColor = colors.textSecondary,
                        focusedBorderColor = colors.siteLink,
                        unfocusedBorderColor = colors.border,
                        disabledBorderColor = colors.border,
                        focusedContainerColor = colors.inputBackground,
                        unfocusedContainerColor = colors.inputBackground,
                        disabledContainerColor = colors.inputBackground,
                        focusedPlaceholderColor = colors.textSecondary,
                        unfocusedPlaceholderColor = colors.textSecondary,
                        cursorColor = colors.siteLink,
                    ),
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                describeUsageText(describe.usage),
                Modifier.weight(1f),
                color = colors.textSecondary,
                style = MaterialTheme.typography.labelMedium,
            )
            Button(
                onClick = { model.describeStart() },
                enabled = describe.prompt.isNotBlank() && !describe.starting,
                colors = ButtonDefaults.buttonColors(containerColor = colors.siteButton, contentColor = Color.White),
            ) {
                Text(stringResource(if (describe.starting) R.string.describe_starting else R.string.describe_find_feeds))
            }
        }
        Text(stringResource(R.string.describe_composer_hint), color = colors.textSecondary, style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun describeUsageText(usage: DescribeUsage?): String =
    when {
        usage == null || usage.locked -> ""
        usage.limit == null -> stringResource(R.string.describe_usage_unlimited)
        else -> stringResource(R.string.describe_usage_remaining, usage.remaining ?: 0, usage.limit)
    }

@Composable
private fun DescribeUpgradeCard(
    message: String,
    colors: ReaderSheetPalette.Colors,
    palette: DescribePalette.Colors,
    onUpgrade: () -> Unit,
) {
    DescribeCard(colors, horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(Icons.Rounded.AutoAwesome, null, Modifier.size(32.dp), palette.sparkle)
        Text(stringResource(R.string.describe_upgrade_title), style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
        Text(
            message.ifBlank { stringResource(R.string.describe_upgrade_message) },
            color = colors.textSecondary,
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
        )
        Button(
            onClick = onUpgrade,
            colors = ButtonDefaults.buttonColors(containerColor = palette.upgradeButton, contentColor = palette.onUpgradeButton),
        ) { Text(stringResource(R.string.describe_upgrade_button)) }
    }
}

@Composable
private fun DescribeHistoryRail(
    describe: DescribeState,
    colors: ReaderSheetPalette.Colors,
    palette: DescribePalette.Colors,
    model: DiscoveryViewModel,
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(R.string.describe_your_searches),
                Modifier.weight(1f),
                color = colors.textSecondary,
                style = MaterialTheme.typography.titleSmall,
            )
            TextButton(
                onClick = model::describeNew,
                enabled = describe.search != null || describe.loading || describe.prompt.isNotBlank() || describe.error != null,
            ) {
                Icon(Icons.Rounded.Add, null, Modifier.size(16.dp), colors.siteLink)
                Spacer(Modifier.width(4.dp))
                Text(stringResource(R.string.describe_new_search), color = colors.siteLink)
            }
        }
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(describe.history, key = { it.id }) { entry ->
                DescribeHistoryCard(
                    entry,
                    active = entry.id == describe.search?.id,
                    colors,
                    palette,
                    onOpen = { model.describeOpen(entry.id) },
                    onDelete = { model.describeDelete(entry.id) },
                )
            }
        }
    }
}

@Composable
private fun DescribeHistoryCard(
    entry: DescribeSummary,
    active: Boolean,
    colors: ReaderSheetPalette.Colors,
    palette: DescribePalette.Colors,
    onOpen: () -> Unit,
    onDelete: () -> Unit,
) {
    val removeDescription = stringResource(R.string.describe_remove_from_history)
    val meta =
        when {
            entry.failed -> stringResource(R.string.describe_history_failed)
            entry.running -> stringResource(R.string.describe_history_searching)
            else -> pluralStringResource(R.plurals.describe_history_feeds, entry.resultCount, entry.resultCount)
        }
    Row(
        Modifier
            .width(220.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(if (active) palette.historyActive else colors.cardBackground)
            .border(1.dp, if (active) palette.historyActiveBorder else colors.border, RoundedCornerShape(10.dp))
            .clickable(role = Role.Button, onClick = onOpen)
            .semantics { selected = active }
            .padding(start = 10.dp, top = 8.dp, bottom = 8.dp, end = 2.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                entry.prompt,
                color = colors.textPrimary,
                style = MaterialTheme.typography.bodyMedium.withContentDirection(),
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                // DescribeTab.kt: the count and the day are separated by a dot like the story rows in DiscoveryFeedCard.kt.
                listOf(meta, describeRelativeDate(entry.createdDate)).filter { it.isNotBlank() }.joinToString(" · "),
                color = colors.textSecondary,
                style = MaterialTheme.typography.labelSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        IconButton(onClick = onDelete, Modifier.size(28.dp)) {
            Icon(Icons.Rounded.Close, removeDescription, Modifier.size(16.dp), colors.textSecondary)
        }
    }
}

@Composable
private fun describeRelativeDate(isoDate: String): String {
    val millis = DiscoverFeedFreshnessFormatter.parseApiDateMillis(isoDate) ?: return ""
    return DateUtils
        .getRelativeTimeSpanString(millis, System.currentTimeMillis(), DateUtils.DAY_IN_MILLIS, DateUtils.FORMAT_ABBREV_RELATIVE)
        .toString()
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DescribeStatusCard(
    describe: DescribeState,
    colors: ReaderSheetPalette.Colors,
    palette: DescribePalette.Colors,
    model: DiscoveryViewModel,
) {
    val search = describe.search
    DescribeCard(colors) {
        if (search == null) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CircularProgressIndicator(Modifier.size(18.dp), color = colors.accent, strokeWidth = 2.dp)
                Text(stringResource(R.string.describe_loading_search), color = colors.textSecondary)
            }
            return@DescribeCard
        }
        val count = search.results.size
        val message =
            when {
                search.failed -> search.error.ifBlank { stringResource(R.string.describe_status_error) }
                search.complete && count > 0 -> pluralStringResource(R.plurals.describe_status_found, count, count)
                search.complete -> stringResource(R.string.describe_status_none)
                search.phaseMessage.isNotBlank() -> search.phaseMessage
                else -> stringResource(R.string.describe_status_starting)
            }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (search.running) CircularProgressIndicator(Modifier.size(18.dp), color = colors.accent, strokeWidth = 2.dp)
            Text(
                message,
                Modifier.weight(1f),
                color = if (search.failed) colors.stale else colors.textPrimary,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
            if (!search.running) {
                TextButton(onClick = model::describeAgain, enabled = !describe.starting) {
                    Text(stringResource(R.string.describe_search_again), color = colors.siteLink)
                }
            }
        }
        DescribeStepper(search, colors, palette)
        if (search.running && count > 0) {
            Text(
                pluralStringResource(R.plurals.describe_status_so_far, count, count),
                color = colors.textSecondary,
                style = MaterialTheme.typography.labelMedium,
            )
        }
        if (search.subQueries.isNotEmpty()) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    stringResource(R.string.describe_searching_for),
                    Modifier.align(Alignment.CenterVertically),
                    color = colors.textSecondary,
                    style = MaterialTheme.typography.labelMedium,
                )
                search.subQueries.forEach { query ->
                    Text(
                        query,
                        Modifier.clip(RoundedCornerShape(999.dp)).background(palette.chip).padding(horizontal = 8.dp, vertical = 3.dp),
                        color = palette.onChip,
                        style = MaterialTheme.typography.labelMedium.withContentDirection(),
                    )
                }
            }
        }
        if (search.note.isNotBlank()) Text(search.note, color = colors.textSecondary, style = MaterialTheme.typography.bodySmall)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DescribeStepper(
    search: DescribeSearch,
    colors: ReaderSheetPalette.Colors,
    palette: DescribePalette.Colors,
) {
    val phaseIndex = if (search.complete) DescribePhase.entries.lastIndex else DescribePhase.indexOf(search.phase)
    FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        DescribePhase.entries.forEachIndexed { index, phase ->
            val done = search.complete || phaseIndex > index
            val current = search.running && phaseIndex == index
            val dot =
                when {
                    done -> palette.stepDone
                    current -> palette.stepCurrent
                    else -> palette.stepPending
                }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Box(
                    Modifier
                        .size(if (current) 10.dp else 8.dp)
                        .clip(CircleShape)
                        .background(dot),
                )
                Text(
                    stringResource(describePhaseLabel(phase)),
                    color = if (done || current) colors.textPrimary else colors.textSecondary,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = if (current) FontWeight.Bold else FontWeight.Normal,
                )
            }
        }
    }
}

@StringRes
private fun describePhaseLabel(phase: DescribePhase): Int =
    when (phase) {
        DescribePhase.EXPANDING -> R.string.describe_phase_reading
        DescribePhase.SEARCHING -> R.string.describe_phase_searching
        DescribePhase.JUDGING -> R.string.describe_phase_judging
        DescribePhase.HUNTING -> R.string.describe_phase_hunting
        DescribePhase.COMPLETE -> R.string.describe_phase_done
    }

@Composable
private fun DescribeResultCard(
    result: DescribeResult,
    state: DiscoveryState,
    model: DiscoveryViewModel,
    colors: ReaderSheetPalette.Colors,
    palette: DescribePalette.Colors,
    loader: ImageLoader,
    thumbnailLoader: ImageLoader,
) {
    val feed = result.feed
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
    ) { DescribeVerdict(result, colors, palette) }
}

// DescribeTab.kt: the judge's verdict sits under the card header, above the stories the shared card already shows.
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ColumnScope.DescribeVerdict(
    result: DescribeResult,
    colors: ReaderSheetPalette.Colors,
    palette: DescribePalette.Colors,
) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        DescribeScorePill(result, palette)
        DescribeSourceBadge(result.fromWeb, palette)
    }
    val judged = result.judged && result.reason.isNotBlank()
    Text(
        when {
            judged -> result.reason
            result.matchedQuery.isNotBlank() -> stringResource(R.string.describe_matched_query, result.matchedQuery)
            else -> stringResource(R.string.describe_waiting_verdict)
        },
        color = if (judged) colors.textPrimary else colors.textSecondary,
        style = MaterialTheme.typography.bodyMedium.withContentDirection(),
        fontStyle = if (judged) FontStyle.Normal else FontStyle.Italic,
    )
    val meta = listOfNotNull(describeStoriesPerMonth(result.feed), describeFreshness(result.feed))
    if (meta.isNotEmpty()) {
        Text(meta.joinToString(" · "), color = colors.textSecondary, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun describeStoriesPerMonth(feed: DiscoveryFeed): String? {
    if (feed.storiesPerMonth <= 0) return null
    val count = NumberFormat.getIntegerInstance().format(feed.storiesPerMonth)
    return pluralStringResource(R.plurals.discover_stories_per_month, feed.storiesPerMonth, count)
}

@Composable
private fun describeFreshness(feed: DiscoveryFeed): String? {
    val millis = DiscoverFeedFreshnessFormatter.parseApiDateMillis(feed.lastStoryDate) ?: return null
    val now = System.currentTimeMillis()
    val relative = DateUtils.getRelativeTimeSpanString(millis, now, DateUtils.MINUTE_IN_MILLIS).toString()
    val stale = now - millis >= DateUtils.YEAR_IN_MILLIS
    return stringResource(if (stale) R.string.discover_stale_updated_relative else R.string.discover_updated_relative, relative)
}

@Composable
private fun DescribeScorePill(
    result: DescribeResult,
    palette: DescribePalette.Colors,
) {
    // DescribeTab.kt: green for 8 to 10, amber for 5 to 7, grey below, like the web's NB-describe-score levels.
    val score = result.score?.takeIf { result.judged }
    val background =
        when {
            score == null -> palette.pending
            score >= 8 -> palette.scoreHigh
            score >= 5 -> palette.scoreMedium
            else -> palette.scoreLow
        }
    val foreground =
        when {
            score == null -> palette.onPending
            score >= 8 -> palette.onScoreHigh
            score >= 5 -> palette.onScoreMedium
            else -> palette.onScoreLow
        }
    val description = stringResource(R.string.describe_score_description)
    Text(
        if (score == null) stringResource(R.string.describe_judging) else stringResource(R.string.describe_score, score),
        Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(background)
            .semantics { stateDescription = description }
            .padding(horizontal = 8.dp, vertical = 3.dp),
        color = foreground,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.Bold,
    )
}

@Composable
private fun DescribeSourceBadge(
    fromWeb: Boolean,
    palette: DescribePalette.Colors,
) {
    val foreground = if (fromWeb) palette.onSourceWeb else palette.onSourceIndex
    Row(
        Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(if (fromWeb) palette.sourceWeb else palette.sourceIndex)
            .padding(horizontal = 8.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(if (fromWeb) Icons.Rounded.Public else Icons.Rounded.RssFeed, null, Modifier.size(13.dp), foreground)
        Text(
            stringResource(if (fromWeb) R.string.describe_source_web else R.string.describe_source_index),
            color = foreground,
            style = MaterialTheme.typography.labelMedium,
        )
    }
}

// DescribeTab.kt: the same eleven examples as describe_feeds_view.js EXAMPLES, in the same order.
private val describeExamples =
    listOf(
        R.string.describe_example_apps,
        R.string.describe_example_cities,
        R.string.describe_example_games,
        R.string.describe_example_recipes,
        R.string.describe_example_research,
        R.string.describe_example_houses,
        R.string.describe_example_film,
        R.string.describe_example_local,
        R.string.describe_example_books,
        R.string.describe_example_systems,
        R.string.describe_example_cycling,
    )

@Composable
private fun DescribeExamples(
    describe: DescribeState,
    colors: ReaderSheetPalette.Colors,
    palette: DescribePalette.Colors,
    model: DiscoveryViewModel,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.describe_examples_title), color = colors.textSecondary, style = MaterialTheme.typography.titleSmall)
        describeExamples.forEach { example ->
            val text = stringResource(example)
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(colors.cardBackground)
                    .border(1.dp, colors.border, RoundedCornerShape(10.dp))
                    .clickable(enabled = !describe.starting, role = Role.Button) { model.describeStart(text) }
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Icon(Icons.Rounded.AutoAwesome, null, Modifier.size(18.dp), palette.sparkle)
                Text(text, color = colors.textPrimary, style = MaterialTheme.typography.bodyMedium)
            }
        }
        if (describe.historyLoaded && describe.history.isEmpty()) {
            Text(stringResource(R.string.describe_history_empty), color = colors.textSecondary, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun DescribeCard(
    colors: ReaderSheetPalette.Colors,
    horizontalAlignment: Alignment.Horizontal = Alignment.Start,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(colors.cardBackground)
            .border(1.dp, colors.border, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        horizontalAlignment = horizontalAlignment,
        content = content,
    )
}

@Composable
private fun describeErrorText(error: DescribeError): String =
    when (error) {
        is DescribeError.Message -> error.text
        DescribeError.StartFailed -> stringResource(R.string.describe_start_failed)
        DescribeError.LoadFailed -> stringResource(R.string.describe_load_failed)
        DescribeError.DeleteFailed -> stringResource(R.string.describe_delete_failed)
    }
