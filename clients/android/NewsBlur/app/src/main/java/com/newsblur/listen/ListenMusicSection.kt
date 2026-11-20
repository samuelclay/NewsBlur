package com.newsblur.listen

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.newsblur.R
import com.newsblur.design.ListenPalette
import java.text.NumberFormat
import java.util.Locale

/**
 * ListenMusicSection.kt is the Music section in Listen's Now Playing sheet (ListenNowPlayingSheet.kt), the same as
 * iOS's ListenMusicCard.swift: Play over other audio, which keeps music from Spotify or another app playing under
 * the voice, lowering it while the voice speaks, and the Music / Voice balance (ListenAudioMix.kt). The header
 * collapses the section, and it stays collapsed.
 */
@Composable
fun ListenMusicSection(
    settings: ListenAudioMixSettings,
    colors: ListenPalette.Colors,
    onCollapsed: (Boolean) -> Unit,
    onPlayOverOtherAudio: (Boolean) -> Unit,
    onLowerMusic: (Boolean) -> Unit,
    onVoiceVolume: (Double) -> Unit,
) {
    val collapsed = settings.isMusicSectionCollapsed
    val expandedLabel = stringResource(R.string.listen_music_expanded)
    val collapsedLabel = stringResource(R.string.listen_music_collapsed)
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(role = Role.Button) { onCollapsed(!collapsed) }
                    .semantics { stateDescription = if (collapsed) collapsedLabel else expandedLabel }
                    .padding(vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.listen_music).uppercase(Locale.getDefault()),
                color = colors.textSecondary,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.8.sp,
                modifier = Modifier.weight(1f),
            )
            Icon(
                imageVector = if (collapsed) Icons.Rounded.ExpandMore else Icons.Rounded.ExpandLess,
                contentDescription = null,
                tint = colors.textSecondary,
            )
        }
        AnimatedVisibility(visible = !collapsed) {
            Column(
                modifier =
                    Modifier
                        .padding(top = 4.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(colors.cardBackground)
                        .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                SwitchRow(
                    title = stringResource(R.string.listen_play_over_other_audio),
                    summary = stringResource(R.string.listen_play_over_other_audio_summary),
                    checked = settings.playsOverOtherAudio,
                    colors = colors,
                    onCheckedChange = onPlayOverOtherAudio,
                )
                AnimatedVisibility(visible = settings.playsOverOtherAudio) {
                    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        SwitchRow(
                            title = stringResource(R.string.listen_lower_music),
                            summary = null,
                            checked = settings.lowersMusicWhileSpeaking,
                            colors = colors,
                            onCheckedChange = onLowerMusic,
                        )
                        BalanceSlider(voiceVolume = settings.voiceVolume, colors = colors, onVoiceVolume = onVoiceVolume)
                    }
                }
            }
        }
    }
}

@Composable
private fun SwitchRow(
    title: String,
    summary: String?,
    checked: Boolean,
    colors: ListenPalette.Colors,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(role = Role.Switch) { onCheckedChange(!checked) },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(text = title, color = colors.textPrimary, fontSize = 15.sp)
            summary?.let {
                Text(text = it, color = colors.textSecondary, fontSize = 12.sp, lineHeight = 16.sp)
            }
        }
        Spacer(Modifier.width(12.dp))
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors =
                SwitchDefaults.colors(
                    checkedThumbColor = colors.onAccent,
                    checkedTrackColor = colors.accent,
                    checkedBorderColor = colors.accent,
                    uncheckedThumbColor = colors.textSecondary,
                    uncheckedTrackColor = colors.progressTrack,
                    uncheckedBorderColor = colors.border,
                ),
        )
    }
}

/**
 * Music on the left, Voice on the right. The middle is the voice at 100% and is marked under the track; near it
 * the balance snaps there with a tick. Toward Voice boosts the voice (ListenVoiceBoost.kt), toward Music lowers it.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BalanceSlider(
    voiceVolume: Double,
    colors: ListenPalette.Colors,
    onVoiceVolume: (Double) -> Unit,
) {
    val haptics = LocalHapticFeedback.current
    var balance by remember { mutableDoubleStateOf(ListenAudioMixMath.balanceForVoiceVolume(voiceVolume)) }
    val sliderColors =
        SliderDefaults.colors(
            thumbColor = colors.accent,
            activeTrackColor = colors.accent,
            inactiveTrackColor = colors.progressTrack,
            activeTickColor = Color.Transparent,
            inactiveTickColor = Color.Transparent,
        )
    val tickColor = colors.textSecondary
    val label = stringResource(R.string.listen_balance_description)
    val percent =
        NumberFormat
            .getPercentInstance()
            .format(ListenAudioMixMath.voiceVolumeForBalance(ListenAudioMixMath.snapped(balance)))
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = stringResource(R.string.listen_balance_music),
            color = colors.textSecondary,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
        )
        Slider(
            value = balance.toFloat(),
            onValueChange = { position ->
                val wasCentered = ListenAudioMixMath.snapped(balance) == 0.0
                balance = position.toDouble()
                val snapped = ListenAudioMixMath.snapped(balance)
                if (snapped == 0.0 && !wasCentered) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                onVoiceVolume(ListenAudioMixMath.voiceVolumeForBalance(snapped))
            },
            valueRange = -1f..1f,
            colors = sliderColors,
            track = { sliderState ->
                SliderDefaults.Track(
                    sliderState = sliderState,
                    colors = sliderColors,
                    drawStopIndicator = null,
                    drawTick = { _, _ -> },
                    // ListenMusicSection.kt marks the middle, the voice at 100%, just under the track.
                    modifier =
                        Modifier.drawWithContent {
                            drawContent()
                            val x = size.width / 2
                            drawLine(
                                color = tickColor,
                                start = Offset(x, size.height + 4.dp.toPx()),
                                end = Offset(x, size.height + 10.dp.toPx()),
                                strokeWidth = 2.dp.toPx(),
                                cap = StrokeCap.Round,
                            )
                        },
                )
            },
            modifier =
                Modifier
                    .weight(1f)
                    .padding(horizontal = 10.dp)
                    .semantics {
                        contentDescription = label
                        stateDescription = percent
                    },
        )
        Text(
            text = stringResource(R.string.listen_balance_voice),
            color = colors.textSecondary,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}
