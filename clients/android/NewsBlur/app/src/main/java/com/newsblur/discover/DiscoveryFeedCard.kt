package com.newsblur.discover

import android.text.format.DateUtils
import android.widget.ImageView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.newsblur.R
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.network.FolderPath
import com.newsblur.util.AppConstants
import com.newsblur.util.ImageLoader
import com.newsblur.util.UIUtils

// DiscoveryFeedCard.kt is shared by Add + Discover Sites and both Related Sites presentations.
@Composable
internal fun DiscoveryFeedCard(
    feed: DiscoveryFeed,
    added: Boolean,
    enabled: Boolean,
    grid: Boolean,
    colors: ReaderSheetPalette.Colors,
    loader: ImageLoader,
    thumbnailLoader: ImageLoader,
    onAdd: () -> Unit,
    onPreview: () -> Unit,
    state: DiscoveryState,
    onChooseFolder: (String) -> Unit,
    onOpenStory: (DiscoveryStory) -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(
                RoundedCornerShape(12.dp),
            ).background(colors.cardBackground)
            .border(1.dp, colors.border, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            AndroidView(modifier = Modifier.size(36.dp).clip(RoundedCornerShape(6.dp)), factory = {
                ImageView(it).apply {
                    scaleType =
                        ImageView.ScaleType.FIT_CENTER
                }
            }, update = { view ->
                val url =
                    feed.image.ifBlank {
                        if (feed.id.isNotBlank()) {
                            "${com.newsblur.network.APIConstants.buildUrl(
                                com.newsblur.network.APIConstants.PATH_FEED_FAVICON_URL,
                            )}${feed.id}"
                        } else {
                            ""
                        }
                    }
                if (view.tag !=
                    url
                ) {
                    view.tag = url
                    view.setImageResource(R.drawable.ic_world)
                    if (url.isNotBlank()) loader.displayImage(url, view)
                }
            })
            Column(Modifier.weight(1f)) {
                Text(feed.title, color = colors.textPrimary, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(
                    feed.link,
                    color = colors.siteLink,
                    style = MaterialTheme.typography.bodySmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        if (feed.subscribers >
            0
        ) {
            Text(
                "${java.text.NumberFormat.getIntegerInstance().format(feed.subscribers)} subscribers",
                color = colors.textSecondary,
                style = MaterialTheme.typography.bodySmall,
            )
        }
        if (!grid) {
            feed.stories.take(3).forEach { story ->
                HorizontalDivider(color = colors.border)
                DiscoveryStoryRow(
                    story, colors, thumbnailLoader, enabled,
                    story.hash.isNotBlank() && state.selectedPreviewStoryHash == story.hash,
                ) { onOpenStory(story) }
            }
        }
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onPreview, enabled = enabled) { Text(if (added) "Open" else "Try", color = colors.siteLink) }
            Spacer(Modifier.width(16.dp))
            if (added) {
                Spacer(Modifier.weight(1f))
            } else {
                DiscoveryFolderPicker(state, colors, onChooseFolder, Modifier.weight(1f))
            }
            Spacer(Modifier.width(8.dp))
            Button(
                onClick = onAdd,
                enabled = enabled && !added,
                colors = ButtonDefaults.buttonColors(containerColor = colors.siteButton, contentColor = Color.White),
            ) {
                Text(if (added) "Added" else "Add")
            }
        }
    }
}

@Composable
private fun DiscoveryStoryRow(
    story: DiscoveryStory,
    colors: ReaderSheetPalette.Colors,
    thumbnailLoader: ImageLoader,
    enabled: Boolean,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val title = remember(story.title) { UIUtils.fromHtml(story.title).toString().trim() }
    val authors = remember(story.authors) { UIUtils.fromHtml(story.authors).toString().trim() }
    val excerpt = remember(story.excerpt) { UIUtils.fromHtml(story.excerpt).toString().trim() }
    val date = story.timestamp?.let {
        DateUtils.getRelativeTimeSpanString(it * 1000, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS).toString()
    }
    val secondaryText = colors.textPrimary.copy(alpha = 0.85f)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 44.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(colors.accent.copy(alpha = if (pressed) 0.24f else if (isSelected) 0.14f else 0f))
            .border(1.dp, colors.accent.copy(alpha = if (pressed || isSelected) 0.5f else 0f), RoundedCornerShape(8.dp))
            .clickable(
                enabled = enabled && story.hash.isNotBlank(),
                role = Role.Button,
                interactionSource = interaction,
                indication = null,
                onClick = onClick,
            )
            .semantics { selected = isSelected }
            .padding(horizontal = 8.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                title,
                color = colors.textPrimary,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            if (authors.isNotBlank() || date != null) {
                Text(
                    listOfNotNull(authors.takeIf(String::isNotBlank), date).joinToString(" · "),
                    color = secondaryText,
                    style = MaterialTheme.typography.labelSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (excerpt.isNotBlank()) {
                Text(
                    excerpt,
                    color = secondaryText,
                    style = MaterialTheme.typography.bodySmall,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        if (story.imageUrl.isNotBlank()) {
            AndroidView(
                modifier = Modifier.size(76.dp).clip(RoundedCornerShape(8.dp)),
                factory = { context ->
                    ImageView(context).apply {
                        scaleType = ImageView.ScaleType.CENTER_CROP
                        importantForAccessibility = android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO
                    }
                },
                update = { view ->
                    if (view.tag != story.imageUrl) {
                        view.tag = story.imageUrl
                        view.setImageDrawable(null)
                        thumbnailLoader.displayImage(story.imageUrl, view, UIUtils.dp2px(view.context, 76), false)
                    }
                },
            )
        }
    }
}

@Composable
internal fun DiscoveryFolderPicker(
    state: DiscoveryState,
    colors: ReaderSheetPalette.Colors,
    onChoose: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }
    val displayName = if (state.folder == AppConstants.ROOT_FOLDER) "Top Level" else FolderPath.leaf(state.folder)
    Box(modifier) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 44.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(colors.inputBackground)
                .border(1.dp, colors.border, RoundedCornerShape(8.dp))
                .clickable(enabled = !state.busy, role = Role.Button) { expanded = true }
                .semantics {
                    contentDescription = "Add to folder"
                    stateDescription = displayName
                }
                .padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(displayName, Modifier.weight(1f), color = colors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Icon(Icons.Rounded.ExpandMore, null, Modifier.size(18.dp), colors.textSecondary)
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.heightIn(max = 360.dp).widthIn(min = 180.dp, max = 340.dp),
            containerColor = colors.cardBackground,
        ) {
            val folders = listOf(AppConstants.ROOT_FOLDER to "Top Level") + state.folders
                .filter { it.flatName() != AppConstants.ROOT_FOLDER }
                .map { it.flatName() to "${"    ".repeat(it.depth())}${it.name}" }
            folders.forEach { (path, title) ->
                DropdownMenuItem(
                    text = { Text(title, color = colors.textPrimary) },
                    modifier = Modifier.semantics { selected = state.folder == path },
                    onClick = {
                        onChoose(path)
                        expanded = false
                    },
                )
            }
        }
    }
}
