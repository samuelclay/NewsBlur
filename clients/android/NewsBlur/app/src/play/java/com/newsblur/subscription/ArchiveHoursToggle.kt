package com.newsblur.subscription

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.newsblur.R

/** ArchiveHoursToggle.kt's colors, all chosen per theme in SubscriptionActivity.kt's palette. */
data class ArchiveHoursToggleColors(
    val track: Color,
    val border: Color,
    val text: Color,
    val selectedText: Color,
    val thumbStart: Color,
    val thumbEnd: Color,
)

/**
 * The "1 hour | 10 hours" switch on the Premium Archive card's Listen line. Both segments take the width of the
 * wider one, and the selected one is a pill in the card's own gradient that slides across when it changes. Each
 * segment can carry a caption, its yearly price or "Current plan", since the buy button is far down the card.
 */
@Composable
fun ArchiveHoursToggle(
    selected: ArchiveListenHours,
    captions: Map<ArchiveListenHours, String>,
    colors: ArchiveHoursToggleColors,
    onSelect: (ArchiveListenHours) -> Unit,
    modifier: Modifier = Modifier,
) {
    val thumbPosition by animateFloatAsState(
        targetValue = ArchiveListenHours.entries.indexOf(selected).toFloat(),
        animationSpec = spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMediumLow),
        label = "archiveHoursThumb",
    )
    val isRtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    val pill = RoundedCornerShape(percent = 50)
    Row(
        modifier =
            modifier
                .width(IntrinsicSize.Max)
                .clip(pill)
                .background(colors.track)
                .border(1.dp, colors.border, pill)
                .padding(3.dp)
                .drawBehind {
                    val segmentWidth = size.width / ArchiveListenHours.entries.size
                    val fromStart = segmentWidth * thumbPosition
                    val left = if (isRtl) size.width - segmentWidth - fromStart else fromStart
                    drawRoundRect(
                        brush = Brush.horizontalGradient(listOf(colors.thumbStart, colors.thumbEnd), startX = left, endX = left + segmentWidth),
                        topLeft = Offset(left, 0f),
                        size = Size(segmentWidth, size.height),
                        cornerRadius = CornerRadius(size.height / 2),
                    )
                }.selectableGroup(),
    ) {
        ArchiveListenHours.entries.forEach { hours ->
            val isSelected = hours == selected
            val textColor by animateColorAsState(
                targetValue = if (isSelected) colors.selectedText else colors.text,
                label = "archiveHoursText",
            )
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier =
                    Modifier
                        .weight(1f)
                        .clip(pill)
                        .selectable(
                            selected = isSelected,
                            interactionSource = null,
                            indication = ripple(color = colors.thumbStart),
                            role = Role.RadioButton,
                            onClick = { onSelect(hours) },
                        ).padding(horizontal = 16.dp, vertical = if (captions.isEmpty()) 9.dp else 6.dp),
            ) {
                Text(
                    text = pluralStringResource(R.plurals.listen_hours, hours.hours, hours.hours),
                    color = textColor,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                )
                // An empty caption still takes its line, so both segments keep the same height.
                if (captions.isNotEmpty()) {
                    Text(
                        text = captions[hours].orEmpty(),
                        color = textColor.copy(alpha = textColor.alpha * 0.85f),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}
