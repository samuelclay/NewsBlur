package com.newsblur.onboarding

import android.text.format.DateUtils
import android.widget.ImageView
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Apartment
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.DirectionsCar
import androidx.compose.material.icons.outlined.DirectionsRun
import androidx.compose.material.icons.outlined.Eco
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Forum
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.Memory
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.MoveToInbox
import androidx.compose.material.icons.outlined.MusicNote
import androidx.compose.material.icons.outlined.Newspaper
import androidx.compose.material.icons.outlined.NightsStay
import androidx.compose.material.icons.outlined.NorthEast
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.Public
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material.icons.outlined.Science
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.SportsEsports
import androidx.compose.material.icons.outlined.TheaterComedy
import androidx.compose.material.icons.outlined.TrendingUp
import androidx.compose.material.icons.outlined.WorkOutline
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.newsblur.R
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.discover.DiscoveryFeed
import com.newsblur.discover.DiscoveryStory
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils

private val setupTeal = Color(0xFF406663)

@Composable
fun SetupScreen(
    model: SetupViewModel,
    theme: ThemeValue,
    thumbnailLoader: ImageLoader,
    onClose: () -> Unit,
    onComplete: () -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    val progress by model.queue.state.collectAsStateWithLifecycle()
    val colors = SetupPalette.colors(theme)
    val tablet = androidx.compose.ui.platform.LocalConfiguration.current.screenWidthDp >= 600
    var complete by rememberSaveable { mutableStateOf(false) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { it?.let(model::import) }
    BackHandler { if (state.category != null) model.closeBundle() else onClose() }
    Box(
        Modifier
            .fillMaxSize()
            .background(
                if (tablet) Color.Black.copy(alpha = .3f) else colors.background,
            ).safeDrawingPadding()
            .padding(vertical = if (tablet) 24.dp else 0.dp, horizontal = if (tablet) 24.dp else 0.dp),
        contentAlignment = Alignment.TopCenter,
    ) {
        Column(
            Modifier
                .widthIn(max = 808.dp)
                .fillMaxSize()
                .clip(RoundedCornerShape(if (tablet) 28.dp else 0.dp))
                .background(colors.background),
        ) {
            Row(
                Modifier.fillMaxWidth().padding(start = 24.dp, end = 24.dp, top = 16.dp, bottom = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Image(painterResource(R.drawable.logo), null, Modifier.size(36.dp))
                Text(
                    "NewsBlur",
                    Modifier.padding(start = 10.dp).weight(1f),
                    color = colors.textPrimary,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(if (complete) "2 / 2" else "1 / 2", color = colors.textSecondary, fontSize = 14.sp)
                Spacer(Modifier.width(8.dp))
                IconButton(onClick = onClose, modifier = Modifier.size(44.dp).background(colors.cardBackground, CircleShape)) {
                    Icon(Icons.Outlined.Close, "Close setup", Modifier.size(20.dp), tint = colors.textPrimary)
                }
            }
            Row(Modifier.padding(horizontal = 24.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                repeat(2) { index ->
                    Box(
                        Modifier.weight(1f).height(3.dp).background(
                            if (index == 0 ||
                                complete
                            ) {
                                colors.textSecondary
                            } else {
                                colors.border.copy(alpha = .5f)
                            },
                            CircleShape,
                        ),
                    )
                }
            }
            val categories =
                (if (state.query.isBlank()) listOf("") else emptyList()) +
                    state.categories.filter { OnboardingCatalog.title(it).contains(state.query, true) }
            val gridState = rememberLazyGridState()
            LaunchedEffect(complete) { gridState.scrollToItem(0) }
            LazyVerticalGrid(
                columns = GridCells.Adaptive(260.dp),
                state = gridState,
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(24.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                if (complete) {
                    item(span = { GridItemSpan(maxLineSpan) }) { Completion(state, progress, colors) }
                } else {
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        ImportPanel(
                            state,
                            colors,
                        ) { picker.launch(arrayOf("text/*", "application/xml", "application/octet-stream", "application/opml+xml")) }
                    }
                    item(span = { GridItemSpan(maxLineSpan) }) { SearchHeader(state, colors, model::search) }
                    if (state.loading && state.categories.isEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }) {
                            Column(
                                Modifier
                                    .fillMaxWidth()
                                    .heightIn(
                                        min = 320.dp,
                                    ).background(colors.cardBackground.copy(alpha = .45f), RoundedCornerShape(24.dp)),
                                verticalArrangement = Arrangement.Center,
                                horizontalAlignment = Alignment.CenterHorizontally,
                            ) {
                                Box(Modifier.size(116.dp), contentAlignment = Alignment.Center) {
                                    CircularProgressIndicator(Modifier.size(110.dp), color = colors.border, strokeWidth = 2.dp)
                                    Icon(Icons.Outlined.GridView, null, Modifier.size(68.dp), tint = colors.textSecondary)
                                }
                                Text(
                                    "Loading interests",
                                    Modifier.padding(top = 24.dp),
                                    color = colors.textPrimary,
                                    fontSize = 20.sp,
                                    fontWeight = FontWeight.SemiBold,
                                )
                                Text("Finding feeds for you to explore", Modifier.padding(top = 8.dp), color = colors.textSecondary)
                            }
                        }
                    } else if (state.categories.isNotEmpty()) {
                        items(categories, key = { "category:$it" }) { category ->
                            InterestCard(category, state, progress, colors, { model.loadIcons(category) }) { model.openBundle(category) }
                        }
                    }
                    if (state.iconFailures.isNotEmpty()) {
                        item(span = {
                            GridItemSpan(maxLineSpan)
                        }) { TextButton(onClick = model::retryIcons) { Text("Retry icons", color = colors.siteLink) } }
                    }
                    if (state.query.isNotBlank()) {
                        item(span = {
                            GridItemSpan(maxLineSpan)
                        }) { Text("Search all sites", color = colors.textPrimary, fontSize = 20.sp, fontWeight = FontWeight.SemiBold) }
                        if (state.searching) item(span = { GridItemSpan(maxLineSpan) }) { CircularProgressIndicator(color = setupTeal) }
                        items(state.search, key = {
                            "search:${it.url}"
                        }, span = { GridItemSpan(maxLineSpan) }) { feed -> SearchResult(feed, state, progress, colors, model) }
                    }
                    state.error?.let { message ->
                        item(span = { GridItemSpan(maxLineSpan) }) {
                            Column {
                                Text(message, color = colors.textPrimary)
                                if (state.categories.isEmpty()) TextButton(onClick = { model.loadCatalog() }) { Text("Try again") }
                            }
                        }
                    }
                }
                if (progress.failures.isNotEmpty()) item(span = { GridItemSpan(maxLineSpan) }) { Failures(progress, model, colors) }
            }
            PrimaryAction(
                if (complete) "Start reading" else "Continue",
                Modifier.padding(horizontal = 24.dp, vertical = 16.dp),
                enabled = !state.importing,
            ) {
                model.queue.refresh()
                if (complete) onComplete() else complete = true
            }
        }
    }
    if (state.category !=
        null
    ) {
        Dialog(
            onDismissRequest = {
            },
            properties =
                DialogProperties(
                    usePlatformDefaultWidth = false,
                    dismissOnBackPress = false,
                    dismissOnClickOutside = false,
                ),
        ) {
            Box(Modifier.fillMaxSize().safeDrawingPadding(), contentAlignment = Alignment.Center) {
                Column(
                    Modifier
                        .widthIn(
                            max = 640.dp,
                        ).fillMaxHeight(if (tablet) .92f else 1f)
                        .background(colors.background, RoundedCornerShape(20.dp)),
                ) {
                    Box(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 12.dp), contentAlignment = Alignment.Center) {
                        Text(
                            if (state.category!!.isEmpty()) "A little of everything" else OnboardingCatalog.title(state.category!!),
                            Modifier.fillMaxWidth().padding(horizontal = 56.dp),
                            color = colors.textPrimary,
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold,
                            textAlign = TextAlign.Center,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                        TextButton(
                            onClick = model::closeBundle,
                            modifier = Modifier.align(Alignment.CenterEnd),
                        ) { Text("Done", color = colors.siteLink) }
                    }
                    Column(
                        Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(18.dp),
                    ) {
                        Text(
                            "Choose feeds for your folder",
                            color = colors.textPrimary,
                            fontSize = 28.sp,
                            lineHeight = 33.sp,
                            fontWeight = FontWeight.Bold,
                        )
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .border(
                                    1.dp,
                                    colors.border,
                                    RoundedCornerShape(12.dp),
                                ).background(colors.inputBackground, RoundedCornerShape(12.dp))
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Outlined.Folder, null, tint = colors.textSecondary)
                            BasicTextField(
                                state.folder,
                                model::folder,
                                Modifier
                                    .padding(
                                        start = 12.dp,
                                    ).weight(
                                        1f,
                                    ),
                                singleLine = true,
                                textStyle =
                                    TextStyle(
                                        color = colors.textPrimary,
                                        fontSize = 20.sp,
                                        fontWeight = FontWeight.Bold,
                                    ),
                                cursorBrush = SolidColor(setupTeal),
                                decorationBox = { inner ->
                                    if (state.folder.isEmpty()) Text("Folder name", color = colors.textSecondary)
                                    inner()
                                },
                            )
                        }
                        state.choices.feeds.forEach { feed ->
                            val status =
                                when (feed.url) {
                                    in progress.added, in state.unavailable -> "Added"
                                    in progress.queued -> "Queued"
                                    else -> null
                                }
                            BundleCard(
                                feed,
                                feed.url in state.choices.selected,
                                status,
                                state,
                                colors,
                                thumbnailLoader,
                            ) { model.toggle(feed.url) }
                        }
                        if (state.bundleLoading) {
                            Row(
                                Modifier.fillMaxWidth().background(colors.cardBackground, RoundedCornerShape(16.dp)).padding(24.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                CircularProgressIndicator(Modifier.size(24.dp), color = colors.textSecondary, strokeWidth = 2.dp)
                                Text(
                                    if (state.choices.feeds.isEmpty()) "Loading feeds to choose from…" else "Loading more feeds…",
                                    Modifier.padding(start = 14.dp),
                                    color = colors.textSecondary,
                                )
                            }
                        }
                        state.bundleError?.let {
                            Text(it, color = colors.textSecondary)
                            TextButton(onClick = { model.openBundle(state.category!!) }) { Text("Try again") }
                        }
                    }
                    if (!state.bundleLoading || state.choices.feeds.isNotEmpty()) {
                        val count = state.choices.selected.size
                        val label =
                            if (count ==
                                0
                            ) {
                                "Select feeds to add"
                            } else if (state.folder.isBlank()) {
                                "Name your folder to continue"
                            } else {
                                "Add $count ${if (count == 1) "feed" else "feeds"} to “${state.folder.trim()}” folder"
                            }
                        PrimaryAction(label, Modifier.padding(16.dp), count > 0 && state.folder.isNotBlank(), model::addBundle)
                    }
                }
            }
        }
    }
}

@Composable private fun PrimaryAction(
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Button(
        onClick,
        modifier.fillMaxWidth().heightIn(min = 54.dp),
        enabled = enabled,
        shape = RoundedCornerShape(14.dp),
        colors =
            ButtonDefaults.buttonColors(
                containerColor = setupTeal,
                contentColor = Color.White,
                disabledContainerColor = setupTeal.copy(alpha = .45f),
                disabledContentColor = Color.White,
            ),
        contentPadding = PaddingValues(16.dp),
    ) {
        Text(label, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
    }
}

@Composable private fun ImportPanel(
    state: SetupState,
    colors: ReaderSheetPalette.Colors,
    onImport: () -> Unit,
) {
    BoxWithConstraints(
        Modifier.fillMaxWidth().background(colors.cardBackground.copy(alpha = .7f), RoundedCornerShape(20.dp)).padding(20.dp),
    ) {
        val wide = maxWidth >= 510.dp
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Icon(Icons.Outlined.MoveToInbox, null, Modifier.size(25.dp), tint = colors.textPrimary)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Already have feeds?", color = colors.textPrimary, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                    Text("Bring your feeds and folders from another reader.", color = colors.textSecondary, fontSize = 15.sp)
                }
                if (wide) ImportButton(state.importing, colors, onImport)
            }
            if (!wide) ImportButton(state.importing, colors, onImport)
            state.importMessage?.let { Text(it, color = colors.textSecondary, fontSize = 14.sp) }
        }
    }
}

@Composable private fun ImportButton(
    busy: Boolean,
    colors: ReaderSheetPalette.Colors,
    onImport: () -> Unit,
) {
    OutlinedButton(
        onImport,
        modifier = Modifier.heightIn(min = 44.dp),
        enabled = !busy,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, colors.border),
        colors = ButtonDefaults.outlinedButtonColors(containerColor = colors.cardBackground),
    ) {
        Text(if (busy) "Importing…" else "Import OPML", color = colors.textPrimary, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable private fun SearchHeader(
    state: SetupState,
    colors: ReaderSheetPalette.Colors,
    onSearch: (String) -> Unit,
) {
    var focused by remember { mutableStateOf(false) }
    BoxWithConstraints {
        val showHeading = !focused || maxWidth >= 550.dp
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            if (showHeading) {
                Column(Modifier.width(IntrinsicSize.Max)) {
                    Text("Explore interests", color = colors.textPrimary, fontSize = 24.sp, fontWeight = FontWeight.SemiBold)
                    if (state.categories.isNotEmpty()) {
                        Text(
                            "${state.categories.size} categories to choose from",
                            Modifier.padding(top = 4.dp),
                            color = colors.textSecondary,
                            fontSize = 12.sp,
                        )
                    }
                }
            }
            Row(
                Modifier
                    .then(
                        if (showHeading) Modifier.widthIn(max = 240.dp).weight(1f) else Modifier.fillMaxWidth(),
                    ).height(44.dp)
                    .background(colors.inputBackground, RoundedCornerShape(12.dp))
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Outlined.Search, "Search interests and sites", Modifier.size(20.dp), tint = colors.textSecondary)
                BasicTextField(
                    state.query,
                    onSearch,
                    Modifier.padding(start = 8.dp).weight(1f).onFocusChanged {
                        focused = it.isFocused
                    },
                    singleLine = true,
                    textStyle =
                        TextStyle(
                            color = colors.textPrimary,
                            fontSize = 15.sp,
                        ),
                    cursorBrush = SolidColor(setupTeal),
                    decorationBox = { inner ->
                        if (state.query.isBlank()) Text("Search", color = colors.textSecondary, fontSize = 15.sp)
                        inner()
                    },
                )
                if (state.query.isNotEmpty()) {
                    IconButton(onClick = {
                        onSearch("")
                    }, modifier = Modifier.size(28.dp)) { Icon(Icons.Outlined.Close, "Clear search", tint = colors.textSecondary) }
                }
            }
        }
    }
}

@Composable private fun InterestCard(
    category: String,
    state: SetupState,
    progress: SetupProgress,
    colors: ReaderSheetPalette.Colors,
    load: () -> Unit,
    onClick: () -> Unit,
) {
    LaunchedEffect(category) { load() }
    val urls = progress.categories[category].orEmpty()
    val pending = urls.intersect(progress.queued).size
    val count = urls.intersect(progress.queued + progress.added).size
    val accent = if (colors.textPrimary.red > .7f) Color(0xFFA3CBC3) else setupTeal
    Column(
        Modifier
            .fillMaxWidth()
            .height(164.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(colors.cardBackground)
            .background(
                if (count >
                    0
                ) {
                    accent.copy(alpha = .1f)
                } else {
                    Color.Transparent
                },
            ).border(
                1.dp,
                if (count >
                    0
                ) {
                    accent.copy(alpha = .5f)
                } else {
                    colors.border.copy(alpha = .45f)
                },
                RoundedCornerShape(16.dp),
            ).clickable(onClick = onClick)
            .padding(20.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(categoryIcon(category), null, Modifier.size(23.dp), tint = colors.textPrimary)
            Text(
                if (category.isEmpty()) "A little of everything" else OnboardingCatalog.title(category),
                color = colors.textPrimary,
                fontSize = 17.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
            )
        }
        Spacer(Modifier.weight(1f))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            repeat(5) { index ->
                val bitmap = state.cardIcons[category]?.getOrNull(index)?.let { state.icons[it] }
                Box(Modifier.size(34.dp).background(colors.background.copy(alpha = .65f), RoundedCornerShape(9.dp)).padding(3.dp)) {
                    if (bitmap != null) {
                        Image(bitmap.asImageBitmap(), null, Modifier.fillMaxSize().clip(RoundedCornerShape(5.dp)))
                    } else {
                        Box(Modifier.fillMaxSize().background(colors.border.copy(alpha = .45f), RoundedCornerShape(7.dp)))
                    }
                }
            }
        }
        Row(Modifier.padding(top = 10.dp).alpha(if (count > 0) 1f else 0f), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Outlined.CheckCircle, null, Modifier.size(14.dp), tint = accent)
            Text(
                "$count ${if (count == 1) "feed" else "feeds"} ${if (pending > 0) "selected" else "added"}",
                Modifier.padding(start = 5.dp),
                color = accent,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

private fun categoryIcon(name: String): ImageVector =
    when {
        name.isEmpty() -> Icons.Outlined.AutoAwesome
        "tech" in name -> Icons.Outlined.Memory
        "science" in name -> Icons.Outlined.Science
        "food" in name -> Icons.Outlined.Restaurant
        "design" in name || "art" in name -> Icons.Outlined.Palette
        "travel" in name -> Icons.Outlined.Public
        "music" in name -> Icons.Outlined.MusicNote
        "sport" in name -> Icons.Outlined.DirectionsRun
        "news" in name -> Icons.Outlined.Newspaper
        "business" in name -> Icons.Outlined.TrendingUp
        "gaming" in name -> Icons.Outlined.SportsEsports
        "book" in name -> Icons.Outlined.MenuBook
        "nature" in name || "agriculture" in name -> Icons.Outlined.Eco
        "space" in name -> Icons.Outlined.NightsStay
        "architecture" in name -> Icons.Outlined.Apartment
        "autom" in name -> Icons.Outlined.DirectionsCar
        "career" in name -> Icons.Outlined.WorkOutline
        "comedy" in name -> Icons.Outlined.TheaterComedy
        "anime" in name -> Icons.Outlined.AutoAwesome
        else -> Icons.Outlined.Layers
    }

@Composable private fun FeedIcon(
    feed: DiscoveryFeed,
    state: SetupState,
    colors: ReaderSheetPalette.Colors,
    size: Int = 36,
) {
    Box(Modifier.size(size.dp).clip(RoundedCornerShape(8.dp)).background(colors.background), contentAlignment = Alignment.Center) {
        val icon = state.icons[feed.id.ifBlank { feed.url }]
        if (icon !=
            null
        ) {
            Image(icon.asImageBitmap(), null, Modifier.fillMaxSize().padding(3.dp))
        } else {
            Text(feed.title.take(1).uppercase(), color = colors.textPrimary, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable private fun BundleCard(
    feed: DiscoveryFeed,
    selected: Boolean,
    status: String?,
    state: SetupState,
    colors: ReaderSheetPalette.Colors,
    thumbnails: ImageLoader,
    onClick: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .alpha(
                if (selected ||
                    status != null
                ) {
                    1f
                } else {
                    .5f
                },
            ).clip(
                RoundedCornerShape(12.dp),
            ).background(colors.cardBackground)
            .border(1.dp, colors.border, RoundedCornerShape(12.dp))
            .toggleable(
                value = selected || status != null,
                enabled =
                    status == null,
                role = Role.Checkbox,
                onValueChange = { onClick() },
            ).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FeedIcon(feed, state, colors)
            Column(Modifier.weight(1f)) {
                Text(feed.title, color = colors.textPrimary, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                Text(
                    android.net.Uri
                        .parse(feed.link)
                        .host ?: feed.link,
                    color = colors.siteLink,
                    fontSize = 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        FeedStatistics(feed, colors)
        if (feed.description.isNotBlank()) {
            Text(
                UIUtils.fromHtml(feed.description).toString(),
                color = colors.textSecondary,
                fontSize = 14.sp,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (feed.stories.isNotEmpty()) HorizontalDivider(color = colors.border)
        feed.stories.take(3).forEach { story -> BundleStory(story, colors, thumbnails) }
        HorizontalDivider(color = colors.border)
        Row(
            Modifier.fillMaxWidth().heightIn(min = 44.dp),
            horizontalArrangement = Arrangement.Start,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                if (selected ||
                    status != null
                ) {
                    Icons.Outlined.CheckCircle
                } else {
                    Icons.Outlined.RadioButtonUnchecked
                },
                null,
                Modifier.size(22.dp),
                tint = setupTeal,
            )
            Text(
                status ?: if (selected) "Included in bundle" else "Include in bundle",
                Modifier.padding(start = 6.dp),
                color = colors.textSecondary,
                fontSize = 14.sp,
            )
        }
    }
}

@Composable private fun SearchResult(
    feed: DiscoveryFeed,
    state: SetupState,
    progress: SetupProgress,
    colors: ReaderSheetPalette.Colors,
    model: SetupViewModel,
) {
    var folder by remember(feed.url) { mutableStateOf("") }
    var choose by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().background(colors.cardBackground, RoundedCornerShape(12.dp)).padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FeedIcon(feed, state, colors)
            Column(Modifier.weight(1f)) {
                Text(feed.title, color = colors.textPrimary, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                Text(feed.url, color = colors.siteLink, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Spacer(Modifier.height(8.dp))
        FeedStatistics(feed, colors)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            Box {
                TextButton(onClick = { choose = true }) { Text(folder.ifEmpty { "All Site Stories" }, color = colors.siteLink) }
                DropdownMenu(choose, { choose = false }) {
                    state.existingFolders.forEach { option ->
                        DropdownMenuItem(text = { Text(option.ifEmpty { "All Site Stories" }) }, onClick = {
                            folder =
                                option
                            ; choose = false
                        })
                    }
                }
            }
            val unavailable = feed.url in state.unavailable || feed.url in progress.added || feed.url in progress.queued
            TextButton(onClick = {
                model.addSearch(feed, folder)
            }, enabled = !unavailable) {
                Text(
                    if (feed.url in
                        progress.queued
                    ) {
                        "Queued"
                    } else if (unavailable) {
                        "Added"
                    } else {
                        "Add"
                    },
                    color = colors.siteLink,
                )
            }
        }
    }
}

@Composable private fun Completion(
    state: SetupState,
    progress: SetupProgress,
    colors: ReaderSheetPalette.Colors,
) {
    val accepted = progress.queued + progress.added
    val folders =
        progress.folders
            .mapValues {
                it.value.filter { feed ->
                    feed.url in accepted
                }
            }.filterValues { it.isNotEmpty() }
            .toSortedMap()
    val count =
        folders.values
            .flatten()
            .distinctBy { it.url }
            .size
    val accent = if (colors.textPrimary.red > .7f) Color(0xFFA3CBC3) else setupTeal
    val uriHandler = LocalUriHandler.current
    Column(verticalArrangement = Arrangement.spacedBy(28.dp)) {
        Column(
            Modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(Modifier.size(108.dp).background(accent.copy(alpha = .05f), CircleShape), contentAlignment = Alignment.Center) {
                Box(Modifier.size(82.dp).background(accent.copy(alpha = .1f), CircleShape), contentAlignment = Alignment.Center) {
                    Icon(Icons.Outlined.Check, null, Modifier.size(38.dp), tint = accent)
                }
            }
            Text(
                "You’re all set up.",
                color = colors.textPrimary,
                fontSize = 32.sp,
                lineHeight = 38.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Text(
                if (count ==
                    0
                ) {
                    "Your reader is ready. Add feeds anytime from Add + Discover Sites."
                } else {
                    "A reading list that’s yours. Everything you chose, in one place."
                },
                color = colors.textSecondary,
                textAlign = TextAlign.Center,
                fontSize = 16.sp,
            )
        }
        if (folders.isNotEmpty()) {
            Column(
                Modifier.fillMaxWidth().background(colors.cardBackground, RoundedCornerShape(22.dp)).padding(22.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                Row {
                    Text(
                        "Your reading list",
                        Modifier.weight(1f),
                        color = colors.textPrimary,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text("$count ${if (count == 1) "feed" else "feeds"}", color = accent)
                }
                folders.forEach { (folder, feeds) ->
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Outlined.Folder, null, tint = accent)
                            Text(
                                folder.ifEmpty {
                                    "All Site Stories"
                                },
                                Modifier.padding(start = 10.dp).weight(1f),
                                color = colors.textPrimary,
                                fontWeight = FontWeight.SemiBold,
                            )
                            Text("${feeds.size}", color = colors.textSecondary, fontSize = 12.sp)
                        }
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            feeds.forEach { FeedIcon(it, state, colors) }
                        }
                        Text(
                            feeds.joinToString(" · ") { it.title },
                            color = colors.textSecondary,
                            fontSize = 12.sp,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                "Stay connected",
                Modifier.padding(horizontal = 4.dp),
                color = colors.textSecondary,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp,
            )
            Column(Modifier.background(colors.cardBackground, RoundedCornerShape(22.dp))) {
                val links =
                    listOf(
                        Triple("NewsBlur Forum", "Ask questions and share ideas", "https://forum.newsblur.com"),
                        Triple("@samuelclay on X", "From the creator of NewsBlur", "https://x.com/samuelclay"),
                        Triple("@NewsBlur on X", "News and updates", "https://x.com/NewsBlur"),
                    )
                links.forEachIndexed { i, link ->
                    if (i > 0) HorizontalDivider(Modifier.padding(start = 80.dp), color = colors.border.copy(alpha = .5f))
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable {
                                uriHandler.openUri(link.third)
                            }.padding(20.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        Box(Modifier.size(44.dp)) {
                            if (i ==
                                0
                            ) {
                                Box(
                                    Modifier.fillMaxSize().background(accent.copy(alpha = .1f), CircleShape),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Icon(Icons.Outlined.Forum, null, tint = accent)
                                }
                            } else {
                                Image(
                                    painterResource(
                                        if (i ==
                                            1
                                        ) {
                                            R.drawable.onboarding_samuel
                                        } else {
                                            R.drawable.logo
                                        },
                                    ),
                                    null,
                                    Modifier.fillMaxSize().clip(CircleShape),
                                )
                                Text(
                                    "𝕏",
                                    Modifier
                                        .align(
                                            Alignment.BottomEnd,
                                        ).background(colors.cardBackground, CircleShape)
                                        .padding(2.dp),
                                    color = colors.textPrimary,
                                    fontSize = 12.sp,
                                )
                            }
                        }
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(link.first, color = colors.textPrimary, fontWeight = FontWeight.SemiBold)
                            Text(link.second, color = colors.textSecondary, fontSize = 14.sp)
                        }
                        Icon(Icons.Outlined.NorthEast, null, Modifier.size(16.dp), tint = colors.textSecondary)
                    }
                }
            }
        }
    }
}

@Composable private fun Failures(
    progress: SetupProgress,
    model: SetupViewModel,
    colors: ReaderSheetPalette.Colors,
) {
    Column {
        progress.failures.forEach { failure ->
            Text(
                "${failure.feeds.size} feeds could not be added to ${failure.folder.ifEmpty { "All Site Stories" }}. ${failure.message}",
                color = colors.textSecondary,
            )
            TextButton(onClick = { model.queue.retry(failure) }) { Text("Retry", color = colors.siteLink) }
        }
    }
}

@Composable private fun FeedStatistics(
    feed: DiscoveryFeed,
    colors: ReaderSheetPalette.Colors,
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                "${java.text.NumberFormat.getIntegerInstance().format(feed.subscribers)} subscribers",
                color = colors.textSecondary,
                fontSize = 12.sp,
            )
            if (feed.storiesPerMonth > 0) Text("${feed.storiesPerMonth} stories/month", color = colors.textSecondary, fontSize = 12.sp)
        }
        val date =
            com.newsblur.util.DiscoverFeedFreshnessFormatter
                .parseApiDateMillis(feed.lastStoryDate)
                ?: feed.stories.mapNotNull { it.timestamp?.times(1000) }.maxOrNull()
        if (date != null) {
            val stale = System.currentTimeMillis() - date > 365L * 86400000
            Text(
                "● ${if (stale) "Stale · last story" else "Updated"} ${DateUtils.getRelativeTimeSpanString(
                    date,
                    System.currentTimeMillis(),
                    DateUtils.MINUTE_IN_MILLIS,
                )}",
                color = if (stale) colors.stale else colors.fresh,
                fontSize = 12.sp,
            )
        }
    }
}

@Composable private fun BundleStory(
    story: DiscoveryStory,
    colors: ReaderSheetPalette.Colors,
    thumbnails: ImageLoader,
) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 44.dp).padding(horizontal = 8.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(Modifier.padding(top = 6.dp).size(5.dp).background(colors.accent, CircleShape))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                UIUtils.fromHtml(story.title).toString(),
                color = colors.textPrimary,
                fontSize = 13.sp,
                lineHeight = 17.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            if (story.excerpt.isNotBlank()) {
                Text(
                    UIUtils.fromHtml(story.excerpt).toString(),
                    color = colors.textSecondary,
                    fontSize = 12.sp,
                    lineHeight = 16.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            val date =
                story.timestamp?.let {
                    DateUtils.getRelativeTimeSpanString(it * 1000, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS).toString()
                }
            Text(
                listOfNotNull(
                    story.authors
                        .takeIf {
                            it.isNotBlank()
                        }?.let {
                            UIUtils.fromHtml(it).toString()
                        },
                    date,
                ).joinToString(" · "),
                color = colors.textSecondary,
                fontSize = 11.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (story.imageUrl.isNotBlank()) {
            AndroidView(modifier = Modifier.size(48.dp).clip(RoundedCornerShape(4.dp)), factory = {
                ImageView(it).apply {
                    scaleType =
                        ImageView.ScaleType.CENTER_CROP
                }
            }, update = { view ->
                if (view.tag !=
                    story.imageUrl
                ) {
                    view.tag = story.imageUrl
                    view.setImageDrawable(null)
                    thumbnails.displayImage(story.imageUrl, view)
                }
            })
        }
    }
}
