package com.newsblur.listen

import android.graphics.Bitmap
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Forward30
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.Replay
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.newsblur.R
import com.newsblur.design.ListenPalette
import java.util.Locale
import kotlin.math.ceil

/**
 * ListenNowPlayingSheet.kt is the expanded player: scrubber, skips, speed, voice settings, the preview
 * banner and upgrade button for people without Premium Archive, inline errors with Retry, Up Next and usage.
 */
@Composable
fun ListenNowPlayingSheet(
    state: ListenUiState,
    icon: Bitmap?,
    colors: ListenPalette.Colors,
    onPlayPause: () -> Unit,
    onSeek: (Long) -> Unit,
    onSkipBack: () -> Unit,
    onSkipForward: () -> Unit,
    onNext: () -> Unit,
    onSpeed: (Double) -> Unit,
    onVoiceSettings: () -> Unit,
    onRetry: () -> Unit,
    onUpgrade: () -> Unit,
    onPlayQueued: (String) -> Unit,
    onRemoveQueued: (String) -> Unit,
    onMoveQueued: (Int, Int) -> Unit,
) {
    val story = state.story ?: return
    var speedOpen by rememberSaveable { mutableStateOf(false) }
    val maxHeight = LocalConfiguration.current.screenHeightDp.dp * 0.9f
    Surface(
        modifier = Modifier.fillMaxWidth().heightIn(max = maxHeight),
        color = colors.sheetBackground,
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp),
        ) {
            Box(
                modifier =
                    Modifier
                        .padding(top = 10.dp, bottom = 14.dp)
                        .width(42.dp)
                        .height(4.dp)
                        .align(Alignment.CenterHorizontally)
                        .clip(CircleShape)
                        .background(colors.border),
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                ListenFeedIcon(icon = icon, colors = colors, size = 48)
                Spacer(Modifier.width(14.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = story.title,
                        color = colors.textPrimary,
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 3,
                        overflow = TextOverflow.Ellipsis,
                    )
                    story.feedTitle?.takeIf { it.isNotBlank() }?.let {
                        Text(
                            text = it,
                            color = colors.textSecondary,
                            fontSize = 13.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }

            Spacer(Modifier.height(14.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                ListenChip(
                    text =
                        state.voice?.name?.let { stringResource(R.string.listen_voice_label, it) }
                            ?: stringResource(R.string.listen_voice_settings),
                    icon = {
                        Icon(
                            Icons.Rounded.GraphicEq,
                            null,
                            tint = colors.textPrimary,
                            modifier = Modifier.size(16.dp),
                        )
                    },
                    colors = colors,
                    onClick = onVoiceSettings,
                    modifier = Modifier.weight(1f, fill = false),
                )
                ListenSpeedChip(
                    speed = state.speed,
                    open = speedOpen,
                    colors = colors,
                    onClick = { speedOpen = !speedOpen },
                )
            }
            AnimatedVisibility(visible = speedOpen) {
                Surface(
                    shape = RoundedCornerShape(14.dp),
                    color = colors.cardBackground,
                    modifier =
                        Modifier
                            .padding(top = 10.dp)
                            .fillMaxWidth()
                            .border(1.dp, colors.border.copy(alpha = 0.6f), RoundedCornerShape(14.dp)),
                ) {
                    ListenSpeedControl(
                        speed = state.speed,
                        colors = colors,
                        onSpeed = onSpeed,
                        modifier = Modifier.padding(14.dp),
                    )
                }
            }

            when {
                state.phase == ListenPhase.ERROR ->
                    ListenErrorCard(
                        state = state,
                        colors = colors,
                        onRetry = onRetry,
                        onUpgrade = onUpgrade,
                    )
                state.phase == ListenPhase.PREVIEW_ENDED ->
                    ListenPreviewEndedCard(state = state, colors = colors, onUpgrade = onUpgrade)
                state.isPreview -> ListenPreviewBanner(state = state, colors = colors)
            }

            Spacer(Modifier.height(10.dp))
            ListenScrubber(state = state, colors = colors, onSeek = onSeek)

            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    ListenIconButton(
                        icon = Icons.Rounded.Replay,
                        description = stringResource(R.string.listen_skip_back),
                        tint = colors.textPrimary,
                        onClick = onSkipBack,
                        size = 52,
                        iconSize = 34,
                    )
                    Text(
                        text = "15",
                        color = colors.textPrimary,
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 3.dp),
                    )
                }
                ListenPlayPauseButton(
                    state = state,
                    colors = colors,
                    size = 68,
                    onClick = onPlayPause,
                )
                ListenIconButton(
                    icon = Icons.Rounded.Forward30,
                    description = stringResource(R.string.listen_skip_forward),
                    tint = colors.textPrimary,
                    onClick = onSkipForward,
                    size = 52,
                    iconSize = 34,
                )
                ListenIconButton(
                    icon = Icons.Rounded.SkipNext,
                    description = stringResource(R.string.listen_next_story),
                    tint = colors.textPrimary,
                    onClick = onNext,
                    size = 52,
                    iconSize = 32,
                    enabled = state.nextStory != null,
                )
            }

            ListenUsageFooter(usage = state.usage, colors = colors, onUpgrade = onUpgrade)

            Spacer(Modifier.height(12.dp))
            ListenUpNextSection(
                state = state,
                colors = colors,
                onPlay = onPlayQueued,
                onRemove = onRemoveQueued,
                onMove = onMoveQueued,
            )
            Spacer(Modifier.height(20.dp))
        }
    }
}

@Composable
private fun ListenScrubber(
    state: ListenUiState,
    colors: ListenPalette.Colors,
    onSeek: (Long) -> Unit,
) {
    var dragging by remember { mutableStateOf<Float?>(null) }
    val duration = state.durationMs.coerceAtLeast(1L).toFloat()
    val value = dragging ?: state.positionMs.toFloat().coerceIn(0f, duration)
    Slider(
        value = value,
        onValueChange = { dragging = it },
        onValueChangeFinished = {
            dragging?.let { onSeek(it.toLong()) }
            dragging = null
        },
        valueRange = 0f..duration,
        enabled = state.durationMs > 0L,
        colors =
            SliderDefaults.colors(
                thumbColor = colors.accent,
                activeTrackColor = colors.accent,
                inactiveTrackColor = colors.progressTrack,
            ),
    )
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = formatListenTime(value.toLong()),
            color = colors.textSecondary,
            fontSize = 12.sp,
            style = TabularNumbers,
        )
        Spacer(Modifier.weight(1f))
        Text(
            text = "-" + formatListenTime((state.durationMs - value.toLong()).coerceAtLeast(0L)),
            color = colors.textSecondary,
            fontSize = 12.sp,
            style = TabularNumbers,
        )
    }
}

/** ListenNowPlayingSheet.kt's speed button shows the exact rate and opens ListenSpeedControl.kt below it. */
@Composable
private fun ListenSpeedChip(
    speed: Double,
    open: Boolean,
    colors: ListenPalette.Colors,
    onClick: () -> Unit,
) {
    val rate = ListenSpeed.format(speed)
    ListenChip(
        text = stringResource(R.string.listen_speed_value, rate),
        icon = {
            Icon(
                Icons.Rounded.Speed,
                null,
                tint = if (open) colors.onChipSelected else colors.textPrimary,
                modifier = Modifier.size(16.dp),
            )
        },
        colors = colors,
        selected = open,
        onClick = onClick,
        contentDescription = stringResource(R.string.listen_speed_button, rate),
    )
}

@Composable
fun ListenChip(
    text: String,
    colors: ListenPalette.Colors,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: (@Composable () -> Unit)? = null,
    selected: Boolean = false,
    contentDescription: String? = null,
) {
    Row(
        modifier =
            modifier
                .clip(RoundedCornerShape(50))
                .background(if (selected) colors.chipSelected else colors.chipBackground)
                .clickable(role = Role.Button, onClickLabel = contentDescription, onClick = onClick)
                .padding(horizontal = 12.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        icon?.let {
            it()
            Spacer(Modifier.width(6.dp))
        }
        Text(
            text = text,
            color = if (selected) colors.onChipSelected else colors.textPrimary,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun ListenPreviewBanner(
    state: ListenUiState,
    colors: ListenPalette.Colors,
) {
    val secondsLeft =
        ceil(
            (state.previewLimitMs - state.positionMs).coerceAtLeast(0L) / 1000.0,
        ).toInt()
    Spacer(Modifier.height(12.dp))
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(colors.previewBackground)
                .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = stringResource(R.string.listen_preview_banner),
            color = colors.previewText,
            fontSize = 13.sp,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(10.dp))
        Text(
            text =
                pluralStringResource(
                    R.plurals.listen_preview_seconds_left,
                    secondsLeft,
                    secondsLeft,
                ),
            color = colors.previewText,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            style = TabularNumbers,
        )
    }
}

@Composable
private fun ListenPreviewEndedCard(
    state: ListenUiState,
    colors: ListenPalette.Colors,
    onUpgrade: () -> Unit,
) {
    Spacer(Modifier.height(12.dp))
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(colors.previewBackground)
                .padding(14.dp),
    ) {
        Text(
            text =
                state.usage?.upgradeMessage?.takeIf { it.isNotBlank() }
                    ?: stringResource(R.string.listen_preview_banner),
            color = colors.previewText,
            fontSize = 14.sp,
        )
        Spacer(Modifier.height(10.dp))
        ListenUpgradeButton(
            text = stringResource(R.string.listen_upgrade_archive),
            colors = colors,
            onClick = onUpgrade,
        )
    }
}

@Composable
private fun ListenErrorCard(
    state: ListenUiState,
    colors: ListenPalette.Colors,
    onRetry: () -> Unit,
    onUpgrade: () -> Unit,
) {
    val error = state.error
    val upgradeText = upgradeButtonText(state)
    Spacer(Modifier.height(12.dp))
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(colors.cardBackground)
                .padding(14.dp),
    ) {
        Text(text = listenErrorMessage(error), color = colors.error, fontSize = 14.sp)
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            if (error?.isUpgradeReason != true) {
                ListenChip(
                    text = stringResource(R.string.listen_retry),
                    colors = colors,
                    onClick = onRetry,
                    selected = true,
                )
            }
            if (upgradeText != null) {
                ListenUpgradeButton(text = upgradeText, colors = colors, onClick = onUpgrade)
            }
        }
    }
}

/** Archive listeners at their cap are offered Pro; Pro listeners at their cap just see the message. */
@Composable
private fun upgradeButtonText(state: ListenUiState): String? {
    val error = state.error ?: return null
    if (!error.isUpgradeReason) return null
    val usage = error.usage ?: state.usage
    return when {
        usage?.tier == TIER_PRO -> null
        usage?.isArchiveTier == true || usage?.tier == TIER_ARCHIVE ->
            stringResource(
                R.string.listen_upgrade_pro,
            )
        else -> stringResource(R.string.listen_upgrade_archive)
    }
}

@Composable
private fun ListenUpgradeButton(
    text: String,
    colors: ListenPalette.Colors,
    onClick: () -> Unit,
) {
    Box(
        modifier =
            Modifier
                .clip(RoundedCornerShape(50))
                .background(colors.upgradeBackground)
                .clickable(role = Role.Button, onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 9.dp),
    ) {
        Text(text = text, color = colors.onUpgrade, fontSize = 14.sp, fontWeight = FontWeight.Bold)
    }
}

fun formatListenTime(ms: Long): String {
    val totalSeconds = (ms / 1000L).coerceAtLeast(0L)
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return if (hours > 0) {
        String.format(Locale.ROOT, "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        String.format(Locale.ROOT, "%d:%02d", minutes, seconds)
    }
}

/** "1.05×": the precise rate, up to two decimals. */
@Composable
fun formatListenSpeed(speed: Double): String = stringResource(R.string.listen_speed_value, ListenSpeed.format(speed))

private const val TIER_PRO = "pro"
private const val TIER_ARCHIVE = "archive"

/** ListenNowPlayingSheet.kt keeps counting times from jittering as their digits change. */
private val TabularNumbers = TextStyle(fontFeatureSettings = "tnum")
