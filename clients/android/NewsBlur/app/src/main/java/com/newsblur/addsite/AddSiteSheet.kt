package com.newsblur.addsite

import android.widget.ImageView
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CreateNewFolder
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Folder
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Mail
import androidx.compose.material.icons.rounded.Newspaper
import androidx.compose.material.icons.rounded.Podcasts
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.SmartDisplay
import androidx.compose.material.icons.rounded.TrendingUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.rememberNestedScrollInteropConnection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.newsblur.R
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.discover.DiscoveryTab
import com.newsblur.domain.FeedResult
import com.newsblur.util.AppConstants
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefConstants.ThemeValue
import java.text.NumberFormat

@Composable
fun AddSiteSheet(
    state: AddSiteState,
    theme: ThemeValue,
    iconLoader: ImageLoader,
    onQueryChanged: (String) -> Unit,
    onFolderNameChanged: (String) -> Unit,
    onChooseFolder: (String) -> Unit,
    onToggleFolder: () -> Unit,
    onSubmit: (String) -> Unit,
    onDiscover: (DiscoveryTab) -> Unit,
) {
    val colors = ReaderSheetPalette.colors(theme)
    val configuration = LocalConfiguration.current
    val heightFraction = if (configuration.screenWidthDp > configuration.screenHeightDp) 0.85f else 0.55f
    val maxHeight = configuration.screenHeightDp.dp * heightFraction
    var choosingFolder by remember { mutableStateOf(false) }
    val enabled = !state.submitting
    val folderOnly = state.query.isBlank() && state.creatingFolder
    val canSubmit = enabled && (state.query.isNotBlank() || (folderOnly && state.newFolder.isNotBlank()))
    Column(
        Modifier
            .fillMaxWidth()
            .heightIn(max = maxHeight)
            .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
            .background(colors.siteFormBackground)
            .animateContentSize(),
    ) {
        Column(Modifier.fillMaxWidth().background(colors.cardBackground)) {
            Box(
                Modifier
                    .padding(top = 7.dp, bottom = 9.dp)
                    .width(36.dp)
                    .height(4.dp)
                    .align(Alignment.CenterHorizontally)
                    .clip(CircleShape)
                    .background(colors.border),
            )
            Row(Modifier.padding(start = 16.dp, end = 16.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Public, null, tint = colors.textSecondary, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(9.dp))
                Text("Add site", color = colors.textPrimary, fontSize = 18.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold)
            }
        }
        // AddSiteSheet.kt scrolls the whole form so folder creation and shortcuts stay reachable above the keyboard.
        LazyVerticalGrid(
            columns = GridCells.Adaptive(100.dp),
            modifier = Modifier.weight(1f, fill = false).nestedScroll(rememberNestedScrollInteropConnection()),
            contentPadding = PaddingValues(12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    SiteInput(
                        value = state.query,
                        placeholder = "https:// or search",
                        icon = Icons.Rounded.Public,
                        enabled = enabled,
                        colors = colors,
                        modifier = Modifier.fillMaxWidth(),
                        loading = state.searching,
                        onChange = onQueryChanged,
                        onGo = { onSubmit(state.query.trim()) },
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.weight(1f)) {
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .heightIn(min = 44.dp)
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(colors.cardBackground)
                                    .border(1.dp, colors.border, RoundedCornerShape(8.dp))
                                    .clickable(
                                        enabled = enabled,
                                        role = Role.Button,
                                        onClickLabel = "Choose folder",
                                        onClick = { choosingFolder = true },
                                    ).padding(horizontal = 10.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Icon(Icons.Rounded.Folder, null, Modifier.size(20.dp), colors.textSecondary)
                                Spacer(Modifier.width(7.dp))
                                Text(
                                    if (state.parent == AppConstants.ROOT_FOLDER) "— Top Level —" else state.parent,
                                    Modifier.weight(1f, fill = false),
                                    color = colors.textPrimary,
                                    fontSize = 15.sp,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                                Icon(Icons.Rounded.ExpandMore, null, Modifier.padding(start = 5.dp).size(18.dp), colors.textSecondary)
                            }
                            DropdownMenu(
                                expanded = choosingFolder,
                                onDismissRequest = { choosingFolder = false },
                                modifier = Modifier.width(300.dp).heightIn(max = 430.dp),
                                containerColor = colors.cardBackground,
                                shape = RoundedCornerShape(18.dp),
                            ) {
                                state.folders.forEach { folder ->
                                    val path = folder.flatName()
                                    DropdownMenuItem(
                                        text = {
                                            Row(
                                                Modifier.padding(start = (folder.depth() * 20).dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                            ) {
                                                Icon(
                                                    Icons.Rounded.Folder,
                                                    null,
                                                    Modifier.size(20.dp),
                                                    if (path ==
                                                        state.parent
                                                    ) {
                                                        colors.accent
                                                    } else {
                                                        colors.textSecondary
                                                    },
                                                )
                                                Spacer(Modifier.width(10.dp))
                                                Text(
                                                    if (folder.name == AppConstants.ROOT_FOLDER) "— Top Level —" else folder.name,
                                                    color = colors.textPrimary,
                                                    fontWeight = FontWeight.Normal,
                                                    fontSize = 16.sp,
                                                    lineHeight = 20.sp,
                                                    maxLines = 1,
                                                    overflow = TextOverflow.Ellipsis,
                                                )
                                            }
                                        },
                                        modifier = Modifier.semantics { contentDescription = path },
                                        onClick = {
                                            onChooseFolder(path)
                                            choosingFolder = false
                                        },
                                    )
                                }
                            }
                        }
                        Box(
                            Modifier
                                .heightIn(min = 44.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(if (canSubmit || state.submitting) colors.siteButton else colors.border)
                                .clickable(enabled = canSubmit, role = Role.Button) { onSubmit(state.query.trim()) }
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            if (state.submitting) {
                                CircularProgressIndicator(
                                    Modifier.size(20.dp).semantics { contentDescription = "Adding site" },
                                    color = Color.White,
                                    strokeWidth = 2.dp,
                                )
                            } else {
                                Text(if (folderOnly) "Add folder" else "Add site", color = Color.White, fontSize = 16.sp, lineHeight = 20.sp)
                            }
                        }
                        Box(
                            Modifier
                                .size(44.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(colors.cardBackground)
                                .border(1.dp, if (state.creatingFolder) colors.accent else colors.border, RoundedCornerShape(8.dp))
                                .clickable(enabled = enabled, role = Role.Button, onClick = onToggleFolder)
                                .semantics { contentDescription = if (state.creatingFolder) "Cancel new folder" else "Create new folder" },
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                Icons.Rounded.CreateNewFolder,
                                null,
                                Modifier.size(22.dp),
                                if (state.creatingFolder) colors.accent else colors.textSecondary,
                            )
                        }
                    }
                    AnimatedVisibility(state.creatingFolder) {
                        SiteInput(
                            state.newFolder,
                            "New folder name",
                            Icons.Rounded.Folder,
                            enabled,
                            colors,
                            Modifier.fillMaxWidth(),
                            onChange = onFolderNameChanged,
                            onGo = { onSubmit(state.query.trim()) },
                        )
                    }
                    state.error?.let {
                        Text(it, color = colors.stale, fontSize = 13.sp, lineHeight = 17.sp, modifier = Modifier.padding(vertical = 4.dp))
                    }
                }
            }
            if (state.query.isEmpty()) {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    Text(
                        "Discover more to read",
                        color = colors.textSecondary,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
                items(AddSiteDiscoveryShortcut.entries, key = { it.name }) { shortcut ->
                    DiscoveryShortcut(shortcut, colors, enabled) { onDiscover(shortcut.tab) }
                }
            } else if (state.results.isNotEmpty()) {
                itemsIndexed(
                    state.results,
                    key = { index, result -> "${result.id}:${result.url}:$index" },
                    span = { _, _ -> GridItemSpan(maxLineSpan) },
                ) { _, result ->
                    Column(Modifier.background(colors.cardBackground)) {
                        SiteResultRow(result, colors, iconLoader, enabled) { onSubmit(result.url) }
                        HorizontalDivider(color = colors.border.copy(alpha = 0.5f))
                    }
                }
            } else if (state.searched && !state.searching && state.error == null) {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    Text(
                        "No sites found. You can also add a site by URL.",
                        Modifier.padding(16.dp),
                        color = colors.textSecondary,
                        fontSize = 14.sp,
                    )
                }
            }
        }
    }
}

@Composable
private fun DiscoveryShortcut(
    shortcut: AddSiteDiscoveryShortcut,
    colors: ReaderSheetPalette.Colors,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 76.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(colors.cardBackground)
            .border(1.dp, colors.border, RoundedCornerShape(8.dp))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically),
    ) {
        if (shortcut.tab == DiscoveryTab.REDDIT) {
            Icon(painterResource(R.drawable.ic_discover_reddit), null, Modifier.size(24.dp), colors.textPrimary)
        } else {
            val icon = when (shortcut.tab) {
                DiscoveryTab.SEARCH -> Icons.Rounded.TrendingUp
                DiscoveryTab.WEB -> Icons.Rounded.Public
                DiscoveryTab.POPULAR -> Icons.Rounded.LocalFireDepartment
                DiscoveryTab.YOUTUBE -> Icons.Rounded.SmartDisplay
                DiscoveryTab.NEWSLETTERS -> Icons.Rounded.Mail
                DiscoveryTab.PODCASTS -> Icons.Rounded.Podcasts
                DiscoveryTab.GOOGLE -> Icons.Rounded.Newspaper
                DiscoveryTab.REDDIT -> Icons.Rounded.Public
            }
            Icon(icon, null, Modifier.size(24.dp), colors.textPrimary)
        }
        Text(shortcut.title, color = colors.textPrimary, fontSize = 12.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun SiteInput(
    value: String,
    placeholder: String,
    icon: ImageVector,
    enabled: Boolean,
    colors: ReaderSheetPalette.Colors,
    modifier: Modifier = Modifier,
    loading: Boolean = false,
    onChange: (String) -> Unit,
    onGo: () -> Unit,
) {
    Row(
        modifier
            .heightIn(min = 44.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(colors.cardBackground)
            .border(1.dp, colors.border, RoundedCornerShape(8.dp))
            .padding(horizontal = 10.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, Modifier.size(18.dp), colors.textSecondary)
        Spacer(Modifier.width(7.dp))
        BasicTextField(
            value,
            onChange,
            modifier = Modifier.weight(1f).semantics { contentDescription = placeholder },
            enabled = enabled,
            singleLine = true,
            textStyle = TextStyle(color = colors.textPrimary, fontSize = 16.sp, lineHeight = 20.sp),
            cursorBrush = SolidColor(colors.siteLink),
            keyboardOptions =
                KeyboardOptions(
                    keyboardType =
                        if (icon ==
                            Icons.Rounded.Public
                        ) {
                            KeyboardType.Uri
                        } else {
                            KeyboardType.Text
                        },
                    imeAction = ImeAction.Go,
                ),
            keyboardActions = KeyboardActions(onGo = { onGo() }),
            decorationBox = { field ->
                Box {
                    if (value.isEmpty()) {
                        Text(
                            placeholder,
                            color = colors.textSecondary.copy(alpha = 0.65f),
                            fontSize = 16.sp,
                            lineHeight = 20.sp,
                            maxLines = 1,
                        )
                    }
                    field()
                }
            },
        )
        if (loading) {
            CircularProgressIndicator(
                Modifier.padding(start = 6.dp).size(18.dp).semantics {
                    contentDescription = "Searching sites"
                },
                color = colors.textSecondary,
                strokeWidth = 2.dp,
            )
        }
    }
}

@Composable
private fun SiteResultRow(
    result: FeedResult,
    colors: ReaderSheetPalette.Colors,
    loader: ImageLoader,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val subscriberCount = remember(result.numberOfSubscriber) { NumberFormat.getIntegerInstance().format(result.numberOfSubscriber) }
    val freshness = remember(result.lastStorySecondsAgo) { SiteFreshness.from(result.lastStorySecondsAgo) }
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(
                enabled = enabled,
                role = Role.Button,
                onClick = onClick,
            ).padding(horizontal = 16.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        AndroidView(
            modifier = Modifier.size(28.dp).clip(RoundedCornerShape(4.dp)),
            factory = { context -> ImageView(context).apply { scaleType = ImageView.ScaleType.FIT_CENTER } },
            update = { view ->
                if (view.tag != result.faviconUrl) {
                    view.tag = result.faviconUrl
                    view.setImageResource(R.drawable.ic_world)
                    if (result.id > 0) loader.displayImage(result.faviconUrl, view)
                }
            },
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                result.label,
                color = colors.textPrimary,
                fontSize = 16.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(result.url, color = colors.siteLink, fontSize = 13.sp, lineHeight = 17.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                "$subscriberCount ${if (result.numberOfSubscriber == 1) "subscriber" else "subscribers"}",
                color = colors.textSecondary,
                fontSize = 11.sp,
                lineHeight = 14.sp,
            )
            if (freshness != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    val color = if (freshness.stale) colors.stale else colors.fresh
                    Box(Modifier.size(5.dp).clip(CircleShape).background(color))
                    Text(freshness.text, color = color, fontSize = 11.sp, lineHeight = 14.sp)
                }
            }
        }
    }
}
