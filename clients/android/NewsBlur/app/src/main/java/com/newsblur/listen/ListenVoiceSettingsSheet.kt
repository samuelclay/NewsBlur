package com.newsblur.listen

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.newsblur.R
import com.newsblur.design.ListenPalette
import com.newsblur.preference.ListenDelivery
import com.newsblur.preference.ListenVoiceSettings
import kotlin.math.roundToInt

data class ListenVoiceSettingsActions(
    val onLanguage: (String) -> Unit,
    val onSelectVoice: (ListenVoice) -> Unit,
    val onPreviewVoice: (ListenVoice) -> Unit,
    val onFilter: (String, String?) -> Unit,
    val onClearFilters: () -> Unit,
    val onSearch: (String) -> Unit,
    val onLoadMore: () -> Unit,
    val onRetryLibrary: () -> Unit,
    val onDelivery: (ListenDelivery) -> Unit,
    val onCustomChange: (ListenVoiceSettings) -> Unit,
    val onCustomDone: (ListenVoiceSettings, Boolean) -> Unit,
    val onSpeed: (Double) -> Unit,
    val onAutoContinue: (Boolean) -> Unit,
    val onHighlight: (Boolean) -> Unit,
    val onRetry: () -> Unit,
    val onUpgrade: () -> Unit,
)

/**
 * ListenVoiceSettingsSheet.kt is the voice picker, laid out like the web one: the story language and a search, one
 * row of filters, one list of voices (recommended for the language, then the rest of the library, scrolling on
 * forever), then delivery, speed, auto-continue, follow along and a collapsed fine-tune section. The selected voice's
 * soft background is the picker's only use of the accent color.
 */
@Composable
fun ListenVoiceSettingsSheet(
    state: ListenVoiceSettingsUiState,
    playback: ListenUiState,
    colors: ListenPalette.Colors,
    actions: ListenVoiceSettingsActions,
) {
    val maxHeight = LocalConfiguration.current.screenHeightDp.dp * 0.92f
    Surface(
        modifier = Modifier.fillMaxWidth().heightIn(max = maxHeight),
        color = colors.sheetBackground,
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .imePadding()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 18.dp),
        ) {
            Box(
                modifier =
                    Modifier
                        .padding(top = 10.dp, bottom = 12.dp)
                        .width(42.dp)
                        .height(4.dp)
                        .align(Alignment.CenterHorizontally)
                        .clip(CircleShape)
                        .background(colors.border),
            )
            VoiceHeader(state = state, colors = colors, onLanguage = actions.onLanguage)
            Spacer(Modifier.height(12.dp))
            SearchField(value = state.search, colors = colors, onChange = actions.onSearch)
            Spacer(Modifier.height(10.dp))
            FilterRow(state = state, colors = colors, onFilter = actions.onFilter)
            fallbackMessage(state, playback)?.let {
                Text(it, color = colors.textSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 10.dp))
            }
            Spacer(Modifier.height(10.dp))
            VoiceList(state = state, colors = colors, actions = actions)
            state.previewError?.let {
                Text(listenErrorMessage(it), color = colors.error, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp))
            }
            Spacer(Modifier.height(16.dp))
            SettingsCard(state = state, playbackSpeed = playback.speed, colors = colors, actions = actions)
            ListenUsageFooter(
                usage = state.usage ?: playback.usage,
                colors = colors,
                onUpgrade = actions.onUpgrade,
                modifier = Modifier.padding(top = 10.dp, start = 4.dp),
            )
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun fallbackMessage(
    state: ListenVoiceSettingsUiState,
    playback: ListenUiState,
): String? {
    val voice = playback.voice?.name ?: return null
    if (!playback.voiceFallback || playback.language != state.language) return null
    return stringResource(R.string.listen_voice_fallback_status, voice)
}

@Composable
private fun VoiceHeader(
    state: ListenVoiceSettingsUiState,
    colors: ListenPalette.Colors,
    onLanguage: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = stringResource(R.string.listen_voice_title),
                color = colors.textPrimary,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = stringResource(R.string.listen_reads_language, state.languageName),
                color = colors.textSecondary,
                fontSize = 13.sp,
            )
        }
        Box {
            Row(
                modifier =
                    Modifier
                        .clip(RoundedCornerShape(50))
                        .border(1.dp, colors.border, RoundedCornerShape(50))
                        .clickable(role = Role.DropdownList, onClickLabel = stringResource(R.string.listen_language)) {
                            expanded = true
                        }.padding(start = 12.dp, end = 6.dp, top = 6.dp, bottom = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(state.languageName, color = colors.textPrimary, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                Icon(Icons.Rounded.ExpandMore, null, tint = colors.textSecondary, modifier = Modifier.size(18.dp))
            }
            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
                modifier = Modifier.background(colors.cardBackground),
            ) {
                state.languages.forEach { language ->
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = language.name,
                                color = colors.textPrimary,
                                fontWeight = if (language.code == state.language) FontWeight.Bold else FontWeight.Normal,
                            )
                        },
                        onClick = {
                            expanded = false
                            onLanguage(language.code)
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun SearchField(
    value: String,
    colors: ListenPalette.Colors,
    onChange: (String) -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(colors.inputBackground)
                .border(1.dp, colors.border, RoundedCornerShape(12.dp))
                .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.Search, null, tint = colors.textSecondary, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Box(modifier = Modifier.weight(1f)) {
            if (value.isEmpty()) {
                Text(stringResource(R.string.listen_search_voices), color = colors.textSecondary, fontSize = 15.sp)
            }
            BasicTextField(
                value = value,
                onValueChange = onChange,
                singleLine = true,
                textStyle = TextStyle(color = colors.textPrimary, fontSize = 15.sp),
                cursorBrush = SolidColor(colors.textPrimary),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        if (value.isNotEmpty()) {
            Icon(
                imageVector = Icons.Rounded.Close,
                contentDescription = stringResource(R.string.listen_clear),
                tint = colors.textSecondary,
                modifier =
                    Modifier
                        .size(20.dp)
                        .clip(CircleShape)
                        .clickable(role = Role.Button) { onChange("") },
            )
        }
    }
}

@Composable
private fun FilterRow(
    state: ListenVoiceSettingsUiState,
    colors: ListenPalette.Colors,
    onFilter: (String, String?) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        ListenVoiceMatching.FILTER_KEYS.forEach { key ->
            val options =
                if (key == ListenFilters.KEY_ACCENT) {
                    state.filters.accentsFor(state.language).map { ListenFilterOption(it, ListenFilters.displayAccent(it)) }
                } else {
                    state.filters.options[key].orEmpty()
                }
            FilterMenu(
                placeholder = filterPlaceholder(key),
                selected = state.activeFilters[key],
                options = options,
                colors = colors,
                onSelect = { onFilter(key, it) },
            )
        }
    }
}

@Composable
private fun filterPlaceholder(key: String): String =
    stringResource(
        when (key) {
            ListenFilters.KEY_GENDER -> R.string.listen_filter_gender
            ListenFilters.KEY_AGE -> R.string.listen_filter_age
            ListenFilters.KEY_ACCENT -> R.string.listen_filter_accent
            else -> R.string.listen_filter_style
        },
    )

@Composable
private fun FilterMenu(
    placeholder: String,
    selected: String?,
    options: List<ListenFilterOption>,
    colors: ListenPalette.Colors,
    onSelect: (String?) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedLabel =
        selected?.let { value -> options.firstOrNull { it.value == value }?.label ?: ListenFilters.displayAccent(value) }
    val active = selectedLabel != null
    Box {
        Row(
            modifier =
                Modifier
                    .clip(RoundedCornerShape(50))
                    .background(if (active) colors.cardBackground else colors.chipBackground)
                    .border(1.dp, if (active) colors.textSecondary else colors.chipBackground, RoundedCornerShape(50))
                    .clickable(enabled = options.isNotEmpty(), role = Role.DropdownList, onClickLabel = placeholder) {
                        expanded = true
                    }.padding(start = 12.dp, end = if (active) 4.dp else 8.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = selectedLabel ?: placeholder,
                color = if (options.isEmpty()) colors.textSecondary else colors.textPrimary,
                fontSize = 13.sp,
                fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                maxLines = 1,
            )
            if (active) {
                Icon(
                    imageVector = Icons.Rounded.Close,
                    contentDescription = stringResource(R.string.listen_clear_filter, placeholder),
                    tint = colors.textSecondary,
                    modifier =
                        Modifier
                            .padding(start = 4.dp)
                            .size(20.dp)
                            .clip(CircleShape)
                            .clickable(role = Role.Button) { onSelect(null) }
                            .padding(2.dp),
                )
            } else {
                Icon(Icons.Rounded.ExpandMore, null, tint = colors.textSecondary, modifier = Modifier.size(16.dp))
            }
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.background(colors.cardBackground),
        ) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = {
                        Text(
                            text = option.label ?: ListenFilters.displayAccent(option.value),
                            color = colors.textPrimary,
                            fontWeight = if (option.value == selected) FontWeight.Bold else FontWeight.Normal,
                        )
                    },
                    onClick = {
                        expanded = false
                        onSelect(option.value)
                    },
                )
            }
        }
    }
}

@Composable
private fun VoiceList(
    state: ListenVoiceSettingsUiState,
    colors: ListenPalette.Colors,
    actions: ListenVoiceSettingsActions,
) {
    val recommended = state.recommended
    val more = state.moreVoices
    val listState = rememberLazyListState()
    val nearEnd by remember {
        derivedStateOf {
            val info = listState.layoutInfo
            val last = info.visibleItemsInfo.lastOrNull()?.index ?: return@derivedStateOf false
            info.totalItemsCount > 0 && last >= info.totalItemsCount - LOAD_MORE_THRESHOLD
        }
    }
    // A new language, filter or search starts the list back at the top.
    LaunchedEffect(state.language, state.activeFilters, state.search) { listState.scrollToItem(0) }
    LaunchedEffect(nearEnd, state.library.hasMore, state.library.loading) {
        if (nearEnd && state.library.hasMore && !state.library.loading) actions.onLoadMore()
    }
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = colors.cardBackground,
        modifier = Modifier.fillMaxWidth().border(1.dp, colors.border.copy(alpha = 0.6f), RoundedCornerShape(14.dp)),
    ) {
        LazyColumn(state = listState, modifier = Modifier.fillMaxWidth().height(VOICE_LIST_HEIGHT.dp)) {
            val stillLoading = state.loading || state.library.loading
            val error = state.error
            when {
                error != null && recommended.isEmpty() && more.isEmpty() ->
                    item { InlineError(error, colors, actions.onRetry) }
                recommended.isEmpty() && more.isEmpty() && stillLoading -> item { LoadingRow(colors) }
                recommended.isEmpty() && more.isEmpty() ->
                    item { EmptyState(hasFilters = state.hasFilters, colors = colors, onClear = actions.onClearFilters) }
                else -> voiceSections(state, recommended, more, colors, actions)
            }
        }
    }
}

private fun LazyListScope.voiceSections(
    state: ListenVoiceSettingsUiState,
    recommended: List<ListenVoice>,
    more: List<ListenVoice>,
    colors: ListenPalette.Colors,
    actions: ListenVoiceSettingsActions,
) {
    if (recommended.isNotEmpty()) {
        item(key = "recommended-header") {
            ListHeader(
                title = stringResource(R.string.listen_recommended_for, state.languageName),
                count =
                    if (state.hasFilters) {
                        pluralStringResource(R.plurals.listen_match_count, recommended.size, recommended.size)
                    } else {
                        null
                    },
                colors = colors,
            )
        }
        items(recommended, key = { "r-" + it.voiceId }) { voice -> VoiceRow(voice, state, colors, actions) }
    }
    val libraryError = state.library.error
    if (more.isNotEmpty() || state.library.loading || libraryError != null) {
        item(key = "more-header") { ListHeader(title = stringResource(R.string.listen_more_voices), count = null, colors = colors) }
        items(more, key = { "m-" + it.voiceId }) { voice -> VoiceRow(voice, state, colors, actions) }
        when {
            state.library.loading -> item(key = "more-loading") { LoadingRow(colors) }
            libraryError != null -> item(key = "more-error") { InlineError(libraryError, colors, actions.onRetryLibrary) }
        }
    }
}

@Composable
private fun ListHeader(
    title: String,
    count: String?,
    colors: ListenPalette.Colors,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .background(colors.cardBackground)
                .padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            color = colors.textSecondary,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        count?.let { Text(it, color = colors.textSecondary, fontSize = 12.sp) }
    }
}

@Composable
private fun VoiceRow(
    voice: ListenVoice,
    state: ListenVoiceSettingsUiState,
    colors: ListenPalette.Colors,
    actions: ListenVoiceSettingsActions,
) {
    val selected = voice.voiceId == state.selectedVoiceId
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 6.dp, vertical = 2.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(if (selected) colors.accent.copy(alpha = SELECTED_ROW_ALPHA) else colors.cardBackground)
                .clickable(role = Role.RadioButton) { actions.onSelectVoice(voice) }
                .padding(start = 8.dp, end = 4.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(modifier = Modifier.size(22.dp), contentAlignment = Alignment.Center) {
            if (selected) {
                Icon(
                    Icons.Rounded.Check,
                    stringResource(R.string.listen_voice_selected),
                    tint = colors.textPrimary,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
        Spacer(Modifier.width(6.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text =
                    buildAnnotatedString {
                        withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = colors.textPrimary)) { append(voice.name) }
                        voice.description?.takeIf { it.isNotBlank() }?.let { description ->
                            withStyle(SpanStyle(color = colors.textSecondary)) { append("  $description") }
                        }
                    },
                fontSize = 15.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            voiceTraits(voice, state.filters).takeIf { it.isNotBlank() }?.let { traits ->
                Text(
                    text = traits,
                    color = colors.textSecondary.copy(alpha = 0.85f),
                    fontSize = 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        PreviewButton(
            loading = state.previewLoadingVoiceId == voice.voiceId,
            playing = state.previewingVoiceId == voice.voiceId,
            colors = colors,
            onClick = { actions.onPreviewVoice(voice) },
        )
    }
}

@Composable
private fun PreviewButton(
    loading: Boolean,
    playing: Boolean,
    colors: ListenPalette.Colors,
    onClick: () -> Unit,
) {
    val description = stringResource(if (playing || loading) R.string.listen_stop_preview else R.string.listen_preview_voice)
    Box(
        modifier =
            Modifier
                .padding(start = 6.dp)
                .size(36.dp)
                .clip(CircleShape)
                .border(1.dp, colors.border, CircleShape)
                .clickable(role = Role.Button, onClickLabel = description, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        when {
            loading -> CircularProgressIndicator(color = colors.textSecondary, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
            playing -> Icon(Icons.Rounded.Stop, description, tint = colors.textPrimary, modifier = Modifier.size(18.dp))
            else -> Icon(Icons.Rounded.PlayArrow, description, tint = colors.textPrimary, modifier = Modifier.size(20.dp))
        }
    }
}

/** "Male · Middle aged · American", using the server's localized labels where it has them. */
private fun voiceTraits(
    voice: ListenVoice,
    filters: ListenFilters,
): String {
    fun label(
        key: String,
        value: String?,
    ): String? {
        if (value.isNullOrBlank()) return null
        return filters.options[key]?.firstOrNull { it.value == value }?.label ?: ListenFilters.displayAccent(value)
    }
    return listOfNotNull(
        label(ListenFilters.KEY_GENDER, voice.gender),
        label(ListenFilters.KEY_AGE, voice.age),
        voice.accent?.takeIf { it.isNotBlank() }?.let(ListenFilters::displayAccent),
    ).joinToString(" · ")
}

@Composable
private fun EmptyState(
    hasFilters: Boolean,
    colors: ListenPalette.Colors,
    onClear: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(stringResource(R.string.listen_no_voices_match), color = colors.textSecondary, fontSize = 14.sp)
        if (hasFilters) {
            Text(
                text = stringResource(R.string.listen_clear_filters),
                color = colors.textPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                modifier =
                    Modifier
                        .padding(top = 10.dp)
                        .clip(RoundedCornerShape(50))
                        .border(1.dp, colors.border, RoundedCornerShape(50))
                        .clickable(role = Role.Button, onClick = onClear)
                        .padding(horizontal = 14.dp, vertical = 7.dp),
            )
        }
    }
}

@Composable
private fun LoadingRow(colors: ListenPalette.Colors) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(18.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CircularProgressIndicator(color = colors.textSecondary, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(10.dp))
        Text(stringResource(R.string.listen_loading_voices), color = colors.textSecondary, fontSize = 13.sp)
    }
}

@Composable
private fun InlineError(
    error: ListenError,
    colors: ListenPalette.Colors,
    onRetry: () -> Unit,
) {
    Row(modifier = Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(listenErrorMessage(error), color = colors.error, fontSize = 13.sp, modifier = Modifier.weight(1f))
        Spacer(Modifier.width(10.dp))
        Text(
            text = stringResource(R.string.listen_retry),
            color = colors.textPrimary,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.clickable(role = Role.Button, onClick = onRetry).padding(6.dp),
        )
    }
}

@Composable
private fun SettingsCard(
    state: ListenVoiceSettingsUiState,
    playbackSpeed: Double,
    colors: ListenPalette.Colors,
    actions: ListenVoiceSettingsActions,
) {
    val settings = state.settings
    val divider = colors.border.copy(alpha = 0.6f)
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = colors.cardBackground,
        modifier = Modifier.fillMaxWidth().border(1.dp, divider, RoundedCornerShape(14.dp)),
    ) {
        Column {
            // Custom only appears once the fine-tune sliders are in use.
            val deliveries =
                ListenDelivery.presets + if (settings.delivery == ListenDelivery.CUSTOM) listOf(ListenDelivery.CUSTOM) else emptyList()
            SettingRow(stringResource(R.string.listen_delivery), stringResource(R.string.listen_delivery_summary), colors) {
                Segmented(
                    options = deliveries.map { it to deliveryLabel(it) },
                    selected = settings.delivery,
                    colors = colors,
                    onSelect = actions.onDelivery,
                )
            }
            HorizontalDivider(color = divider)
            SettingRow(stringResource(R.string.listen_speed), stringResource(R.string.listen_speed_summary), colors) {
                ListenSpeedControl(speed = playbackSpeed, colors = colors, onSpeed = actions.onSpeed)
            }
            HorizontalDivider(color = divider)
            SettingRow(
                stringResource(R.string.listen_auto_continue_title),
                stringResource(R.string.listen_auto_continue_summary),
                colors,
            ) {
                OnOff(checked = settings.autoContinue, colors = colors, onChange = actions.onAutoContinue)
            }
            HorizontalDivider(color = divider)
            SettingRow(stringResource(R.string.listen_follow_along), stringResource(R.string.listen_follow_along_summary), colors) {
                OnOff(checked = settings.highlight, colors = colors, onChange = actions.onHighlight)
            }
            HorizontalDivider(color = divider)
            FineTune(state = state, colors = colors, actions = actions)
        }
    }
}

@Composable
private fun SettingRow(
    title: String,
    description: String,
    colors: ListenPalette.Colors,
    control: @Composable () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth().padding(14.dp)) {
        Text(title, color = colors.textPrimary, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        Text(description, color = colors.textSecondary, fontSize = 12.sp)
        Spacer(Modifier.height(10.dp))
        control()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun <T> Segmented(
    options: List<Pair<T, String>>,
    selected: T?,
    colors: ListenPalette.Colors,
    onSelect: (T) -> Unit,
) {
    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
        options.forEachIndexed { index, (value, label) ->
            SegmentedButton(
                selected = value == selected,
                onClick = { onSelect(value) },
                shape = SegmentedButtonDefaults.itemShape(index = index, count = options.size),
                colors =
                    SegmentedButtonDefaults.colors(
                        activeContainerColor = colors.chipBackground,
                        activeContentColor = colors.textPrimary,
                        activeBorderColor = colors.border,
                        inactiveContainerColor = colors.cardBackground,
                        inactiveContentColor = colors.textSecondary,
                        inactiveBorderColor = colors.border,
                    ),
                icon = {},
                label = {
                    Text(
                        text = label,
                        fontSize = 13.sp,
                        fontWeight = if (value == selected) FontWeight.Bold else FontWeight.Normal,
                        maxLines = 1,
                        softWrap = false,
                    )
                },
            )
        }
    }
}

@Composable
private fun OnOff(
    checked: Boolean,
    colors: ListenPalette.Colors,
    onChange: (Boolean) -> Unit,
) {
    Segmented(
        options = listOf(true to stringResource(R.string.listen_on), false to stringResource(R.string.listen_off)),
        selected = checked,
        colors = colors,
        onSelect = onChange,
    )
}

@Composable
private fun FineTune(
    state: ListenVoiceSettingsUiState,
    colors: ListenPalette.Colors,
    actions: ListenVoiceSettingsActions,
) {
    var expanded by remember { mutableStateOf(false) }
    val values = state.voiceSettings
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(role = Role.Button) { expanded = !expanded }
                .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(stringResource(R.string.listen_fine_tune), color = colors.textPrimary, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.listen_fine_tune_summary), color = colors.textSecondary, fontSize = 12.sp)
        }
        Icon(if (expanded) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore, null, tint = colors.textSecondary)
    }
    AnimatedVisibility(expanded) {
        Column(modifier = Modifier.padding(start = 14.dp, end = 14.dp, bottom = 14.dp)) {
            val done = { actions.onCustomDone(state.voiceSettings, state.settings.speakerBoost) }
            SliderRow(
                title = stringResource(R.string.listen_stability),
                description = stringResource(R.string.listen_stability_summary),
                value = values.stability,
                colors = colors,
                onChange = { actions.onCustomChange(values.copy(stability = it)) },
                onDone = done,
            )
            SliderRow(
                title = stringResource(R.string.listen_similarity),
                description = stringResource(R.string.listen_similarity_summary),
                value = values.similarity,
                colors = colors,
                onChange = { actions.onCustomChange(values.copy(similarity = it)) },
                onDone = done,
            )
            SliderRow(
                title = stringResource(R.string.listen_style),
                description = stringResource(R.string.listen_style_summary),
                value = values.style,
                colors = colors,
                onChange = { actions.onCustomChange(values.copy(style = it)) },
                onDone = done,
            )
            Spacer(Modifier.height(6.dp))
            Text(stringResource(R.string.listen_speaker_boost), color = colors.textPrimary, fontSize = 14.sp)
            Text(stringResource(R.string.listen_speaker_boost_summary), color = colors.textSecondary, fontSize = 12.sp)
            Spacer(Modifier.height(8.dp))
            OnOff(checked = state.settings.speakerBoost, colors = colors, onChange = { actions.onCustomDone(values, it) })
        }
    }
}

@Composable
private fun SliderRow(
    title: String,
    description: String,
    value: Double,
    colors: ListenPalette.Colors,
    onChange: (Double) -> Unit,
    onDone: () -> Unit,
) {
    Column(modifier = Modifier.padding(top = 6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(title, color = colors.textPrimary, fontSize = 14.sp)
                Text(description, color = colors.textSecondary, fontSize = 12.sp)
            }
            Text(
                text = stringResource(R.string.listen_percent, (value * 100).roundToInt()),
                color = colors.textSecondary,
                fontSize = 13.sp,
            )
        }
        Slider(
            value = value.toFloat(),
            onValueChange = { onChange(it.toDouble()) },
            onValueChangeFinished = onDone,
            valueRange = 0f..1f,
            colors =
                SliderDefaults.colors(
                    thumbColor = colors.textPrimary,
                    activeTrackColor = colors.textSecondary,
                    inactiveTrackColor = colors.progressTrack,
                ),
        )
    }
}

@Composable
private fun deliveryLabel(delivery: ListenDelivery): String =
    stringResource(
        when (delivery) {
            ListenDelivery.STEADY -> R.string.listen_delivery_steady
            ListenDelivery.NATURAL -> R.string.listen_delivery_natural
            ListenDelivery.EXPRESSIVE -> R.string.listen_delivery_expressive
            ListenDelivery.CUSTOM -> R.string.listen_delivery_custom
        },
    )

private const val VOICE_LIST_HEIGHT = 360
private const val LOAD_MORE_THRESHOLD = 5
private const val SELECTED_ROW_ALPHA = 0.16f
