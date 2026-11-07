package com.newsblur.listen

import android.graphics.Bitmap
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Headphones
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Replay
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.newsblur.R
import com.newsblur.design.ListenPalette

/**
 * ListenMiniPlayer.kt is the bar that floats above the bottom toolbar on every main screen while a story is
 * loaded: the story, its feed, play or pause, the next story, how far along it is, and a close button. A podcast
 * episode swaps the next story for skip back and forward, as a podcast player has them. Tapping it opens Now
 * Playing (ListenNowPlayingFragment.kt).
 */
@Composable
fun ListenMiniPlayer(
    state: ListenUiState,
    icon: Bitmap?,
    colors: ListenPalette.Colors,
    onOpen: () -> Unit,
    onPlayPause: () -> Unit,
    onSkipBack: () -> Unit,
    onSkipForward: () -> Unit,
    onNext: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val story = state.story ?: return
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = colors.barBackground,
        border = BorderStroke(1.dp, colors.barBorder),
        shadowElevation = 8.dp,
    ) {
        Column {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .clickable(
                            onClickLabel = stringResource(R.string.listen_open_player),
                            onClick = onOpen,
                        ).padding(start = 10.dp, end = 4.dp, top = 8.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                ListenFeedIcon(icon = icon, colors = colors, size = 32)
                Spacer(Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = story.title,
                        color = colors.textPrimary,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = miniPlayerSubtitle(state),
                        color =
                            if (state.phase == ListenPhase.ERROR) {
                                colors.error
                            } else {
                                colors.textSecondary
                            },
                        fontSize = 12.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                if (state.isMedia) {
                    ListenSkipButton(
                        seconds = state.skipBackSeconds,
                        forward = false,
                        tint = colors.textPrimary,
                        onClick = onSkipBack,
                        size = 38,
                        iconSize = 28,
                    )
                    ListenPlayPauseButton(
                        state = state,
                        colors = colors,
                        size = 38,
                        onClick = onPlayPause,
                    )
                    ListenSkipButton(
                        seconds = state.skipForwardSeconds,
                        forward = true,
                        tint = colors.textPrimary,
                        onClick = onSkipForward,
                        size = 38,
                        iconSize = 28,
                    )
                } else {
                    ListenPlayPauseButton(
                        state = state,
                        colors = colors,
                        size = 38,
                        onClick = onPlayPause,
                    )
                    // The same next as Now Playing's: Up Next first, then auto-continue; greyed at the end of a list.
                    ListenIconButton(
                        icon = Icons.Rounded.SkipNext,
                        description = stringResource(R.string.listen_next_story),
                        tint = colors.textPrimary,
                        onClick = onNext,
                        enabled = state.nextStory != null,
                    )
                }
                ListenIconButton(
                    icon = Icons.Rounded.Close,
                    description = stringResource(R.string.listen_close),
                    tint = colors.textSecondary,
                    onClick = onClose,
                )
            }
            ListenProgressLine(state = state, colors = colors)
        }
    }
}

@Composable
private fun miniPlayerSubtitle(state: ListenUiState): String =
    when {
        state.phase == ListenPhase.ERROR -> listenErrorMessage(state.error, isMedia = state.isMedia)
        state.phase == ListenPhase.LOADING ->
            stringResource(if (state.isMedia) R.string.listen_media_loading else R.string.listen_loading)
        state.phase == ListenPhase.PREVIEW_ENDED -> stringResource(R.string.listen_preview_finished)
        state.isPreview -> stringResource(R.string.listen_preview_pill)
        else -> {
            val feed = state.story?.feedTitle.orEmpty()
            val voice = state.voice?.name.orEmpty()
            when {
                feed.isNotBlank() && voice.isNotBlank() ->
                    stringResource(
                        R.string.listen_feed_and_voice,
                        feed,
                        voice,
                    )
                feed.isNotBlank() -> feed
                else -> voice
            }
        }
    }

@Composable
private fun ListenProgressLine(
    state: ListenUiState,
    colors: ListenPalette.Colors,
) {
    val fraction =
        if (state.durationMs >
            0L
        ) {
            (state.positionMs.toFloat() / state.durationMs).coerceIn(0f, 1f)
        } else {
            0f
        }
    Box(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp)
                .padding(bottom = 6.dp)
                .height(3.dp)
                .clip(CircleShape)
                .background(colors.progressTrack),
    ) {
        Box(
            modifier =
                Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(fraction)
                    .background(colors.accent),
        )
    }
}

@Composable
fun ListenFeedIcon(
    icon: Bitmap?,
    colors: ListenPalette.Colors,
    size: Int,
) {
    Box(
        modifier =
            Modifier
                .size(size.dp)
                .clip(RoundedCornerShape((size / 4).dp))
                .background(colors.chipBackground),
        contentAlignment = Alignment.Center,
    ) {
        if (icon != null) {
            Image(
                bitmap = icon.asImageBitmap(),
                contentDescription = null,
                filterQuality = if (icon.width >= 64) FilterQuality.Medium else FilterQuality.None,
                modifier = Modifier.size((size * 0.72f).dp),
            )
        } else {
            Icon(
                imageVector = Icons.Rounded.Headphones,
                contentDescription = null,
                tint = colors.textSecondary,
                modifier = Modifier.size((size * 0.6f).dp),
            )
        }
    }
}

@Composable
fun ListenPlayPauseButton(
    state: ListenUiState,
    colors: ListenPalette.Colors,
    size: Int,
    onClick: () -> Unit,
) {
    val (icon, description) =
        when {
            state.phase == ListenPhase.ERROR ->
                Icons.Rounded.Refresh to
                    stringResource(R.string.listen_retry)
            state.showsPause -> Icons.Rounded.Pause to stringResource(R.string.listen_pause)
            else -> Icons.Rounded.PlayArrow to stringResource(R.string.listen_play)
        }
    Box(
        modifier =
            Modifier
                .size(size.dp)
                .clip(CircleShape)
                .background(colors.accent)
                .clickable(role = Role.Button, onClickLabel = description, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (state.isLoading && state.playWhenReady) {
            CircularProgressIndicator(
                color = colors.onAccent,
                strokeWidth = 2.dp,
                modifier = Modifier.size((size * 0.55f).dp),
            )
        } else {
            Icon(
                imageVector = icon,
                contentDescription = description,
                tint = colors.onAccent,
                modifier = Modifier.size((size * 0.6f).dp),
            )
        }
    }
}

@Composable
fun ListenIconButton(
    icon: ImageVector,
    description: String,
    tint: androidx.compose.ui.graphics.Color,
    onClick: () -> Unit,
    size: Int = 40,
    iconSize: Int = 22,
    enabled: Boolean = true,
) {
    Box(
        modifier =
            Modifier
                .size(size.dp)
                .clip(CircleShape)
                .clickable(
                    enabled = enabled,
                    role = Role.Button,
                    onClickLabel = description,
                    onClick = onClick,
                ),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = description,
            tint = if (enabled) tint else tint.copy(alpha = 0.35f),
            modifier = Modifier.size(iconSize.dp),
        )
    }
}

/**
 * A skip button showing its interval inside a circular arrow, like the web player's: the web media player's
 * skip_back_seconds or skip_forward_seconds. Forward mirrors the arrow.
 */
@Composable
fun ListenSkipButton(
    seconds: Int,
    forward: Boolean,
    tint: Color,
    onClick: () -> Unit,
    size: Int,
    iconSize: Int,
) {
    val description =
        pluralStringResource(
            if (forward) R.plurals.listen_skip_forward_seconds else R.plurals.listen_skip_back_seconds,
            seconds,
            seconds,
        )
    Box(
        modifier =
            Modifier
                .size(size.dp)
                .clip(CircleShape)
                .clickable(role = Role.Button, onClickLabel = description, onClick = onClick)
                .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = Icons.Rounded.Replay,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(iconSize.dp).graphicsLayer { if (forward) scaleX = -1f },
        )
        // The number sits in the arrow's circle, a little below the middle where the arrowhead leaves room.
        Text(
            text = seconds.toString(),
            color = tint,
            fontSize = (iconSize * SKIP_NUMBER_SCALE).sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = (iconSize * SKIP_NUMBER_OFFSET).dp),
        )
    }
}

private const val SKIP_NUMBER_SCALE = 0.27f
private const val SKIP_NUMBER_OFFSET = 0.09f

/** The server's localized message when there is one, else this client's message for the failure. */
@Composable
fun listenErrorMessage(
    error: ListenError?,
    isMedia: Boolean = false,
): String {
    error?.message?.takeIf { it.isNotBlank() }?.let { return it }
    // A podcast episode's file comes straight from its host, so its only failure is that it didn't play.
    if (isMedia) return stringResource(R.string.listen_media_error)
    return when (error?.reason) {
        ListenError.REASON_NETWORK -> stringResource(R.string.listen_error_network)
        ListenError.REASON_PLAYBACK -> stringResource(R.string.listen_error_playback)
        ListenError.REASON_BUSY -> stringResource(R.string.listen_error_busy)
        ListenError.REASON_RATE_LIMITED -> stringResource(R.string.listen_error_rate_limited)
        else -> stringResource(R.string.listen_error_generic)
    }
}
