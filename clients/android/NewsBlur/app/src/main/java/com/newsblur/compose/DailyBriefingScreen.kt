@file:OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)

package com.newsblur.compose

import android.os.SystemClock
import android.view.View
import android.view.ViewGroup
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.R
import com.newsblur.activity.NbActivity
import com.newsblur.database.StoryViewAdapter
import com.newsblur.design.LocalNbColors
import com.newsblur.domain.Story
import com.newsblur.network.domain.DailyBriefingModelOption
import com.newsblur.util.DailyBriefingPresentationState
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.ImageLoader
import com.newsblur.util.StoryListStyle
import com.newsblur.viewModel.DailyBriefingDraft
import com.newsblur.viewModel.DailyBriefingGroupUi
import com.newsblur.viewModel.DailyBriefingSectionDefinition
import com.newsblur.viewModel.DailyBriefingUiState
import com.newsblur.viewModel.DailyBriefingViewModel
import com.newsblur.preference.PrefsRepo
import com.newsblur.view.ExpandedHeightRecyclerView
import com.newsblur.util.PrefConstants.ThemeValue

private data class DailyBriefingPalette(
    val screen: Color,
    val card: Color,
    val cardAlt: Color,
    val title: Color,
    val body: Color,
    val muted: Color,
    val accent: Color,
    val border: Color,
    val unread: Color,
)

private data class DailyBriefingSectionPalette(
    val background: Color,
    val border: Color,
    val title: Color,
    val date: Color,
)

private data class BriefingChoiceOption<T>(
    val value: T,
    val title: String,
)

data class DailyBriefingStoryTableConfig(
    val activity: NbActivity,
    val iconLoader: ImageLoader,
    val thumbnailLoader: ImageLoader,
    val feedUtils: FeedUtils,
    val prefsRepo: PrefsRepo,
)

@Composable
private fun rememberDailyBriefingPalette(): DailyBriefingPalette {
    val nb = LocalNbColors.current
    val cs = MaterialTheme.colorScheme
    return remember(nb, cs) {
        DailyBriefingPalette(
            screen = nb.itemBackgroundDarkAlt,
            card = nb.itemBackground,
            cardAlt = cs.surfaceVariant.copy(alpha = 0.55f),
            title = nb.textDefault,
            body = nb.textSnippet,
            muted = nb.textMeta,
            accent = cs.primary,
            border = nb.rowBorder,
            unread = cs.primary,
        )
    }
}

@Composable
private fun rememberDailyBriefingSectionPalette(prefsRepo: PrefsRepo): DailyBriefingSectionPalette {
    val selectedTheme = prefsRepo.getSelectedTheme()
    val effectiveTheme =
        when (selectedTheme) {
            ThemeValue.AUTO -> if (isSystemInDarkTheme()) ThemeValue.DARK else ThemeValue.LIGHT
            else -> selectedTheme
        }

    return remember(effectiveTheme) {
        when (effectiveTheme) {
            ThemeValue.LIGHT ->
                DailyBriefingSectionPalette(
                    background = Color(0xFFEAECE6),
                    border = Color(0xFFD9DDD5),
                    title = Color(0xFF4C4D4A),
                    date = Color(0xFF767974),
                )
            ThemeValue.SEPIA ->
                DailyBriefingSectionPalette(
                    background = Color(0xFFE9DECE),
                    border = Color(0xFFD9CDBE),
                    title = Color(0xFF5C4A3D),
                    date = Color(0xFF7D6F61),
                )
            ThemeValue.DARK ->
                DailyBriefingSectionPalette(
                    background = Color(0xFF3A3A3C),
                    border = Color(0xFF4A4A4C),
                    title = Color(0xFFE0E0E0),
                    date = Color(0xFFA5A5AA),
                )
            ThemeValue.BLACK ->
                DailyBriefingSectionPalette(
                    background = Color(0xFF2C2C2E),
                    border = Color(0xFF242426),
                    title = Color(0xFFE8E8E8),
                    date = Color(0xFF98989D),
                )
            ThemeValue.AUTO -> error("AUTO should resolve to a concrete theme")
        }
    }
}

@Composable
fun DailyBriefingScreen(
    state: DailyBriefingUiState,
    storyTableConfig: DailyBriefingStoryTableConfig,
    onToggleGroup: (String) -> Unit,
    onLoadMoreIfNeeded: (String) -> Unit,
    onStoryClick: (String) -> Unit,
    onPremiumClick: () -> Unit,
    onHideSettings: () -> Unit,
    onSavePreferences: (DailyBriefingDraft, Boolean) -> Unit,
) {
    val palette = rememberDailyBriefingPalette()
    val sectionPalette = rememberDailyBriefingSectionPalette(storyTableConfig.prefsRepo)

    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .background(palette.screen),
    ) {
        when (state.presentationState) {
            DailyBriefingPresentationState.LOADING -> LoadingState()
            DailyBriefingPresentationState.SETTINGS -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    item {
                        DailyBriefingMessages(state = state)
                    }
                    item {
                        DailyBriefingSetupView(
                            state = state,
                            onSavePreferences = onSavePreferences,
                        )
                    }
                }
            }
            DailyBriefingPresentationState.EMPTY -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    item {
                        DailyBriefingMessages(state = state)
                    }
                    item {
                        DailyBriefingEmptyView(
                            hasPreferences = state.preferences != null,
                            onGenerate = {
                                state.preferences?.let { onSavePreferences(it, true) }
                            },
                        )
                    }
                }
            }
            DailyBriefingPresentationState.STORIES -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(vertical = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    item {
                        DailyBriefingMessages(state = state)
                    }
                    itemsIndexed(state.groups, key = { _, group -> group.briefingId }) { index, group ->
                        if (index == state.groups.lastIndex) {
                            onLoadMoreIfNeeded(group.briefingId)
                        }
                        DailyBriefingGroupCard(
                            group = group,
                            sectionPalette = sectionPalette,
                            storyTableConfig = storyTableConfig,
                            collapsed = state.collapsedGroupIds.contains(group.briefingId),
                            onToggleGroup = onToggleGroup,
                            onStoryClick = onStoryClick,
                            onPremiumClick = onPremiumClick,
                        )
                    }
                    if (state.isLoadingMore) {
                        item {
                            Box(
                                modifier = Modifier.fillMaxWidth(),
                                contentAlignment = Alignment.Center,
                            ) {
                                CircularProgressIndicator()
                            }
                        }
                    }
                }
            }
        }

        if (state.showSettingsSheet && state.preferences != null) {
            ModalBottomSheet(onDismissRequest = onHideSettings) {
                DailyBriefingSettingsSheet(
                    state = state,
                    onDismiss = onHideSettings,
                    onSavePreferences = onSavePreferences,
                )
            }
        }
    }
}

@Composable
private fun LoadingState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator()
    }
}

@Composable
private fun DailyBriefingMessages(state: DailyBriefingUiState) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        state.errorMessage?.let { message ->
            DailyBriefingMessageCard(
                title = "Unable to load Daily Briefing",
                message = message,
                isError = true,
            )
        }
        state.progressMessage?.let { message ->
            DailyBriefingMessageCard(
                title = "Working…",
                message = message,
                isError = false,
            )
        }
    }
}

@Composable
private fun DailyBriefingMessageCard(
    title: String,
    message: String,
    isError: Boolean,
) {
    val palette = rememberDailyBriefingPalette()
    Card(
        colors =
            CardDefaults.cardColors(
                containerColor = if (isError) palette.cardAlt else palette.card,
            ),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = if (isError) MaterialTheme.colorScheme.error else palette.title,
            )
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = palette.body,
            )
            if (!isError) {
                Spacer(Modifier.height(6.dp))
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            }
        }
    }
}

@Composable
private fun DailyBriefingEmptyView(
    hasPreferences: Boolean,
    onGenerate: () -> Unit,
) {
    val palette = rememberDailyBriefingPalette()
    Card(
        colors = CardDefaults.cardColors(containerColor = palette.card),
        shape = RoundedCornerShape(22.dp),
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            androidx.compose.foundation.Image(
                painter = painterResource(R.drawable.ic_briefing),
                contentDescription = null,
                modifier = Modifier.size(44.dp),
            )
            Text(
                text = "No briefings yet",
                style = MaterialTheme.typography.headlineSmall,
                color = palette.title,
                textAlign = TextAlign.Center,
            )
            Text(
                text = "Set up Daily Briefing to generate a summary of the stories that matter most to you.",
                style = MaterialTheme.typography.bodyMedium,
                color = palette.body,
                textAlign = TextAlign.Center,
            )
            if (hasPreferences) {
                Button(onClick = onGenerate) {
                    Text("Generate Daily Briefing")
                }
            }
        }
    }
}

@Composable
private fun DailyBriefingSetupView(
    state: DailyBriefingUiState,
    onSavePreferences: (DailyBriefingDraft, Boolean) -> Unit,
) {
    var draft by remember(state.preferences) {
        mutableStateOf(state.preferences ?: DailyBriefingDraft())
    }
    val palette = rememberDailyBriefingPalette()

    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.card),
            shape = RoundedCornerShape(22.dp),
        ) {
            Column(
                modifier = Modifier.padding(22.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                androidx.compose.foundation.Image(
                    painter = painterResource(R.drawable.ic_briefing),
                    contentDescription = null,
                    modifier = Modifier.size(42.dp),
                )
                Text(
                    text = "Daily Briefing",
                    style = MaterialTheme.typography.headlineMedium,
                    color = palette.title,
                )
                Text(
                    text = "Get a summary of your top stories, delivered on your schedule.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = palette.body,
                )
            }
        }

        DailyBriefingSettingsForm(
            draft = draft,
            isSaving = state.isSaving,
            isGenerating = state.isGenerating,
            progressMessage = state.progressMessage,
            showsSaveButton = false,
            onDraftChange = { draft = it },
            onSavePreferences = onSavePreferences,
        )
    }
}

@Composable
private fun DailyBriefingSettingsSheet(
    state: DailyBriefingUiState,
    onDismiss: () -> Unit,
    onSavePreferences: (DailyBriefingDraft, Boolean) -> Unit,
) {
    var draft by remember(state.preferences) {
        mutableStateOf(state.preferences ?: DailyBriefingDraft())
    }
    val palette = rememberDailyBriefingPalette()

    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = "Daily Briefing Settings",
            style = MaterialTheme.typography.headlineSmall,
            color = palette.title,
        )
        if (state.errorMessage != null) {
            DailyBriefingMessageCard(
                title = "Save failed",
                message = state.errorMessage,
                isError = true,
            )
        }
        DailyBriefingSettingsForm(
            draft = draft,
            isSaving = state.isSaving,
            isGenerating = state.isGenerating,
            progressMessage = state.progressMessage,
            showsSaveButton = true,
            onDraftChange = { draft = it },
            onSavePreferences = onSavePreferences,
        )
        Spacer(Modifier.height(8.dp))
        OutlinedButton(
            modifier = Modifier.fillMaxWidth(),
            onClick = onDismiss,
        ) {
            Text("Close")
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun DailyBriefingSettingsForm(
    draft: DailyBriefingDraft,
    isSaving: Boolean,
    isGenerating: Boolean,
    progressMessage: String?,
    showsSaveButton: Boolean,
    onDraftChange: (DailyBriefingDraft) -> Unit,
    onSavePreferences: (DailyBriefingDraft, Boolean) -> Unit,
) {
    val builtInSections = DailyBriefingViewModel.builtInSections

    val frequencyOptions =
        listOf(
            BriefingChoiceOption("thrice_daily", "3x daily"),
            BriefingChoiceOption("twice_daily", "2x daily"),
            BriefingChoiceOption("daily", "Daily"),
            BriefingChoiceOption("weekly", "Weekly"),
        )
    val timeOptions =
        listOf(
            BriefingChoiceOption("morning", "Morning"),
            BriefingChoiceOption("afternoon", "Afternoon"),
            BriefingChoiceOption("evening", "Evening"),
        )
    val dayOptions =
        listOf(
            BriefingChoiceOption("sun", "Sunday"),
            BriefingChoiceOption("mon", "Monday"),
            BriefingChoiceOption("tue", "Tuesday"),
            BriefingChoiceOption("wed", "Wednesday"),
            BriefingChoiceOption("thu", "Thursday"),
            BriefingChoiceOption("fri", "Friday"),
            BriefingChoiceOption("sat", "Saturday"),
        )
    val storyCountOptions =
        listOf(
            BriefingChoiceOption(5, "5"),
            BriefingChoiceOption(10, "10"),
            BriefingChoiceOption(15, "15"),
            BriefingChoiceOption(20, "20"),
            BriefingChoiceOption(25, "25"),
        )
    val summaryStyleOptions =
        listOf(
            BriefingChoiceOption("bullets", "Bullets"),
            BriefingChoiceOption("editorial", "Editorial"),
            BriefingChoiceOption("headlines", "Headlines"),
        )
    val readFilterOptions =
        listOf(
            BriefingChoiceOption("unread", "Unread"),
            BriefingChoiceOption("focus", "Focus"),
        )

    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        SettingsCard(
            title = "Auto-generate",
            subtitle = "Automatically create briefings on your schedule",
        ) {
            ToggleRow(
                title = "Enabled",
                checked = draft.enabled,
                onCheckedChange = { onDraftChange(draft.copy(enabled = it)) },
            )
        }

        SettingsCard(
            title = "Schedule",
            subtitle = "Choose how often and when your briefing is generated",
        ) {
            ChoiceChipGroup(
                label = "Frequency",
                selectedValue = draft.frequency,
                options = frequencyOptions,
                onSelected = { onDraftChange(draft.copy(frequency = it)) },
            )
            ChoiceChipGroup(
                label = "Preferred time",
                selectedValue = draft.preferredTime,
                options = timeOptions,
                onSelected = { onDraftChange(draft.copy(preferredTime = it)) },
            )
            if (draft.frequency == "weekly") {
                ChoiceChipGroup(
                    label = "Preferred day",
                    selectedValue = draft.preferredDay,
                    options = dayOptions,
                    onSelected = { onDraftChange(draft.copy(preferredDay = it)) },
                )
            }
        }

        SettingsCard(
            title = "Length & Style",
            subtitle = "Control how much is included and how it is written",
        ) {
            ChoiceChipGroup(
                label = "Story count",
                selectedValue = draft.storyCount,
                options = storyCountOptions,
                onSelected = { onDraftChange(draft.copy(storyCount = it)) },
            )
            ChoiceChipGroup(
                label = "Writing style",
                selectedValue = draft.summaryStyle,
                options = summaryStyleOptions,
                onSelected = { onDraftChange(draft.copy(summaryStyle = it)) },
            )
        }

        SettingsCard(
            title = "Sources",
            subtitle = "Choose which stories are eligible for Daily Briefing",
        ) {
            ChoiceDropdown(
                title = "Feed source",
                selectedLabel = draft.selectedFolder ?: "All Site Stories",
                options =
                    listOf(
                        BriefingChoiceOption<String?>(null, "All Site Stories"),
                    ) + draft.folders.map { folder ->
                        BriefingChoiceOption(folder, folder)
                    },
                onSelected = { folder -> onDraftChange(draft.withSelectedFolder(folder)) },
            )
            ChoiceChipGroup(
                label = "Filter",
                selectedValue = draft.readFilter,
                options = readFilterOptions,
                onSelected = { onDraftChange(draft.copy(readFilter = it)) },
            )
            ToggleRow(
                title = "Include already-read stories",
                checked = draft.includeRead,
                onCheckedChange = { onDraftChange(draft.copy(includeRead = it)) },
            )
        }

        SettingsCard(
            title = "Sections",
            subtitle = "Only sections with matching stories will be included",
        ) {
            builtInSections.forEach { section ->
                SectionToggle(
                    definition = section,
                    checked = draft.builtInSections[section.key] ?: true,
                    onCheckedChange = { checked ->
                        onDraftChange(
                            draft.copy(
                                builtInSections = draft.builtInSections + (section.key to checked),
                            ),
                        )
                    },
                )
            }
        }

        SettingsCard(
            title = "Keyword Sections",
            subtitle = "Add custom keyword filters that become their own briefing sections",
        ) {
            draft.customSectionPrompts.forEachIndexed { index, value ->
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    ToggleRow(
                        title = "Keyword section ${index + 1}",
                        checked = draft.customSectionEnabled.getOrElse(index) { true },
                        onCheckedChange = { enabled ->
                            val updated = draft.customSectionEnabled.toMutableList()
                            if (index < updated.size) {
                                updated[index] = enabled
                            }
                            onDraftChange(draft.copy(customSectionEnabled = updated))
                        },
                        actionLabel = "Remove",
                        onAction = { onDraftChange(draft.removeKeywordSection(index)) },
                    )
                    OutlinedTextField(
                        modifier = Modifier.fillMaxWidth(),
                        value = value,
                        onValueChange = { newValue ->
                            val updated = draft.customSectionPrompts.toMutableList()
                            updated[index] = newValue
                            onDraftChange(draft.copy(customSectionPrompts = updated))
                        },
                        label = { Text("Keywords") },
                    )
                }
            }
            if (draft.customSectionPrompts.size < 5) {
                OutlinedButton(
                    onClick = { onDraftChange(draft.addKeywordSection()) },
                ) {
                    Text("Add keyword section")
                }
            }
        }

        SettingsCard(
            title = "Notifications",
            subtitle = "Choose where Daily Briefing alerts should go",
        ) {
            listOf("email", "web", "ios", "android").forEach { option ->
                ToggleRow(
                    title = option.replaceFirstChar { it.uppercase() },
                    checked = draft.notificationTypes.contains(option),
                    onCheckedChange = { checked ->
                        onDraftChange(
                            draft.copy(
                                notificationTypes =
                                    draft.notificationTypes.toMutableSet().also { updated ->
                                        if (checked) {
                                            updated.add(option)
                                        } else {
                                            updated.remove(option)
                                        }
                                    },
                            ),
                        )
                    },
                )
            }
        }

        if (draft.briefingModels.size > 1) {
            SettingsCard(
                title = "Model",
                subtitle = "Pick which model writes your Daily Briefing",
            ) {
                ChoiceDropdown(
                    title = "Model",
                    selectedLabel =
                        draft.briefingModels.firstOrNull { it.key == draft.briefingModel }?.displayName
                            ?: draft.briefingModels.firstOrNull()?.displayName
                            ?: draft.briefingModel,
                    options = draft.briefingModels.map { model -> BriefingChoiceOption(model, model.displayName) },
                    onSelected = { model -> onDraftChange(draft.copy(briefingModel = model.key)) },
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (showsSaveButton) {
                OutlinedButton(
                    modifier = Modifier.weight(1f),
                    enabled = !isSaving && !isGenerating,
                    onClick = { onSavePreferences(draft, false) },
                ) {
                    Text("Save")
                }
            }
            Button(
                modifier = Modifier.weight(1f),
                enabled = !isSaving && !isGenerating,
                onClick = { onSavePreferences(draft, true) },
            ) {
                Text(if (showsSaveButton) "Generate Now" else "Generate Daily Briefing")
            }
        }

        if (isSaving || isGenerating) {
            DailyBriefingMessageCard(
                title = "Working…",
                message = progressMessage ?: "Saving Daily Briefing settings…",
                isError = false,
            )
        }
    }
}

@Composable
private fun DailyBriefingGroupCard(
    group: DailyBriefingGroupUi,
    sectionPalette: DailyBriefingSectionPalette,
    storyTableConfig: DailyBriefingStoryTableConfig,
    collapsed: Boolean,
    onToggleGroup: (String) -> Unit,
    onStoryClick: (String) -> Unit,
    onPremiumClick: () -> Unit,
) {
    val palette = rememberDailyBriefingPalette()
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .background(sectionPalette.background),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .clickable { onToggleGroup(group.briefingId) }
                    .padding(start = 12.dp, top = 10.dp, end = 8.dp, bottom = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = if (collapsed) "▸" else "▾",
                style = MaterialTheme.typography.titleMedium,
                color = sectionPalette.title,
            )
            Spacer(Modifier.size(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = group.title,
                    style = MaterialTheme.typography.titleMedium,
                    color = sectionPalette.title,
                )
                if (group.dateText.isNotBlank()) {
                    Text(
                        text = group.dateText,
                        style = MaterialTheme.typography.bodySmall,
                        color = sectionPalette.date,
                    )
                }
            }
            Text(
                text = "${group.curatedCount} ${if (group.curatedCount == 1) "story" else "stories"}",
                style = MaterialTheme.typography.labelLarge,
                color = sectionPalette.date,
            )
        }
        HorizontalDivider(color = sectionPalette.border)

        if (!collapsed) {
            NativeDailyBriefingStoryList(
                stories = group.stories,
                storyTableConfig = storyTableConfig,
                onStoryClick = onStoryClick,
            )

            if (group.isPreview) {
                DailyBriefingUpgradeBanner(onPremiumClick = onPremiumClick)
            }
        }
    }
}

@Composable
private fun DailyBriefingUpgradeBanner(onPremiumClick: () -> Unit) {
    val palette = rememberDailyBriefingPalette()
    val archivePurple = Color(0xFF8B5CF6)
    val archivePurpleLight = Color(0xFF6366F1)

    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .background(palette.card)
                .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Card(
            colors =
                CardDefaults.cardColors(
                    containerColor = archivePurple.copy(alpha = 0.08f),
                ),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.clickable(onClick = onPremiumClick),
            border = androidx.compose.foundation.BorderStroke(1.dp, archivePurple.copy(alpha = 0.2f)),
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                androidx.compose.foundation.Image(
                    painter = painterResource(id = R.drawable.ic_star_active),
                    contentDescription = null,
                    modifier = Modifier.size(24.dp),
                    colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(archivePurple),
                )
                Spacer(Modifier.height(10.dp))
                Row(
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Premium Archive",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        modifier =
                            Modifier
                                .clip(RoundedCornerShape(4.dp))
                                .background(
                                    brush =
                                        androidx.compose.ui.graphics.Brush.linearGradient(
                                            colors = listOf(archivePurpleLight, archivePurple),
                                        ),
                                )
                                .padding(horizontal = 8.dp, vertical = 3.dp),
                    )
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    text = "Get daily briefings with all your top stories",
                    style = MaterialTheme.typography.bodyMedium,
                    color = palette.body,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(12.dp))
                Button(
                    onClick = onPremiumClick,
                    shape = RoundedCornerShape(10.dp),
                    colors =
                        androidx.compose.material3.ButtonDefaults.buttonColors(
                            containerColor = archivePurple,
                            contentColor = Color.White,
                        ),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        text = "Upgrade to Premium Archive",
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
    }
}

@Composable
private fun NativeDailyBriefingStoryList(
    stories: List<Story>,
    storyTableConfig: DailyBriefingStoryTableConfig,
    onStoryClick: (String) -> Unit,
) {
    AndroidView(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 0.dp),
        factory = { context ->
            ExpandedHeightRecyclerView(context).apply {
                layoutParams =
                    ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                    )
                layoutManager = LinearLayoutManager(context)
                itemAnimator = null
                overScrollMode = View.OVER_SCROLL_NEVER
                isNestedScrollingEnabled = false
                adapter =
                    StoryViewAdapter(
                        storyTableConfig.activity,
                        FeedSet.dailyBriefing(),
                        StoryListStyle.LIST,
                        storyTableConfig.iconLoader,
                        storyTableConfig.thumbnailLoader,
                        storyTableConfig.feedUtils,
                        storyTableConfig.prefsRepo,
                        object : StoryViewAdapter.OnStoryClickListener {
                            override fun onStoryClicked(
                                feedSet: FeedSet?,
                                storyHash: String?,
                            ) {
                                storyHash?.let(onStoryClick)
                            }
                        },
                    )
            }
        },
        update = { recyclerView ->
            (recyclerView.adapter as? StoryViewAdapter)?.submitStories(
                stories = stories,
                loadId = SystemClock.elapsedRealtime(),
                rv = recyclerView,
                oldScrollState = null,
                skipBackFillingStories = false,
            )
        },
    )
}

@Composable
private fun SettingsCard(
    title: String,
    subtitle: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    val palette = rememberDailyBriefingPalette()
    Card(
        colors = CardDefaults.cardColors(containerColor = palette.card),
        shape = RoundedCornerShape(20.dp),
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            content = {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    color = palette.title,
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = palette.body,
                )
                content()
            },
        )
    }
}

@Composable
private fun ToggleRow(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    val palette = rememberDailyBriefingPalette()
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyLarge,
            color = palette.title,
        )
        if (actionLabel != null && onAction != null) {
            Text(
                text = actionLabel,
                modifier =
                    Modifier
                        .padding(end = 12.dp)
                        .clickable(onClick = onAction),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.error,
            )
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun SectionToggle(
    definition: DailyBriefingSectionDefinition,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    val palette = rememberDailyBriefingPalette()
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        ToggleRow(
            title = definition.name,
            checked = checked,
            onCheckedChange = onCheckedChange,
        )
        Text(
            text = definition.subtitle,
            style = MaterialTheme.typography.bodySmall,
            color = palette.body,
        )
    }
}

@Composable
private fun <T> ChoiceChipGroup(
    label: String,
    selectedValue: T,
    options: List<BriefingChoiceOption<T>>,
    onSelected: (T) -> Unit,
) {
    val palette = rememberDailyBriefingPalette()
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            color = palette.muted,
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            options.forEach { option ->
                FilterChip(
                    selected = option.value == selectedValue,
                    onClick = { onSelected(option.value) },
                    label = { Text(option.title) },
                )
            }
        }
    }
}

@Composable
private fun <T> ChoiceDropdown(
    title: String,
    selectedLabel: String,
    options: List<BriefingChoiceOption<T>>,
    onSelected: (T) -> Unit,
) {
    val palette = rememberDailyBriefingPalette()
    var expanded by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelLarge,
            color = palette.muted,
        )
        Box {
            OutlinedButton(
                modifier = Modifier.fillMaxWidth(),
                onClick = { expanded = true },
            ) {
                Text(
                    text = selectedLabel,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Start,
                )
                Text("▼")
            }
            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
            ) {
                options.forEach { option ->
                    DropdownMenuItem(
                        text = { Text(option.title) },
                        onClick = {
                            expanded = false
                            onSelected(option.value)
                        },
                    )
                }
            }
        }
    }
}
