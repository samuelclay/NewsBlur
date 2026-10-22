package com.newsblur.listen

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.newsblur.R
import com.newsblur.design.ListenPalette

/**
 * ListenSpeedControl.kt is the speed control shared by Now Playing and voice settings: an exact value field, a
 * slider over ListenSpeed.STOPS with a tick at 1x, and preset buttons. All three follow the same rate, which
 * ListenManager.kt applies to the audio right away.
 */
@Composable
fun ListenSpeedControl(
    speed: Double,
    colors: ListenPalette.Colors,
    onSpeed: (Double) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SpeedField(speed = speed, colors = colors, onSpeed = onSpeed)
            Spacer(Modifier.width(12.dp))
            SpeedSlider(speed = speed, colors = colors, onSpeed = onSpeed, modifier = Modifier.weight(1f))
        }
        Spacer(Modifier.height(8.dp))
        ListenSpeed.PRESETS.chunked(PRESETS_PER_ROW).forEachIndexed { rowIndex, row ->
            if (rowIndex > 0) Spacer(Modifier.height(6.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                row.forEach { preset ->
                    PresetButton(
                        preset = preset,
                        selected = ListenSpeed.isSelected(preset, speed),
                        colors = colors,
                        onClick = { onSpeed(preset) },
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun SpeedField(
    speed: Double,
    colors: ListenPalette.Colors,
    onSpeed: (Double) -> Unit,
) {
    var text by remember { mutableStateOf(ListenSpeed.format(speed)) }
    var focused by remember { mutableStateOf(false) }
    val currentSpeed by rememberUpdatedState(speed)
    val focusManager = LocalFocusManager.current
    // The slider and presets rewrite the field, unless it already shows this rate the way it was typed.
    LaunchedEffect(speed) {
        val shown = ListenSpeed.parse(text)
        if (!focused || shown == null || ListenSpeed.clamp(shown) != ListenSpeed.clamp(speed)) {
            text = ListenSpeed.format(speed)
        }
    }
    val commit = {
        val typed = ListenSpeed.parse(text)
        if (typed == null) {
            text = ListenSpeed.format(currentSpeed)
        } else {
            // Out of range input clamps to 0.5x or 3x once the field is done.
            val value = ListenSpeed.clamp(typed)
            if (value != ListenSpeed.clamp(currentSpeed)) onSpeed(value)
            text = ListenSpeed.format(value)
        }
    }
    val label = stringResource(R.string.listen_speed_exact)
    val shape = RoundedCornerShape(10.dp)
    Row(
        modifier =
            Modifier
                .width(FIELD_WIDTH_DP.dp)
                .clip(shape)
                .background(colors.inputBackground)
                .border(1.dp, if (focused) colors.accent else colors.border, shape)
                .padding(horizontal = 10.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicTextField(
            value = text,
            onValueChange = { typed ->
                text = ListenSpeed.sanitizeInput(typed)
                // Each keystroke plays right away while it reads as a rate in range.
                ListenSpeed.parse(text)?.takeIf { it in ListenSpeed.MIN..ListenSpeed.MAX }?.let { value ->
                    val rounded = ListenSpeed.clamp(value)
                    if (rounded != ListenSpeed.clamp(currentSpeed)) onSpeed(rounded)
                }
            },
            singleLine = true,
            textStyle =
                TextStyle(
                    color = colors.textPrimary,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFeatureSettings = "tnum",
                    textAlign = TextAlign.End,
                ),
            cursorBrush = SolidColor(colors.accent),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal, imeAction = ImeAction.Done),
            keyboardActions =
                KeyboardActions(onDone = {
                    commit()
                    focusManager.clearFocus()
                }),
            modifier =
                Modifier
                    .weight(1f)
                    .semantics { contentDescription = label }
                    .onFocusChanged { state ->
                        if (focused && !state.isFocused) commit()
                        focused = state.isFocused
                    },
        )
        Text(
            text = stringResource(R.string.listen_speed_unit),
            color = colors.textSecondary,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SpeedSlider(
    speed: Double,
    colors: ListenPalette.Colors,
    onSpeed: (Double) -> Unit,
    modifier: Modifier = Modifier,
) {
    // A typed rate between stops leaves the thumb on the nearest stop but keeps the typed rate.
    val index = ListenSpeed.nearestStopIndex(speed)
    val sliderColors =
        SliderDefaults.colors(
            thumbColor = colors.textPrimary,
            activeTrackColor = colors.textSecondary,
            inactiveTrackColor = colors.progressTrack,
            activeTickColor = Color.Transparent,
            inactiveTickColor = Color.Transparent,
        )
    val tickColor = colors.textSecondary
    val label = stringResource(R.string.listen_speed_slider)
    val state = stringResource(R.string.listen_speed_value, ListenSpeed.format(speed))
    Slider(
        value = index.toFloat(),
        onValueChange = { position ->
            val stop = ListenSpeed.stopAt(position)
            if (stop != ListenSpeed.clamp(speed)) onSpeed(stop)
        },
        valueRange = 0f..ListenSpeed.LAST_INDEX.toFloat(),
        steps = ListenSpeed.LAST_INDEX - 1,
        colors = sliderColors,
        track = { sliderState ->
            SliderDefaults.Track(
                sliderState = sliderState,
                colors = sliderColors,
                drawStopIndicator = null,
                drawTick = { _, _ -> },
                // ListenSpeedControl.kt marks 1x just under the track, at the same spot as its stop.
                modifier =
                    Modifier.drawWithContent {
                        drawContent()
                        val x = size.width * ListenSpeed.normalTickFraction
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
            modifier.semantics {
                contentDescription = label
                stateDescription = state
            },
    )
}

@Composable
private fun PresetButton(
    preset: Double,
    selected: Boolean,
    colors: ListenPalette.Colors,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(8.dp)
    Text(
        text = stringResource(R.string.listen_speed_value, ListenSpeed.format(preset)),
        color = if (selected) colors.onChipSelected else colors.textPrimary,
        fontSize = 13.sp,
        fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
        textAlign = TextAlign.Center,
        maxLines = 1,
        softWrap = false,
        style = TextStyle(fontFeatureSettings = "tnum"),
        modifier =
            modifier
                .clip(shape)
                .background(if (selected) colors.chipSelected else colors.chipBackground)
                .selectable(selected = selected, role = Role.RadioButton, onClick = onClick)
                .padding(vertical = 8.dp),
    )
}

private const val PRESETS_PER_ROW = 5
private const val FIELD_WIDTH_DP = 84
