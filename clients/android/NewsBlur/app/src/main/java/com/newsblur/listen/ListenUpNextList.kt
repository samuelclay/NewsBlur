package com.newsblur.listen

import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.DragHandle
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.newsblur.R
import com.newsblur.design.ListenPalette
import kotlinx.coroutines.launch
import java.util.Locale
import kotlin.math.roundToInt

/**
 * ListenUpNextList.kt is Now Playing's Up Next: your queue first (drag the handle to reorder, swipe away to remove,
 * tap to play now), then a dimmer list of the unread stories auto-continue would play from the same feed or folder.
 */
@Composable
fun ListenUpNextSection(
    state: ListenUiState,
    colors: ListenPalette.Colors,
    onPlay: (String) -> Unit,
    onRemove: (String) -> Unit,
    onMove: (Int, Int) -> Unit,
) {
    Text(
        text = stringResource(R.string.listen_up_next).uppercase(Locale.getDefault()),
        color = colors.textSecondary,
        fontSize = 12.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = 0.8.sp,
    )
    Spacer(Modifier.height(6.dp))
    if (state.queued.isNotEmpty()) {
        QueueList(items = state.queued, colors = colors, onPlay = onPlay, onRemove = onRemove, onMove = onMove)
    } else {
        Text(
            text = stringResource(R.string.listen_up_next_empty_queue),
            color = colors.textSecondary,
            fontSize = 13.sp,
            modifier = Modifier.padding(vertical = 4.dp),
        )
    }

    Spacer(Modifier.height(14.dp))
    Text(
        text =
            state.upNextSource?.let { stringResource(R.string.listen_then_from, it) }
                ?: stringResource(R.string.listen_then_unread),
        color = colors.textSecondary,
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
    Spacer(Modifier.height(6.dp))
    Surface(shape = RoundedCornerShape(14.dp), color = colors.cardBackground.copy(alpha = THEN_CARD_ALPHA)) {
        Column(modifier = Modifier.fillMaxWidth()) {
            if (state.upNext.isEmpty()) {
                Text(
                    text = stringResource(R.string.listen_up_next_empty),
                    color = colors.textSecondary,
                    fontSize = 14.sp,
                    modifier = Modifier.padding(14.dp),
                )
            }
            state.upNext.forEachIndexed { index, item ->
                if (index > 0) HorizontalDivider(color = colors.border.copy(alpha = 0.5f))
                Column(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .clickable(role = Role.Button) { onPlay(item.storyHash) }
                            .padding(horizontal = 14.dp, vertical = 10.dp),
                ) {
                    StoryLines(item = item, colors = colors, dimmed = true)
                }
            }
        }
    }
}

@Composable
private fun QueueList(
    items: List<ListenStory>,
    colors: ListenPalette.Colors,
    onPlay: (String) -> Unit,
    onRemove: (String) -> Unit,
    onMove: (Int, Int) -> Unit,
) {
    // While a row is dragged, the list shows the order it would drop into; the queue changes only on release.
    var order by remember { mutableStateOf(items) }
    var dragging by remember { mutableStateOf<String?>(null) }
    var dragOffset by remember { mutableFloatStateOf(0f) }
    val heights = remember { mutableStateMapOf<String, Int>() }
    val currentItems by rememberUpdatedState(items)
    val currentOnMove by rememberUpdatedState(onMove)
    val shown = if (dragging == null) items else order
    val moveUp = stringResource(R.string.listen_up_next_move_up)
    val moveDown = stringResource(R.string.listen_up_next_move_down)
    val remove = stringResource(R.string.listen_remove_from_up_next)

    fun startDrag(storyHash: String) {
        order = currentItems
        dragging = storyHash
        dragOffset = 0f
    }

    fun drag(amount: Float) {
        val hash = dragging ?: return
        dragOffset += amount
        val index = order.indexOfFirst { it.storyHash == hash }
        if (index < 0) return
        // Passing half of a neighbor's height swaps with it, and the offset carries over so the row stays under the finger.
        if (dragOffset > 0 && index < order.lastIndex) {
            val next = heights[order[index + 1].storyHash] ?: return
            if (dragOffset > next / 2f) {
                order = order.toMutableList().apply { add(index + 1, removeAt(index)) }
                dragOffset -= next
            }
        } else if (dragOffset < 0 && index > 0) {
            val previous = heights[order[index - 1].storyHash] ?: return
            if (-dragOffset > previous / 2f) {
                order = order.toMutableList().apply { add(index - 1, removeAt(index)) }
                dragOffset += previous
            }
        }
    }

    fun endDrag() {
        val hash = dragging ?: return
        val from = currentItems.indexOfFirst { it.storyHash == hash }
        val to = order.indexOfFirst { it.storyHash == hash }
        dragging = null
        dragOffset = 0f
        if (from >= 0 && to >= 0 && from != to) currentOnMove(from, to)
    }

    Surface(shape = RoundedCornerShape(14.dp), color = colors.cardBackground) {
        Column(modifier = Modifier.fillMaxWidth()) {
            shown.forEachIndexed { index, item ->
                key(item.storyHash) {
                    val isDragging = dragging == item.storyHash
                    Column(
                        modifier =
                            Modifier
                                .zIndex(if (isDragging) 1f else 0f)
                                .graphicsLayer { translationY = if (isDragging) dragOffset else 0f }
                                .onSizeChanged { heights[item.storyHash] = it.height }
                                .semantics {
                                    customActions =
                                        buildList {
                                            if (index > 0) {
                                                add(
                                                    CustomAccessibilityAction(moveUp) {
                                                        onMove(index, index - 1)
                                                        true
                                                    },
                                                )
                                            }
                                            if (index < shown.lastIndex) {
                                                add(
                                                    CustomAccessibilityAction(moveDown) {
                                                        onMove(index, index + 1)
                                                        true
                                                    },
                                                )
                                            }
                                            add(
                                                CustomAccessibilityAction(remove) {
                                                    onRemove(item.storyHash)
                                                    true
                                                },
                                            )
                                        }
                                },
                    ) {
                        if (index > 0) HorizontalDivider(color = colors.border.copy(alpha = 0.6f))
                        QueueRow(
                            item = item,
                            colors = colors,
                            lifted = isDragging,
                            onPlay = { onPlay(item.storyHash) },
                            onRemove = { onRemove(item.storyHash) },
                            onDragStart = { startDrag(item.storyHash) },
                            onDrag = ::drag,
                            onDragEnd = ::endDrag,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun QueueRow(
    item: ListenStory,
    colors: ListenPalette.Colors,
    lifted: Boolean,
    onPlay: () -> Unit,
    onRemove: () -> Unit,
    onDragStart: () -> Unit,
    onDrag: (Float) -> Unit,
    onDragEnd: () -> Unit,
) {
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    // Swiping a row left past a third of its width, or flinging it, takes it out of Up Next.
    val swipe = remember { Animatable(0f) }
    var rowWidth by remember { mutableIntStateOf(0) }
    val currentOnRemove by rememberUpdatedState(onRemove)
    Box(modifier = Modifier.fillMaxWidth().onSizeChanged { rowWidth = it.width }.clipToBounds()) {
        Box(
            modifier = Modifier.matchParentSize().background(colors.error.copy(alpha = 0.85f)).padding(horizontal = 18.dp),
            contentAlignment = Alignment.CenterEnd,
        ) {
            Icon(Icons.Rounded.Delete, contentDescription = null, tint = colors.onAccent)
        }
        Row(
            modifier =
                Modifier
                    .offset { IntOffset(swipe.value.roundToInt(), 0) }
                    .fillMaxWidth()
                    .background(if (lifted) colors.chipBackground else colors.cardBackground)
                    .pointerInput(item.storyHash) {
                        val velocity = VelocityTracker()
                        detectHorizontalDragGestures(
                            onDragStart = { velocity.resetTracking() },
                            onDragEnd = {
                                val width = rowWidth.toFloat()
                                val flung = velocity.calculateVelocity().x < -SWIPE_FLING_VELOCITY
                                scope.launch {
                                    if (width > 0f && (swipe.value < -width * SWIPE_REMOVE_FRACTION || flung)) {
                                        swipe.animateTo(-width)
                                        currentOnRemove()
                                    } else {
                                        swipe.animateTo(0f)
                                    }
                                }
                            },
                            onDragCancel = { scope.launch { swipe.animateTo(0f) } },
                            onHorizontalDrag = { change, amount ->
                                change.consume()
                                velocity.addPosition(change.uptimeMillis, change.position)
                                scope.launch { swipe.snapTo((swipe.value + amount).coerceIn(-rowWidth.toFloat(), 0f)) }
                            },
                        )
                    }.clickable(role = Role.Button, onClick = onPlay)
                    .padding(start = 14.dp, top = 10.dp, bottom = 10.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                StoryLines(item = item, colors = colors, dimmed = false)
            }
            Box(
                modifier =
                    Modifier
                        .size(40.dp)
                        .clip(RoundedCornerShape(8.dp))
                        // The sheet itself drags vertically, so a touch on the handle keeps the gesture for the row.
                        .pointerInput(Unit) {
                            awaitEachGesture {
                                awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
                                view.parent?.requestDisallowInterceptTouchEvent(true)
                            }
                        }.pointerInput(item.storyHash) {
                            detectVerticalDragGestures(
                                onDragStart = { onDragStart() },
                                onDragEnd = onDragEnd,
                                onDragCancel = onDragEnd,
                                onVerticalDrag = { change, amount ->
                                    change.consume()
                                    onDrag(amount)
                                },
                            )
                        },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Rounded.DragHandle,
                    contentDescription = stringResource(R.string.listen_up_next_drag),
                    tint = colors.textSecondary,
                )
            }
        }
    }
}

@Composable
private fun StoryLines(
    item: ListenStory,
    colors: ListenPalette.Colors,
    dimmed: Boolean,
) {
    val alpha = if (dimmed) DIMMED_TEXT_ALPHA else 1f
    Text(
        item.title,
        color = colors.textPrimary.copy(alpha = alpha),
        fontSize = 14.sp,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
    )
    item.feedTitle?.takeIf { it.isNotBlank() }?.let {
        Text(
            it,
            color = colors.textSecondary.copy(alpha = alpha),
            fontSize = 12.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

private const val DIMMED_TEXT_ALPHA = 0.7f
private const val SWIPE_REMOVE_FRACTION = 0.33f
private const val SWIPE_FLING_VELOCITY = 1_500f
private const val THEN_CARD_ALPHA = 0.6f
