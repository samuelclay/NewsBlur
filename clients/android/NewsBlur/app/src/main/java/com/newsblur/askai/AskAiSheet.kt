package com.newsblur.askai

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.FactCheck
import androidx.compose.material.icons.automirrored.rounded.FormatListBulleted
import androidx.compose.material.icons.automirrored.rounded.ShortText
import androidx.compose.material.icons.rounded.AccountTree
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.StopCircle
import androidx.compose.material.icons.rounded.UnfoldMore
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.newsblur.R
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.PrefConstants.ThemeValue

@Composable
fun AskAiSheet(
    state: AskAiUiState,
    theme: ThemeValue,
    onQuestionSelected: (AskAiQuestionType) -> Unit,
    onCustomQuestionChanged: (String) -> Unit,
    onAskCustomQuestion: () -> Unit,
    onSendFollowUp: () -> Unit,
    onReask: () -> Unit,
    onModelSelected: (AskAiProvider) -> Unit,
    onUpgrade: () -> Unit,
    onVoiceClick: () -> Unit,
) {
    val palette = remember(theme) { askAiPalette(theme) }
    val maxHeight = LocalConfiguration.current.screenHeightDp.dp * 0.88f

    Surface(
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(max = maxHeight),
        shape = RoundedCornerShape(0.dp),
        color = palette.background,
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .imePadding(),
        ) {
            Box(
                modifier =
                    Modifier
                        .padding(top = 10.dp, bottom = 8.dp)
                        .width(42.dp)
                        .height(4.dp)
                        .align(Alignment.CenterHorizontally)
                        .clip(CircleShape)
                        .background(palette.border),
            )

            if (state.hasAskedQuestion) {
                AskAiResponseContent(
                    state = state,
                    palette = palette,
                    onCustomQuestionChanged = onCustomQuestionChanged,
                    onSendFollowUp = onSendFollowUp,
                    onReask = onReask,
                    onModelSelected = onModelSelected,
                    onUpgrade = onUpgrade,
                    onVoiceClick = onVoiceClick,
                )
            } else {
                AskAiQuestionContent(
                    state = state,
                    palette = palette,
                    onQuestionSelected = onQuestionSelected,
                    onCustomQuestionChanged = onCustomQuestionChanged,
                    onAskCustomQuestion = onAskCustomQuestion,
                    onModelSelected = onModelSelected,
                    onVoiceClick = onVoiceClick,
                )
            }
        }
    }
}

@Composable
private fun AskAiQuestionContent(
    state: AskAiUiState,
    palette: AskAiPalette,
    onQuestionSelected: (AskAiQuestionType) -> Unit,
    onCustomQuestionChanged: (String) -> Unit,
    onAskCustomQuestion: () -> Unit,
    onModelSelected: (AskAiProvider) -> Unit,
    onVoiceClick: () -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState()),
    ) {
        AskAiCard(palette = palette) {
            AskAiSectionHeader(
                title = "Summarize",
                icon = Icons.AutoMirrored.Rounded.ShortText,
                palette = palette,
            )
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .height(IntrinsicSize.Min)
                        .padding(start = 12.dp, end = 12.dp, bottom = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                listOf(
                    AskAiQuestionType.SENTENCE,
                    AskAiQuestionType.BULLETS,
                    AskAiQuestionType.PARAGRAPH,
                ).forEach { type ->
                    AskAiPromptButton(
                        modifier =
                            Modifier
                                .weight(1f)
                                .fillMaxHeight(),
                        type = type,
                        palette = palette,
                        onClick = { onQuestionSelected(type) },
                    )
                }
            }
        }

        Spacer(Modifier.height(12.dp))

        AskAiCard(palette = palette) {
            AskAiSectionHeader(
                title = "Understand",
                icon = Icons.Rounded.Lightbulb,
                palette = palette,
            )
            listOf(
                AskAiQuestionType.CONTEXT,
                AskAiQuestionType.PEOPLE,
                AskAiQuestionType.ARGUMENTS,
                AskAiQuestionType.FACTCHECK,
            ).forEachIndexed { index, type ->
                AskAiListButton(
                    type = type,
                    palette = palette,
                    onClick = { onQuestionSelected(type) },
                )
                if (index < 3) {
                    HorizontalDivider(color = palette.border.copy(alpha = 0.65f))
                }
            }
        }

        Spacer(Modifier.height(12.dp))

        AskAiComposer(
            value = state.customQuestion,
            placeholder = stringResource(R.string.ask_ai_ask_question),
            selectedModel = state.selectedModel,
            palette = palette,
            isRecording = state.isRecording,
            isTranscribing = state.isTranscribing,
            onValueChange = onCustomQuestionChanged,
            onModelSelected = onModelSelected,
            onVoiceClick = onVoiceClick,
            onPrimaryAction = onAskCustomQuestion,
        )
    }
}

@Composable
private fun AskAiResponseContent(
    state: AskAiUiState,
    palette: AskAiPalette,
    onCustomQuestionChanged: (String) -> Unit,
    onSendFollowUp: () -> Unit,
    onReask: () -> Unit,
    onModelSelected: (AskAiProvider) -> Unit,
    onUpgrade: () -> Unit,
    onVoiceClick: () -> Unit,
) {
    val listState = rememberLazyListState()
    val lastIndex =
        state.completedBlocks.size +
            if (state.isStreaming || state.currentResponseText.isNotBlank()) 1 else 0 +
            if (state.errorMessage != null) 1 else 0 +
            if (state.usageMessage != null) 1 else 0

    LaunchedEffect(lastIndex, state.currentResponseText, state.isStreaming) {
        if (lastIndex > 0) {
            listState.animateScrollToItem(lastIndex - 1)
        }
    }

    Column(modifier = Modifier.fillMaxWidth()) {
        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f, fill = false),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            itemsIndexed(state.completedBlocks) { index, block ->
                AskAiCompletedBlock(
                    block = block,
                    previousModel = state.completedBlocks.getOrNull(index - 1)?.model,
                    storyTitle = state.story?.storyTitle.orEmpty(),
                    palette = palette,
                )
            }

            if (state.isStreaming || state.currentResponseText.isNotBlank()) {
                item {
                    AskAiStreamingBlock(state = state, palette = palette)
                }
            }

            state.errorMessage?.let { error ->
                item {
                    AskAiBanner(
                        message = error,
                        palette = palette,
                        isError = true,
                        showUpgrade = isUpgradeMessage(error) && !state.isArchiveTier,
                        onUpgrade = onUpgrade,
                    )
                }
            }

            state.usageMessage?.let { usage ->
                item {
                    AskAiBanner(
                        message = usage,
                        palette = palette,
                        isError = false,
                        showUpgrade = isUpgradeMessage(usage) && !state.isArchiveTier,
                        onUpgrade = onUpgrade,
                    )
                }
            }
        }

        if (state.isComplete || state.errorMessage != null || (!state.isStreaming && state.currentResponseText.isNotBlank())) {
            HorizontalDivider(color = palette.border)
            AskAiComposer(
                value = state.customQuestion,
                placeholder = stringResource(R.string.ask_ai_follow_up),
                selectedModel = state.selectedModel,
                palette = palette,
                isRecording = state.isRecording,
                isTranscribing = state.isTranscribing,
                showReaskWhenBlank = true,
                onValueChange = onCustomQuestionChanged,
                onModelSelected = onModelSelected,
                onVoiceClick = onVoiceClick,
                onPrimaryAction = onSendFollowUp,
                onReask = onReask,
            )
        }
    }
}

@Composable
private fun AskAiCompletedBlock(
    block: AskAiResponseBlock,
    previousModel: AskAiProvider?,
    storyTitle: String,
    palette: AskAiPalette,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (block.isFollowUp) {
            FollowUpQuestionHeader(text = block.questionText, palette = palette)
        } else {
            QuestionHeader(text = block.questionText, storyTitle = storyTitle, palette = palette)
        }

        if (previousModel == null || previousModel != block.model) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                ModelPill(model = block.model, palette = palette)
            }
        }

        AskAiMarkdownText(text = block.responseText, palette = palette)
    }
}

@Composable
private fun AskAiStreamingBlock(
    state: AskAiUiState,
    palette: AskAiPalette,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (state.completedBlocks.isEmpty()) {
            QuestionHeader(
                text = state.currentQuestionText,
                storyTitle = state.story?.storyTitle.orEmpty(),
                palette = palette,
            )
        } else {
            FollowUpQuestionHeader(text = state.currentQuestionText, palette = palette)
        }

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            ModelPill(model = state.selectedModel, palette = palette, isLoading = state.isStreaming)
        }

        if (state.currentResponseText.isNotBlank()) {
            AskAiMarkdownText(text = state.currentResponseText, palette = palette)
        }
    }
}

@Composable
private fun AskAiComposer(
    value: String,
    placeholder: String,
    selectedModel: AskAiProvider,
    palette: AskAiPalette,
    isRecording: Boolean,
    isTranscribing: Boolean,
    onValueChange: (String) -> Unit,
    onModelSelected: (AskAiProvider) -> Unit,
    onVoiceClick: () -> Unit,
    onPrimaryAction: () -> Unit,
    onReask: () -> Unit = {},
    showReaskWhenBlank: Boolean = false,
) {
    val actionLabel =
        when {
            showReaskWhenBlank && value.isBlank() -> stringResource(R.string.ask_ai_reask)
            showReaskWhenBlank -> stringResource(R.string.ask_ai_send)
            else -> stringResource(R.string.ask_ai_ask)
        }
    val actionEnabled = !isRecording && !isTranscribing && (showReaskWhenBlank || value.isNotBlank())

    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .background(palette.inputBackground)
                .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            AskAiVoiceButton(
                isRecording = isRecording,
                isEnabled = !isTranscribing,
                palette = palette,
                onClick = onVoiceClick,
            )

            AskAiTextField(
                modifier = Modifier.weight(1f),
                value = value,
                placeholder = placeholder,
                palette = palette,
                enabled = !isRecording && !isTranscribing,
                onValueChange = onValueChange,
                onSubmit = {
                    if (showReaskWhenBlank && value.isBlank()) {
                        onReask()
                    } else if (value.isNotBlank()) {
                        onPrimaryAction()
                    }
                },
            )

            ModelSelector(
                selectedModel = selectedModel,
                palette = palette,
                enabled = !isTranscribing,
                onSelected = onModelSelected,
            )

            AskAiActionButton(
                text = actionLabel,
                palette = palette,
                isEnabled = actionEnabled,
                emphasized = !showReaskWhenBlank || value.isNotBlank(),
                onClick = {
                    if (showReaskWhenBlank && value.isBlank()) {
                        onReask()
                    } else {
                        onPrimaryAction()
                    }
                },
            )
        }

        if (isRecording || isTranscribing) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.size(14.dp),
                    color = palette.accent,
                    strokeWidth = 2.dp,
                )
                Text(
                    text =
                        if (isRecording) {
                            stringResource(R.string.ask_ai_recording)
                        } else {
                            stringResource(R.string.ask_ai_transcribing)
                        },
                    color = palette.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }
}

@Composable
private fun AskAiPromptButton(
    modifier: Modifier = Modifier,
    type: AskAiQuestionType,
    palette: AskAiPalette,
    onClick: () -> Unit,
) {
    Surface(
        modifier = modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(8.dp),
        color = palette.cardBackground,
        border = androidx.compose.foundation.BorderStroke(1.dp, palette.border),
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .fillMaxHeight()
                    .padding(horizontal = 10.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Box(
                modifier = Modifier.height(20.dp),
                contentAlignment = Alignment.Center,
            ) {
                when (type) {
                    AskAiQuestionType.SENTENCE -> {
                        Box(
                            modifier =
                                Modifier
                                    .width(18.dp)
                                    .height(2.dp)
                                    .clip(CircleShape)
                                    .background(palette.textSecondary),
                        )
                    }

                    AskAiQuestionType.BULLETS -> {
                        Icon(
                            imageVector = Icons.AutoMirrored.Rounded.FormatListBulleted,
                            contentDescription = null,
                            tint = palette.textSecondary,
                            modifier = Modifier.size(18.dp),
                        )
                    }

                    else -> {
                        Icon(
                            imageVector = Icons.AutoMirrored.Rounded.ShortText,
                            contentDescription = null,
                            tint = palette.textSecondary,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
            }

            Text(
                text = type.displayTitle,
                color = palette.textPrimary,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = type.subtitle,
                color = palette.textSecondary,
                fontSize = 11.sp,
                textAlign = TextAlign.Center,
                lineHeight = 13.sp,
            )
        }
    }
}

@Composable
private fun AskAiListButton(
    type: AskAiQuestionType,
    palette: AskAiPalette,
    onClick: () -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = askAiListIcon(type),
            contentDescription = null,
            tint = palette.textSecondary,
            modifier = Modifier.size(18.dp),
        )
        Text(
            text = type.displayTitle,
            color = palette.textPrimary,
            style = MaterialTheme.typography.bodyLarge,
        )
    }
}

@Composable
private fun AskAiSectionHeader(
    title: String,
    icon: ImageVector,
    palette: AskAiPalette,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = palette.textSecondary,
            modifier = Modifier.size(18.dp),
        )
        Text(
            text = title,
            color = palette.textPrimary,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun AskAiCard(
    palette: AskAiPalette,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp),
        shape = RoundedCornerShape(18.dp),
        color = palette.cardBackground,
        border = androidx.compose.foundation.BorderStroke(1.dp, palette.border.copy(alpha = 0.75f)),
    ) {
        Column(content = content)
    }
}

@Composable
private fun AskAiVoiceButton(
    isRecording: Boolean,
    isEnabled: Boolean,
    palette: AskAiPalette,
    onClick: () -> Unit,
) {
    val tint = if (isRecording) Color(0xFFD14C4C) else palette.textSecondary
    val background = if (isRecording) Color(0x1AD14C4C) else palette.cardBackground

    Box(
        modifier =
            Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(background)
                .border(1.dp, palette.border, CircleShape)
                .clickable(enabled = isEnabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = if (isRecording) Icons.Rounded.StopCircle else Icons.Rounded.Mic,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(18.dp),
        )
    }
}

@Composable
private fun AskAiTextField(
    modifier: Modifier = Modifier,
    value: String,
    placeholder: String,
    palette: AskAiPalette,
    enabled: Boolean,
    onValueChange: (String) -> Unit,
    onSubmit: () -> Unit,
) {
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        enabled = enabled,
        singleLine = true,
        textStyle = TextStyle(color = palette.textPrimary, fontSize = 13.sp),
        cursorBrush = SolidColor(palette.accent),
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
        keyboardActions = KeyboardActions(onSend = { onSubmit() }),
        decorationBox = { innerTextField ->
            Box(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(6.dp))
                        .background(palette.cardBackground)
                        .border(1.dp, palette.border, RoundedCornerShape(6.dp))
                        .padding(horizontal = 12.dp, vertical = 9.dp),
            ) {
                if (value.isBlank()) {
                    Text(
                        text = placeholder,
                        color = palette.textSecondary,
                        fontSize = 13.sp,
                    )
                }
                innerTextField()
            }
        },
    )
}

@Composable
private fun ModelSelector(
    selectedModel: AskAiProvider,
    palette: AskAiPalette,
    enabled: Boolean,
    onSelected: (AskAiProvider) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }

    Box {
        Row(
            modifier =
                Modifier
                    .clip(CircleShape)
                    .background(Color(selectedModel.colorHex))
                    .clickable(enabled = enabled) { expanded = true }
                    .padding(horizontal = 10.dp, vertical = 7.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = selectedModel.shortName,
                color = Color.White,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
            )
            Icon(
                imageVector = Icons.Rounded.UnfoldMore,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(14.dp),
            )
        }

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            containerColor = palette.cardBackground,
        ) {
            AskAiProvider.entries.forEach { model ->
                DropdownMenuItem(
                    text = {
                        Text(
                            text = model.displayName,
                            color = palette.textPrimary,
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    },
                    onClick = {
                        expanded = false
                        onSelected(model)
                    },
                    trailingIcon = {
                        if (model == selectedModel) {
                            Icon(
                                imageVector = Icons.Rounded.AutoAwesome,
                                contentDescription = null,
                                tint = palette.accent,
                                modifier = Modifier.size(16.dp),
                            )
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun AskAiActionButton(
    text: String,
    palette: AskAiPalette,
    isEnabled: Boolean,
    emphasized: Boolean,
    onClick: () -> Unit,
) {
    val background =
        when {
            !isEnabled -> palette.textSecondary
            emphasized -> palette.accent
            else -> palette.cardBackground
        }
    val contentColor = if (emphasized && isEnabled) Color.White else palette.textPrimary
    val borderColor = if (emphasized && isEnabled) background else palette.border

    Surface(
        modifier = Modifier.clickable(enabled = isEnabled, onClick = onClick),
        shape = RoundedCornerShape(6.dp),
        color = background,
        border = androidx.compose.foundation.BorderStroke(1.dp, borderColor),
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 9.dp),
            color = contentColor,
            fontSize = 13.sp,
            fontWeight = if (emphasized) FontWeight.Medium else FontWeight.Normal,
        )
    }
}

@Composable
private fun QuestionHeader(
    text: String,
    storyTitle: String,
    palette: AskAiPalette,
) {
    Surface(
        shape = RoundedCornerShape(8.dp),
        color = palette.cardBackground,
        border = androidx.compose.foundation.BorderStroke(1.dp, palette.border),
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = text,
                color = palette.textPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
            )
            if (storyTitle.isNotBlank()) {
                Text(
                    text = storyTitle,
                    color = palette.textSecondary,
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Serif,
                    lineHeight = 15.sp,
                )
            }
        }
    }
}

@Composable
private fun FollowUpQuestionHeader(
    text: String,
    palette: AskAiPalette,
) {
    Surface(
        shape = RoundedCornerShape(8.dp),
        color = palette.cardBackground.copy(alpha = 0.75f),
        border = androidx.compose.foundation.BorderStroke(1.dp, palette.border.copy(alpha = 0.6f)),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 10.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Rounded.ArrowForward,
                contentDescription = null,
                tint = palette.textSecondary,
                modifier = Modifier.size(14.dp),
            )
            Text(
                text = text,
                color = palette.textPrimary,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                lineHeight = 17.sp,
            )
        }
    }
}

@Composable
private fun ModelPill(
    model: AskAiProvider,
    palette: AskAiPalette,
    isLoading: Boolean = false,
) {
    val transition = rememberInfiniteTransition(label = "ask_ai_model_pill")
    val alpha by transition.animateFloat(
        initialValue = if (isLoading) 1f else 1f,
        targetValue = if (isLoading) 0.55f else 1f,
        animationSpec =
            infiniteRepeatable(
                animation = tween(durationMillis = 800),
                repeatMode = RepeatMode.Reverse,
            ),
        label = "ask_ai_model_pill_alpha",
    )

    Surface(
        modifier = Modifier.alpha(if (isLoading) alpha else 1f),
        shape = CircleShape,
        color = Color(model.colorHex),
    ) {
        Text(
            text = model.shortName,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

@Composable
private fun AskAiBanner(
    message: String,
    palette: AskAiPalette,
    isError: Boolean,
    showUpgrade: Boolean,
    onUpgrade: () -> Unit,
) {
    val isUpgradeMessage = isUpgradeMessage(message)
    val bannerColor =
        when {
            isUpgradeMessage -> Color(0x1AF0A130)
            isError -> Color(0x1AE05555)
            else -> palette.accent.copy(alpha = 0.12f)
        }
    val icon =
        when {
            isUpgradeMessage -> Icons.Rounded.Warning
            isError -> Icons.Rounded.Warning
            else -> Icons.Rounded.Info
        }
    val iconColor =
        when {
            isUpgradeMessage -> Color(0xFFF0A130)
            isError -> Color(0xFFD44B4B)
            else -> palette.accent
        }

    Surface(
        shape = RoundedCornerShape(8.dp),
        color = bannerColor,
        border = androidx.compose.foundation.BorderStroke(1.dp, palette.border.copy(alpha = 0.45f)),
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(16.dp),
                )
                Text(
                    text = message,
                    color = if (isError && !isUpgradeMessage) Color(0xFFD44B4B) else palette.textPrimary,
                    fontSize = if (isError) 13.sp else 12.sp,
                    lineHeight = 18.sp,
                )
            }

            if (showUpgrade) {
                AskAiActionButton(
                    text = stringResource(R.string.ask_ai_upgrade_archive),
                    palette = palette,
                    isEnabled = true,
                    emphasized = true,
                    onClick = onUpgrade,
                )
            }
        }
    }
}

@Composable
private fun AskAiMarkdownText(
    text: String,
    palette: AskAiPalette,
) {
    val paragraphSpacing = 12.dp

    SelectionContainer {
        Column(verticalArrangement = Arrangement.spacedBy(paragraphSpacing)) {
            text
                .lines()
                .filter { it.isNotBlank() }
                .forEachIndexed { index, line ->
                    val numberedMatch = NUMBERED_LIST_REGEX.matchEntire(line)
                    when {
                        line.startsWith("# ") -> {
                            MarkdownParagraph(
                                text = line.removePrefix("# ").trim(),
                                palette = palette,
                                fontSize = 20.sp,
                                fontWeight = FontWeight.Bold,
                            )
                        }

                        line.startsWith("## ") -> {
                            MarkdownParagraph(
                                text = line.removePrefix("## ").trim(),
                                palette = palette,
                                fontSize = 18.sp,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }

                        line.startsWith("### ") -> {
                            MarkdownParagraph(
                                text = line.removePrefix("### ").trim(),
                                palette = palette,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }

                        line.startsWith("- ") || line.startsWith("* ") -> {
                            MarkdownBulletLine(
                                text = line.drop(2).trim(),
                                palette = palette,
                            )
                        }

                        numberedMatch != null -> {
                            MarkdownNumberedLine(
                                number = numberedMatch.groupValues[1],
                                text = numberedMatch.groupValues[2],
                                palette = palette,
                            )
                        }

                        line.startsWith("---") -> {
                            HorizontalDivider(color = palette.border.copy(alpha = 0.8f))
                        }

                        else -> {
                            MarkdownParagraph(
                                text = line.trim(),
                                palette = palette,
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Normal,
                            )
                        }
                    }
                }
        }
    }
}

@Composable
private fun MarkdownParagraph(
    text: String,
    palette: AskAiPalette,
    fontSize: androidx.compose.ui.unit.TextUnit,
    fontWeight: FontWeight,
) {
    Text(
        text = inlineMarkdown(text, palette, fontWeight, fontSize),
        color = palette.textBody,
        fontSize = fontSize,
        fontWeight = fontWeight,
        lineHeight = (fontSize.value + 4).sp,
    )
}

@Composable
private fun MarkdownBulletLine(
    text: String,
    palette: AskAiPalette,
) {
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = "•",
            color = palette.accent,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = inlineMarkdown(text, palette),
            color = palette.textBody,
            fontSize = 15.sp,
            lineHeight = 19.sp,
        )
    }
}

@Composable
private fun MarkdownNumberedLine(
    number: String,
    text: String,
    palette: AskAiPalette,
) {
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = "$number.",
            color = palette.accent,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
        )
        Text(
            text = inlineMarkdown(text, palette),
            color = palette.textBody,
            fontSize = 15.sp,
            lineHeight = 19.sp,
        )
    }
}

private fun inlineMarkdown(
    text: String,
    palette: AskAiPalette,
    defaultWeight: FontWeight = FontWeight.Normal,
    defaultSize: androidx.compose.ui.unit.TextUnit = 15.sp,
): AnnotatedString =
    buildAnnotatedString {
        var cursor = 0
        INLINE_MARKDOWN_REGEX.findAll(text).forEach { match ->
            if (match.range.first > cursor) {
                withStyle(SpanStyle(color = palette.textBody, fontWeight = defaultWeight, fontSize = defaultSize)) {
                    append(text.substring(cursor, match.range.first))
                }
            }

            val token = match.value
            val content =
                when {
                    token.startsWith("**") && token.endsWith("**") -> token.drop(2).dropLast(2)
                    token.startsWith("__") && token.endsWith("__") -> token.drop(2).dropLast(2)
                    token.startsWith("*") && token.endsWith("*") -> token.drop(1).dropLast(1)
                    token.startsWith("_") && token.endsWith("_") -> token.drop(1).dropLast(1)
                    else -> token
                }

            val style =
                when {
                    token.startsWith("**") || token.startsWith("__") ->
                        SpanStyle(
                            color = palette.textBody,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = defaultSize,
                        )

                    else ->
                        SpanStyle(
                            color = palette.textBody,
                            fontStyle = FontStyle.Italic,
                            fontWeight = defaultWeight,
                            fontSize = defaultSize,
                        )
                }

            withStyle(style) {
                append(content)
            }
            cursor = match.range.last + 1
        }

        if (cursor < text.length) {
            withStyle(SpanStyle(color = palette.textBody, fontWeight = defaultWeight, fontSize = defaultSize)) {
                append(text.substring(cursor))
            }
        }
    }

private fun askAiListIcon(type: AskAiQuestionType): ImageVector =
    when (type) {
        AskAiQuestionType.CONTEXT -> Icons.Rounded.Public
        AskAiQuestionType.PEOPLE -> Icons.Rounded.Groups
        AskAiQuestionType.ARGUMENTS -> Icons.Rounded.AccountTree
        AskAiQuestionType.FACTCHECK -> Icons.AutoMirrored.Rounded.FactCheck
        else -> Icons.Rounded.AutoAwesome
    }

private fun askAiPalette(theme: ThemeValue): AskAiPalette {
    val palette = ReaderSheetPalette.colors(theme)
    return AskAiPalette(
        background = palette.background,
        cardBackground = palette.cardBackground,
        border = palette.border,
        textPrimary = palette.textPrimary,
        textSecondary = palette.textSecondary,
        inputBackground = palette.inputBackground,
        accent = palette.accent,
    )
}

internal fun askAiSheetBackgroundColor(theme: ThemeValue): Color = askAiPalette(theme).background

private fun isUpgradeMessage(message: String): Boolean {
    val lowered = message.lowercase()
    return lowered.contains("limit") || lowered.contains("used all") || lowered.contains("reached")
}

private data class AskAiPalette(
    val background: Color,
    val cardBackground: Color,
    val border: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val inputBackground: Color,
    val accent: Color = Color(0xFF709E5D),
) {
    val textBody: Color
        get() = textPrimary
}

private val NUMBERED_LIST_REGEX = Regex("""^(\d+)\.\s+(.*)$""")
private val INLINE_MARKDOWN_REGEX = Regex("""(\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_)""")
