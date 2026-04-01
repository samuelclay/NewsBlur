package com.newsblur.compose

import android.content.SharedPreferences
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.Article
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.DeleteSweep
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.FilterList
import androidx.compose.material.icons.rounded.Forum
import androidx.compose.material.icons.rounded.Gesture
import androidx.compose.material.icons.rounded.Image
import androidx.compose.material.icons.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.ListAlt
import androidx.compose.material.icons.rounded.MenuBook
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.OpenInBrowser
import androidx.compose.material.icons.rounded.Photo
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.ShortText
import androidx.compose.material.icons.rounded.SortByAlpha
import androidx.compose.material.icons.rounded.SwapVert
import androidx.compose.material.icons.rounded.SwipeRightAlt
import androidx.compose.material.icons.rounded.TextFields
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.VolumeUp
import androidx.compose.material.icons.rounded.Wifi
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.newsblur.R
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.DefaultBrowser
import com.newsblur.util.FeedListOrder
import com.newsblur.util.GestureAction
import com.newsblur.util.MarkAllReadConfirmation
import com.newsblur.util.MarkStoryReadBehavior
import com.newsblur.util.PrefConstants
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.ReadFilter
import com.newsblur.util.StoryContentPreviewStyle
import com.newsblur.util.StoryClusterDisplayDecision
import com.newsblur.util.StoryOrder
import com.newsblur.util.ThumbnailStyle
import com.newsblur.util.VolumeKeyNavigation

@Immutable
data class SettingsUiState(
    val theme: ThemeValue = ThemeValue.AUTO,
    val enableOffline: Boolean = false,
    val enableImagePrefetch: Boolean = false,
    val networkSelect: String = PrefConstants.NETWORK_SELECT_NOMONONME,
    val keepOldStories: Boolean = false,
    val cacheAgeSelect: String = PrefConstants.CACHE_AGE_SELECT_30D,
    val feedListOrder: String = FeedListOrder.ALPHABETICAL.name,
    val enableRowGlobalShared: Boolean = true,
    val enableRowInfrequentStories: Boolean = true,
    val enableRowDailyBriefing: Boolean = true,
    val defaultStoryOrder: String = StoryOrder.NEWEST.name,
    val defaultReadFilter: String = ReadFilter.ALL.name,
    val markAllReadConfirmation: String = MarkAllReadConfirmation.FOLDER_ONLY.name,
    val confirmMarkRangeRead: Boolean = false,
    val loadNextOnMarkRead: Boolean = false,
    val autoOpenFirstUnread: Boolean = false,
    val markReadOnScroll: Boolean = false,
    val storyClustering: Boolean = true,
    val storyContentPreviewStyle: String = StoryContentPreviewStyle.MEDIUM.name,
    val thumbnailStyle: String = ThumbnailStyle.RIGHT_LARGE.name,
    val markStoryReadBehavior: String = MarkStoryReadBehavior.IMMEDIATELY.name,
    val defaultBrowser: String = DefaultBrowser.SYSTEM_DEFAULT.name,
    val readingFont: String = "DEFAULT",
    val volumeKeyNavigation: String = VolumeKeyNavigation.OFF.name,
    val showPublicComments: Boolean = true,
    val ltrGestureAction: String = GestureAction.GEST_ACTION_BACK.name,
    val rtlGestureAction: String = GestureAction.GEST_ACTION_TOGGLE_READ.name,
    val enableNotifications: Boolean = false,
    val showAskAi: Boolean = true,
)

fun buildSettingsUiState(
    prefsRepo: PrefsRepo,
    sharedPreferences: SharedPreferences,
): SettingsUiState =
    SettingsUiState(
        theme = prefsRepo.getSelectedTheme(),
        enableOffline = prefsRepo.isOfflineEnabled(),
        enableImagePrefetch = prefsRepo.isImagePrefetchEnabled(),
        networkSelect =
            sharedPreferences.getString(
                PrefConstants.NETWORK_SELECT,
                PrefConstants.NETWORK_SELECT_NOMONONME,
            ) ?: PrefConstants.NETWORK_SELECT_NOMONONME,
        keepOldStories = prefsRepo.isKeepOldStories(),
        cacheAgeSelect =
            sharedPreferences.getString(
                PrefConstants.CACHE_AGE_SELECT,
                PrefConstants.CACHE_AGE_SELECT_30D,
            ) ?: PrefConstants.CACHE_AGE_SELECT_30D,
        feedListOrder = prefsRepo.getFeedListOrder().name,
        enableRowGlobalShared = prefsRepo.isEnableRowGlobalShared(),
        enableRowInfrequentStories = prefsRepo.isEnableRowInfrequent(),
        enableRowDailyBriefing = prefsRepo.isEnableRowDailyBriefing(),
        defaultStoryOrder = prefsRepo.getDefaultStoryOrder().name,
        defaultReadFilter =
            sharedPreferences.getString(
                PrefConstants.DEFAULT_READ_FILTER,
                ReadFilter.ALL.name,
            ) ?: ReadFilter.ALL.name,
        markAllReadConfirmation = prefsRepo.getMarkAllReadConfirmation().name,
        confirmMarkRangeRead = prefsRepo.isConfirmMarkRangeRead(),
        loadNextOnMarkRead = prefsRepo.loadNextOnMarkRead(),
        autoOpenFirstUnread = prefsRepo.isAutoOpenFirstUnread(),
        markReadOnScroll = prefsRepo.isMarkReadOnFeedScroll(),
        storyClustering = StoryClusterDisplayDecision.isStoryClusteringEnabled(prefsRepo),
        storyContentPreviewStyle = prefsRepo.getStoryContentPreviewStyle().name,
        thumbnailStyle = prefsRepo.getThumbnailStyle().name,
        markStoryReadBehavior = prefsRepo.getMarkStoryReadBehavior().name,
        defaultBrowser = prefsRepo.getDefaultBrowser().name,
        readingFont = prefsRepo.getFontString(),
        volumeKeyNavigation = prefsRepo.getVolumeKeyNavigation().name,
        showPublicComments = prefsRepo.showPublicComments(),
        ltrGestureAction = prefsRepo.getLeftToRightGestureAction().name,
        rtlGestureAction = prefsRepo.getRightToLeftGestureAction().name,
        enableNotifications = prefsRepo.isEnableNotifications(),
        showAskAi = prefsRepo.isShowAskAi(),
    )

@Composable
fun SettingsScreen(
    state: SettingsUiState,
    onBooleanChanged: (String, Boolean) -> Unit,
    onStringChanged: (String, String) -> Unit,
    onDeleteOfflineStories: () -> Unit,
) {
    val palette = settingsPalette(state.theme)
    var dialogState by remember { mutableStateOf<ChoiceDialogState?>(null) }

    val networkOptions =
        listOf(
            ChoiceOption(PrefConstants.NETWORK_SELECT_ANY, stringResource(R.string.menu_network_select_opt_any)),
            ChoiceOption(PrefConstants.NETWORK_SELECT_NOMO, stringResource(R.string.menu_network_select_opt_nomo)),
            ChoiceOption(PrefConstants.NETWORK_SELECT_NOMONONME, stringResource(R.string.menu_network_select_opt_nomononme)),
        )
    val cacheAgeOptions =
        listOf(
            ChoiceOption(PrefConstants.CACHE_AGE_SELECT_2D, stringResource(R.string.menu_cache_age_select_opt_2d)),
            ChoiceOption(PrefConstants.CACHE_AGE_SELECT_7D, stringResource(R.string.menu_cache_age_select_opt_7d)),
            ChoiceOption(PrefConstants.CACHE_AGE_SELECT_14D, stringResource(R.string.menu_cache_age_select_opt_14d)),
            ChoiceOption(PrefConstants.CACHE_AGE_SELECT_30D, stringResource(R.string.menu_cache_age_select_opt_30d)),
        )
    val feedListOrderOptions =
        listOf(
            ChoiceOption(FeedListOrder.ALPHABETICAL.name, stringResource(R.string.alphabetical)),
            ChoiceOption(FeedListOrder.MOST_USED_AT_TOP.name, stringResource(R.string.most_used_at_top)),
        )
    val storyOrderOptions =
        listOf(
            ChoiceOption(StoryOrder.NEWEST.name, stringResource(R.string.newest), stringResource(R.string.newest)),
            ChoiceOption(StoryOrder.OLDEST.name, stringResource(R.string.oldest), stringResource(R.string.oldest)),
        )
    val readFilterOptions =
        listOf(
            ChoiceOption(ReadFilter.ALL.name, stringResource(R.string.all_stories), stringResource(R.string.all_stories)),
            ChoiceOption(ReadFilter.UNREAD.name, stringResource(R.string.unread_only), stringResource(R.string.unread_only)),
        )
    val confirmMarkReadOptions =
        listOf(
            ChoiceOption(
                MarkAllReadConfirmation.FEED_AND_FOLDER.name,
                stringResource(R.string.feed_and_folder),
                stringResource(R.string.settings_confirm_mark_all_read_segment_both),
            ),
            ChoiceOption(
                MarkAllReadConfirmation.FOLDER_ONLY.name,
                stringResource(R.string.folder_only),
                stringResource(R.string.settings_confirm_mark_all_read_segment_folders),
            ),
            ChoiceOption(
                MarkAllReadConfirmation.NONE.name,
                stringResource(R.string.none),
                stringResource(R.string.settings_confirm_mark_all_read_segment_never),
            ),
        )
    val afterMarkReadOptions =
        listOf(
            ChoiceOption(
                "next",
                stringResource(R.string.settings_after_mark_read_next),
                stringResource(R.string.settings_after_mark_read_next),
            ),
            ChoiceOption(
                "stay",
                stringResource(R.string.settings_after_mark_read_stay),
                stringResource(R.string.settings_after_mark_read_stay),
            ),
        )
    val siteOpeningOptions =
        listOf(
            ChoiceOption(
                "stories",
                stringResource(R.string.settings_when_opening_site_stories),
                stringResource(R.string.settings_when_opening_site_stories),
            ),
            ChoiceOption(
                "first_story",
                stringResource(R.string.settings_when_opening_site_first_story),
                stringResource(R.string.settings_when_opening_site_first_story),
            ),
        )
    val markStoryReadOptions =
        listOf(
            ChoiceOption(MarkStoryReadBehavior.IMMEDIATELY.name, stringResource(R.string.mark_story_read_immediately)),
            ChoiceOption(MarkStoryReadBehavior.SECONDS_5.name, stringResource(R.string.mark_story_read_5_seconds)),
            ChoiceOption(MarkStoryReadBehavior.SECONDS_10.name, stringResource(R.string.mark_story_read_10_seconds)),
            ChoiceOption(MarkStoryReadBehavior.SECONDS_20.name, stringResource(R.string.mark_story_read_20_seconds)),
            ChoiceOption(MarkStoryReadBehavior.SECONDS_30.name, stringResource(R.string.mark_story_read_30_seconds)),
            ChoiceOption(MarkStoryReadBehavior.SECONDS_45.name, stringResource(R.string.mark_story_read_45_seconds)),
            ChoiceOption(MarkStoryReadBehavior.SECONDS_60.name, stringResource(R.string.mark_story_read_60_seconds)),
            ChoiceOption(MarkStoryReadBehavior.MANUALLY.name, stringResource(R.string.mark_story_read_manually)),
        )
    val contentPreviewOptions =
        listOf(
            ChoiceOption(
                StoryContentPreviewStyle.NONE.name,
                stringResource(R.string.story_content_preview_none),
                stringResource(R.string.story_content_preview_none),
            ),
            ChoiceOption(
                StoryContentPreviewStyle.SMALL.name,
                stringResource(R.string.story_content_preview_small),
                stringResource(R.string.story_content_preview_small),
            ),
            ChoiceOption(
                StoryContentPreviewStyle.MEDIUM.name,
                stringResource(R.string.story_content_preview_medium),
                stringResource(R.string.story_content_preview_medium),
            ),
            ChoiceOption(
                StoryContentPreviewStyle.LARGE.name,
                stringResource(R.string.story_content_preview_large),
                stringResource(R.string.story_content_preview_large),
            ),
        )
    val thumbnailOptions =
        listOf(
            ChoiceOption(
                ThumbnailStyle.OFF.name,
                stringResource(R.string.story_thumbnail_no_image_preview),
                stringResource(R.string.settings_preview_images_segment_off),
            ),
            ChoiceOption(
                ThumbnailStyle.LEFT_SMALL.name,
                stringResource(R.string.story_thumbnail_left_hand_small),
                stringResource(R.string.settings_preview_images_segment_left_small),
            ),
            ChoiceOption(
                ThumbnailStyle.LEFT_LARGE.name,
                stringResource(R.string.story_thumbnail_left_hand_large),
                stringResource(R.string.settings_preview_images_segment_left_large),
            ),
            ChoiceOption(
                ThumbnailStyle.RIGHT_SMALL.name,
                stringResource(R.string.story_thumbnail_right_hand_small),
                stringResource(R.string.settings_preview_images_segment_right_small),
            ),
            ChoiceOption(
                ThumbnailStyle.RIGHT_LARGE.name,
                stringResource(R.string.story_thumbnail_right_hand_large),
                stringResource(R.string.settings_preview_images_segment_right_large),
            ),
        )
    val browserOptions =
        listOf(
            ChoiceOption(DefaultBrowser.SYSTEM_DEFAULT.name, "System default"),
            ChoiceOption(DefaultBrowser.IN_APP_BROWSER.name, "In-app browser"),
            ChoiceOption(DefaultBrowser.CHROME.name, "Chrome"),
            ChoiceOption(DefaultBrowser.FIREFOX.name, "Firefox"),
            ChoiceOption(DefaultBrowser.OPERA_MINI.name, "Opera Mini"),
        )
    val fontOptions =
        listOf(
            ChoiceOption("ANONYMOUS_PRO", stringResource(R.string.anonymous_pro_font)),
            ChoiceOption("CHRONICLE", stringResource(R.string.chronicle_font)),
            ChoiceOption("DEFAULT", stringResource(R.string.default_font)),
            ChoiceOption("GOTHAM_NARROW", stringResource(R.string.gotham_narrow_font)),
            ChoiceOption("NOTO_SANS", stringResource(R.string.noto_sans_font)),
            ChoiceOption("NOTO_SERIF", stringResource(R.string.noto_serif_font)),
            ChoiceOption("OPEN_SANS_CONDENSED", stringResource(R.string.open_sans_condensed_font)),
            ChoiceOption("ROBOTO", stringResource(R.string.roboto_font)),
        )
    val volumeKeyOptions =
        listOf(
            ChoiceOption(VolumeKeyNavigation.OFF.name, stringResource(R.string.off), stringResource(R.string.off)),
            ChoiceOption(VolumeKeyNavigation.UP_NEXT.name, stringResource(R.string.volume_up_next), "Up"),
            ChoiceOption(VolumeKeyNavigation.DOWN_NEXT.name, stringResource(R.string.volume_down_next), "Down"),
        )
    val ltrGestureOptions =
        listOf(
            ChoiceOption(GestureAction.GEST_ACTION_BACK.name, stringResource(R.string.gest_action_back)),
            ChoiceOption(GestureAction.GEST_ACTION_TOGGLE_READ.name, stringResource(R.string.gest_action_toggle_read)),
            ChoiceOption(GestureAction.GEST_ACTION_NONE.name, stringResource(R.string.gest_action_none)),
            ChoiceOption(GestureAction.GEST_ACTION_MARKREAD.name, stringResource(R.string.gest_action_markread)),
            ChoiceOption(GestureAction.GEST_ACTION_MARKUNREAD.name, stringResource(R.string.gest_action_markunread)),
            ChoiceOption(GestureAction.GEST_ACTION_SAVE.name, stringResource(R.string.gest_action_save)),
            ChoiceOption(GestureAction.GEST_ACTION_UNSAVE.name, stringResource(R.string.gest_action_unsave)),
            ChoiceOption(GestureAction.GEST_ACTION_STATISTICS.name, stringResource(R.string.gest_action_statistics)),
        )
    val rtlGestureOptions =
        listOf(
            ChoiceOption(GestureAction.GEST_ACTION_TOGGLE_READ.name, stringResource(R.string.gest_action_toggle_read)),
            ChoiceOption(GestureAction.GEST_ACTION_NONE.name, stringResource(R.string.gest_action_none)),
            ChoiceOption(GestureAction.GEST_ACTION_MARKREAD.name, stringResource(R.string.gest_action_markread)),
            ChoiceOption(GestureAction.GEST_ACTION_MARKUNREAD.name, stringResource(R.string.gest_action_markunread)),
            ChoiceOption(GestureAction.GEST_ACTION_SAVE.name, stringResource(R.string.gest_action_save)),
            ChoiceOption(GestureAction.GEST_ACTION_UNSAVE.name, stringResource(R.string.gest_action_unsave)),
            ChoiceOption(GestureAction.GEST_ACTION_STATISTICS.name, stringResource(R.string.gest_action_statistics)),
        )
    val confirmMarkReadTitle = stringResource(R.string.settings_confirm_mark_all_read).stripTrailingEllipsis()
    val markStoryReadTitle = stringResource(R.string.settings_mark_story_read_title)
    val previewImagesTitle = stringResource(R.string.settings_preview_images_title)
    val defaultBrowserTitle = stringResource(R.string.default_browser).stripTrailingEllipsis()
    val fontTitle = stringResource(R.string.font).stripTrailingEllipsis()
    val ltrGestureTitle = stringResource(R.string.settings_ltr_gesture_action).stripTrailingEllipsis()
    val rtlGestureTitle = stringResource(R.string.settings_rtl_gesture_action).stripTrailingEllipsis()
    val networkTitle = stringResource(R.string.menu_network_select).stripTrailingEllipsis()
    val cacheAgeTitle = stringResource(R.string.menu_cache_age_select).stripTrailingEllipsis()

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .background(palette.background)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        SettingsSection(
            title = stringResource(R.string.settings_cat_story_list),
            icon = Icons.Rounded.ListAlt,
            iconColor = NewsblurBlue,
            palette = palette,
        ) {
            SegmentedSettingsRow(
                title = stringResource(R.string.menu_story_order),
                icon = Icons.Rounded.SwapVert,
                iconColor = NewsblurBlue,
                selectedValue = state.defaultStoryOrder,
                options = storyOrderOptions,
                palette = palette,
                onSelected = { onStringChanged(PrefConstants.DEFAULT_STORY_ORDER, it) },
            )
            RowDivider(palette)
            SegmentedSettingsRow(
                title = stringResource(R.string.settings_read_filter_title),
                icon = Icons.Rounded.FilterList,
                iconColor = NewsblurOrange,
                selectedValue = state.defaultReadFilter,
                options = readFilterOptions,
                palette = palette,
                onSelected = { onStringChanged(PrefConstants.DEFAULT_READ_FILTER, it) },
            )
            RowDivider(palette)
            SegmentedSettingsRow(
                title = confirmMarkReadTitle,
                icon = Icons.Rounded.CheckCircle,
                iconColor = NewsblurGreen,
                selectedValue = state.markAllReadConfirmation,
                options = confirmMarkReadOptions,
                palette = palette,
                footer = stringResource(R.string.settings_confirm_mark_all_read_note),
                onSelected = { onStringChanged(PrefConstants.MARK_ALL_READ_CONFIRMATION, it) },
            )
            RowDivider(palette)
            ToggleSettingsRow(
                title = stringResource(R.string.settings_confirm_mark_range_read),
                icon = Icons.Rounded.CheckCircle,
                iconColor = NewsblurGreen,
                checked = state.confirmMarkRangeRead,
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.MARK_RANGE_READ_CONFIRMATION, it) },
            )
            RowDivider(palette)
            SegmentedSettingsRow(
                title = stringResource(R.string.settings_after_mark_read_title),
                icon = Icons.AutoMirrored.Rounded.ArrowForward,
                iconColor = NewsblurTeal,
                selectedValue = if (state.loadNextOnMarkRead) "next" else "stay",
                options = afterMarkReadOptions,
                palette = palette,
                onSelected = { onBooleanChanged(PrefConstants.LOAD_NEXT_ON_MARK_READ, it == "next") },
            )
            RowDivider(palette)
            SegmentedSettingsRow(
                title = stringResource(R.string.settings_when_opening_site_title),
                icon = Icons.Rounded.Article,
                iconColor = NewsblurIndigo,
                selectedValue = if (state.autoOpenFirstUnread) "first_story" else "stories",
                options = siteOpeningOptions,
                palette = palette,
                onSelected = { onBooleanChanged(PrefConstants.STORIES_AUTO_OPEN_FIRST, it == "first_story") },
            )
            RowDivider(palette)
            ValueSettingsRow(
                title = markStoryReadTitle,
                icon = Icons.Rounded.Timer,
                iconColor = NewsblurCyan,
                currentValue = markStoryReadOptions.labelFor(state.markStoryReadBehavior),
                palette = palette,
                onClick = {
                    dialogState =
                        ChoiceDialogState(
                            title = markStoryReadTitle,
                            selectedValue = state.markStoryReadBehavior,
                            options = markStoryReadOptions,
                            onSelect = { onStringChanged(PrefConstants.STORY_MARK_READ_BEHAVIOR, it) },
                        )
                },
            )
            RowDivider(palette)
            ToggleSettingsRow(
                title = stringResource(R.string.settings_mark_read_on_feed_scroll),
                icon = Icons.Rounded.SwapVert,
                iconColor = NewsblurCyan,
                checked = state.markReadOnScroll,
                subtitle = stringResource(R.string.settings_mark_read_on_feed_scroll_sum),
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.STORIES_MARK_READ_ON_SCROLL, it) },
            )
            RowDivider(palette)
            ToggleSettingsRow(
                title = stringResource(R.string.settings_story_clustering),
                icon = Icons.Rounded.Article,
                iconColor = NewsblurIndigo,
                checked = state.storyClustering,
                subtitle = stringResource(R.string.settings_story_clustering_summary),
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.STORY_CLUSTERING, it) },
            )
        }

        SettingsSection(
            title = stringResource(R.string.settings_cat_story_layout),
            icon = Icons.Rounded.Tune,
            iconColor = NewsblurPurple,
            palette = palette,
        ) {
            SegmentedSettingsRow(
                title = stringResource(R.string.settings_content_preview).stripTrailingEllipsis(),
                icon = Icons.Rounded.ShortText,
                iconColor = NewsblurOrange,
                selectedValue = state.storyContentPreviewStyle,
                options = contentPreviewOptions,
                palette = palette,
                onSelected = { onStringChanged(PrefConstants.STORIES_SHOW_PREVIEWS_STYLE, it) },
            )
            RowDivider(palette)
            SegmentedSettingsRow(
                title = previewImagesTitle,
                icon = Icons.Rounded.Photo,
                iconColor = NewsblurGreen,
                selectedValue = state.thumbnailStyle,
                options = thumbnailOptions,
                palette = palette,
                onSelected = { onStringChanged(PrefConstants.STORIES_THUMBNAIL_STYLE, it) },
            )
        }

        SettingsSection(
            title = stringResource(R.string.settings_cat_feed_list),
            icon = Icons.Rounded.SortByAlpha,
            iconColor = NewsblurOrange,
            palette = palette,
        ) {
            SegmentedSettingsRow(
                title = stringResource(R.string.setting_feed_list_order).stripTrailingEllipsis(),
                icon = Icons.Rounded.SortByAlpha,
                iconColor = NewsblurOrange,
                selectedValue = state.feedListOrder,
                options = feedListOrderOptions,
                palette = palette,
                onSelected = { onStringChanged(PrefConstants.FEED_LIST_ORDER, it) },
            )
            RowDivider(palette)
            ToggleSettingsRow(
                title = stringResource(R.string.settings_enable_row_global_shared),
                icon = Icons.Rounded.Public,
                iconColor = NewsblurPurple,
                checked = state.enableRowGlobalShared,
                subtitle = stringResource(R.string.settings_enable_row_global_shared_sum),
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.ENABLE_ROW_GLOBAL_SHARED, it) },
            )
            RowDivider(palette)
            ToggleSettingsRow(
                title = stringResource(R.string.settings_enable_row_infrequent_stories),
                icon = Icons.Rounded.Schedule,
                iconColor = NewsblurTeal,
                checked = state.enableRowInfrequentStories,
                subtitle = stringResource(R.string.settings_enable_row_infrequent_stories_sum),
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.ENABLE_ROW_INFREQUENT_STORIES, it) },
            )
            RowDivider(palette)
            ToggleSettingsRow(
                title = stringResource(R.string.settings_enable_row_daily_briefing),
                icon = Icons.Rounded.AutoAwesome,
                iconColor = NewsblurOrange,
                checked = state.enableRowDailyBriefing,
                subtitle = stringResource(R.string.settings_enable_row_daily_briefing_sum),
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.ENABLE_ROW_DAILY_BRIEFING, it) },
            )
        }

        SettingsSection(
            title = stringResource(R.string.settings_reading),
            icon = Icons.Rounded.MenuBook,
            iconColor = NewsblurBlue,
            palette = palette,
        ) {
            ValueSettingsRow(
                title = defaultBrowserTitle,
                icon = Icons.Rounded.OpenInBrowser,
                iconColor = NewsblurBlue,
                currentValue = browserOptions.labelFor(state.defaultBrowser),
                palette = palette,
                onClick = {
                    dialogState =
                        ChoiceDialogState(
                            title = defaultBrowserTitle,
                            selectedValue = state.defaultBrowser,
                            options = browserOptions,
                            onSelect = { onStringChanged(PrefConstants.DEFAULT_BROWSER, it) },
                        )
                },
            )
            RowDivider(palette)
            ValueSettingsRow(
                title = fontTitle,
                icon = Icons.Rounded.TextFields,
                iconColor = NewsblurPurple,
                currentValue = fontOptions.labelFor(state.readingFont),
                palette = palette,
                onClick = {
                    dialogState =
                        ChoiceDialogState(
                            title = fontTitle,
                            selectedValue = state.readingFont,
                            options = fontOptions,
                            onSelect = { onStringChanged(PrefConstants.READING_FONT, it) },
                        )
                },
            )
            RowDivider(palette)
            SegmentedSettingsRow(
                title = stringResource(R.string.volume_key_navigation).stripTrailingEllipsis(),
                icon = Icons.Rounded.VolumeUp,
                iconColor = NewsblurCyan,
                selectedValue = state.volumeKeyNavigation,
                options = volumeKeyOptions,
                palette = palette,
                onSelected = { onStringChanged(PrefConstants.VOLUME_KEY_NAVIGATION, it) },
            )
            RowDivider(palette)
            ToggleSettingsRow(
                title = stringResource(R.string.settings_show_ask_ai),
                icon = Icons.Rounded.AutoAwesome,
                iconColor = NewsblurOrange,
                checked = state.showAskAi,
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.SHOW_ASK_AI, it) },
            )
        }

        SettingsSection(
            title = stringResource(R.string.settings_social),
            icon = Icons.Rounded.Forum,
            iconColor = NewsblurBlue,
            palette = palette,
        ) {
            ToggleSettingsRow(
                title = stringResource(R.string.settings_show_public_comments),
                icon = Icons.Rounded.Forum,
                iconColor = NewsblurBlue,
                checked = state.showPublicComments,
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.SHOW_PUBLIC_COMMENTS, it) },
            )
        }

        SettingsSection(
            title = stringResource(R.string.settings_gestures),
            icon = Icons.Rounded.Gesture,
            iconColor = NewsblurPurple,
            palette = palette,
        ) {
            ValueSettingsRow(
                title = ltrGestureTitle,
                icon = Icons.Rounded.SwipeRightAlt,
                iconColor = NewsblurOrange,
                currentValue = ltrGestureOptions.labelFor(state.ltrGestureAction),
                palette = palette,
                onClick = {
                    dialogState =
                        ChoiceDialogState(
                            title = ltrGestureTitle,
                            selectedValue = state.ltrGestureAction,
                            options = ltrGestureOptions,
                            onSelect = { onStringChanged(PrefConstants.LTR_GESTURE_ACTION, it) },
                        )
                },
            )
            RowDivider(palette)
            ValueSettingsRow(
                title = rtlGestureTitle,
                icon = Icons.AutoMirrored.Rounded.ArrowForward,
                iconColor = NewsblurPurple,
                currentValue = rtlGestureOptions.labelFor(state.rtlGestureAction),
                palette = palette,
                onClick = {
                    dialogState =
                        ChoiceDialogState(
                            title = rtlGestureTitle,
                            selectedValue = state.rtlGestureAction,
                            options = rtlGestureOptions,
                            onSelect = { onStringChanged(PrefConstants.RTL_GESTURE_ACTION, it) },
                        )
                },
            )
        }

        SettingsSection(
            title = stringResource(R.string.settings_cat_offline),
            icon = Icons.Rounded.Download,
            iconColor = NewsblurBlue,
            palette = palette,
        ) {
            ToggleSettingsRow(
                title = stringResource(R.string.settings_enable_offline),
                icon = Icons.Rounded.Download,
                iconColor = NewsblurBlue,
                checked = state.enableOffline,
                subtitle = stringResource(R.string.settings_enable_offline_sum),
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.ENABLE_OFFLINE, it) },
            )
            RowDivider(palette)
            ToggleSettingsRow(
                title = stringResource(R.string.settings_enable_image_prefetch),
                icon = Icons.Rounded.Image,
                iconColor = NewsblurOrange,
                checked = state.enableImagePrefetch,
                subtitle = stringResource(R.string.settings_enable_image_prefetch_sum),
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.ENABLE_IMAGE_PREFETCH, it) },
            )
            RowDivider(palette)
            ValueSettingsRow(
                title = networkTitle,
                icon = Icons.Rounded.Wifi,
                iconColor = NewsblurTeal,
                currentValue = networkOptions.labelFor(state.networkSelect),
                subtitle = stringResource(R.string.menu_network_select_sum),
                palette = palette,
                onClick = {
                    dialogState =
                        ChoiceDialogState(
                            title = networkTitle,
                            selectedValue = state.networkSelect,
                            options = networkOptions,
                            onSelect = { onStringChanged(PrefConstants.NETWORK_SELECT, it) },
                        )
                },
            )
            RowDivider(palette)
            ToggleSettingsRow(
                title = stringResource(R.string.settings_keep_old_stories),
                icon = Icons.Rounded.Schedule,
                iconColor = NewsblurPurple,
                checked = state.keepOldStories,
                subtitle = stringResource(R.string.settings_keep_old_stories_sum),
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.KEEP_OLD_STORIES, it) },
            )
            RowDivider(palette)
            ValueSettingsRow(
                title = cacheAgeTitle,
                icon = Icons.Rounded.Schedule,
                iconColor = NewsblurIndigo,
                currentValue = cacheAgeOptions.labelFor(state.cacheAgeSelect),
                subtitle = stringResource(R.string.menu_cache_age_select_sum),
                palette = palette,
                onClick = {
                    dialogState =
                        ChoiceDialogState(
                            title = cacheAgeTitle,
                            selectedValue = state.cacheAgeSelect,
                            options = cacheAgeOptions,
                            onSelect = { onStringChanged(PrefConstants.CACHE_AGE_SELECT, it) },
                        )
                },
            )
            RowDivider(palette)
            ActionSettingsRow(
                title = stringResource(R.string.menu_delete_offline_stories).stripTrailingEllipsis(),
                icon = Icons.Rounded.DeleteSweep,
                iconColor = NewsblurRed,
                subtitle = stringResource(R.string.menu_delete_offline_stories_sum),
                palette = palette,
                isDestructive = true,
                onClick = onDeleteOfflineStories,
            )
        }

        SettingsSection(
            title = stringResource(R.string.settings_notifications),
            icon = Icons.Rounded.Notifications,
            iconColor = NewsblurRed,
            palette = palette,
        ) {
            ToggleSettingsRow(
                title = stringResource(R.string.settings_enable_notifications),
                icon = Icons.Rounded.Notifications,
                iconColor = NewsblurRed,
                checked = state.enableNotifications,
                palette = palette,
                onCheckedChange = { onBooleanChanged(PrefConstants.ENABLE_NOTIFICATIONS, it) },
            )
        }
    }

    dialogState?.let { dialog ->
        ChoiceDialog(
            state = dialog,
            palette = palette,
            onDismiss = { dialogState = null },
        )
    }
}

@Composable
private fun SettingsSection(
    title: String,
    icon: ImageVector,
    iconColor: Color,
    palette: SettingsPalette,
    content: @Composable () -> Unit,
) {
    Column {
        Row(
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = iconColor,
                modifier = Modifier.size(15.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = title.uppercase(),
                color = palette.textSecondary,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.8.sp,
            )
        }

        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(18.dp),
            color = palette.cardBackground,
            shadowElevation = if (palette.showShadow) 3.dp else 0.dp,
        ) {
            Column(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .border(
                            width = 1.dp,
                            color = palette.border.copy(alpha = 0.6f),
                            shape = RoundedCornerShape(18.dp),
                        ),
            ) {
                content()
            }
        }
    }
}

@Composable
private fun ValueSettingsRow(
    title: String,
    icon: ImageVector,
    iconColor: Color,
    currentValue: String,
    palette: SettingsPalette,
    subtitle: String? = null,
    footer: String? = null,
    onClick: () -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = onClick,
                ).padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            PreferenceIcon(icon = icon, color = iconColor)
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    color = palette.textPrimary,
                    style = MaterialTheme.typography.bodyLarge,
                )
                subtitle?.let {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = it,
                        color = palette.textSecondary,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
            Spacer(Modifier.width(8.dp))
            Text(
                text = currentValue,
                color = palette.textSecondary,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.End,
                modifier = Modifier.weight(0.6f, fill = false),
            )
            Icon(
                imageVector = Icons.Rounded.KeyboardArrowRight,
                contentDescription = null,
                tint = palette.textSecondary.copy(alpha = 0.55f),
                modifier = Modifier.size(20.dp),
            )
        }
        footer?.let {
            Spacer(Modifier.height(8.dp))
            Text(
                text = it,
                color = palette.textSecondary,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(start = 40.dp, end = 6.dp),
            )
        }
    }
}

@Composable
private fun ToggleSettingsRow(
    title: String,
    icon: ImageVector,
    iconColor: Color,
    checked: Boolean,
    palette: SettingsPalette,
    subtitle: String? = null,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PreferenceIcon(icon = icon, color = iconColor)
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                color = palette.textPrimary,
                style = MaterialTheme.typography.bodyLarge,
            )
            subtitle?.let {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = it,
                    color = palette.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
        Spacer(Modifier.width(12.dp))
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors =
                SwitchDefaults.colors(
                    checkedBorderColor = palette.newsblurGreen,
                    checkedThumbColor = Color.White,
                    checkedTrackColor = palette.newsblurGreen,
                    uncheckedBorderColor = palette.border,
                    uncheckedThumbColor = Color.White,
                    uncheckedTrackColor = palette.secondaryBackground,
                ),
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SegmentedSettingsRow(
    title: String,
    icon: ImageVector,
    iconColor: Color,
    selectedValue: String,
    options: List<ChoiceOption>,
    palette: SettingsPalette,
    subtitle: String? = null,
    footer: String? = null,
    onSelected: (String) -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            PreferenceIcon(icon = icon, color = iconColor)
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    color = palette.textPrimary,
                    style = MaterialTheme.typography.bodyLarge,
                )
                subtitle?.let {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = it,
                        color = palette.textSecondary,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        FlowRow(
            modifier =
                Modifier
                    .padding(start = 40.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(palette.segmentedBackground)
                    .border(1.dp, palette.segmentedBorder, RoundedCornerShape(16.dp))
                    .padding(3.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            options.forEach { option ->
                val isSelected = option.value == selectedValue
                Box(
                    modifier =
                        Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (isSelected) palette.segmentedSelected else Color.Transparent)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                            ) {
                                onSelected(option.value)
                            }.padding(horizontal = 12.dp, vertical = 8.dp)
                            .defaultMinSize(minWidth = 56.dp)
                            .wrapContentHeight(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = option.segmentLabel,
                        color = if (isSelected) palette.segmentedSelectedText else palette.segmentedText,
                        fontSize = 12.sp,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                        textAlign = TextAlign.Center,
                        lineHeight = 14.sp,
                    )
                }
            }
        }
        footer?.let {
            Spacer(Modifier.height(8.dp))
            Text(
                text = it,
                color = palette.textSecondary,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(start = 40.dp, end = 6.dp),
            )
        }
    }
}

@Composable
private fun ActionSettingsRow(
    title: String,
    icon: ImageVector,
    iconColor: Color,
    palette: SettingsPalette,
    subtitle: String? = null,
    isDestructive: Boolean = false,
    onClick: () -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = onClick,
                ).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PreferenceIcon(icon = icon, color = iconColor)
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                color = if (isDestructive) palette.destructive else palette.textPrimary,
                style = MaterialTheme.typography.bodyLarge,
            )
            subtitle?.let {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = it,
                    color = palette.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }
}

@Composable
private fun PreferenceIcon(
    icon: ImageVector,
    color: Color,
) {
    Box(
        modifier =
            Modifier
                .size(28.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(color),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(16.dp),
        )
    }
}

@Composable
private fun RowDivider(palette: SettingsPalette) {
    HorizontalDivider(
        color = palette.border.copy(alpha = 0.55f),
        modifier = Modifier.padding(start = 54.dp, end = 14.dp),
    )
}

@Composable
private fun ChoiceDialog(
    state: ChoiceDialogState,
    palette: SettingsPalette,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = palette.cardBackground,
        titleContentColor = palette.textPrimary,
        textContentColor = palette.textPrimary,
        title = {
            Text(
                text = state.title,
                color = palette.textPrimary,
                style = MaterialTheme.typography.titleMedium,
            )
        },
        text = {
            Column(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(max = 420.dp)
                        .verticalScroll(rememberScrollState()),
            ) {
                state.options.forEach { option ->
                    Row(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .clickable {
                                    state.onSelect(option.value)
                                    onDismiss()
                                }.padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(
                            selected = option.value == state.selectedValue,
                            onClick = {
                                state.onSelect(option.value)
                                onDismiss()
                            },
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = option.label,
                            color = palette.textPrimary,
                            style = MaterialTheme.typography.bodyLarge,
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.alert_dialog_done), color = palette.newsblurGreen)
            }
        },
    )
}

private data class ChoiceDialogState(
    val title: String,
    val selectedValue: String,
    val options: List<ChoiceOption>,
    val onSelect: (String) -> Unit,
)

private data class ChoiceOption(
    val value: String,
    val label: String,
    val segmentLabel: String = label,
)

private fun List<ChoiceOption>.labelFor(value: String): String = firstOrNull { it.value == value }?.label ?: ""

private fun String.stripTrailingEllipsis(): String = removeSuffix("…")

@Immutable
private data class SettingsPalette(
    val background: Color,
    val cardBackground: Color,
    val secondaryBackground: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val border: Color,
    val segmentedBackground: Color,
    val segmentedSelected: Color,
    val segmentedText: Color,
    val segmentedSelectedText: Color,
    val segmentedBorder: Color,
    val newsblurGreen: Color,
    val destructive: Color,
    val showShadow: Boolean,
)

@Composable
private fun settingsPalette(theme: ThemeValue): SettingsPalette {
    val resolvedTheme =
        when (theme) {
            ThemeValue.AUTO -> if (isSystemInDarkTheme()) ThemeValue.DARK else ThemeValue.LIGHT
            else -> theme
        }

    return when (resolvedTheme) {
        ThemeValue.SEPIA ->
            SettingsPalette(
                background = Color(0xFFF3E2CB),
                cardBackground = Color(0xFFFAF5ED),
                secondaryBackground = Color(0xFFFAF5ED),
                textPrimary = Color(0xFF3C3226),
                textSecondary = Color(0xFF8B7B6B),
                border = Color(0xFFD4C8B8),
                segmentedBackground = Color(0xFFE8DED0),
                segmentedSelected = Color(0xFFFAF5ED),
                segmentedText = Color(0xFF8B7B6B),
                segmentedSelectedText = Color(0xFF3C3226),
                segmentedBorder = Color(0xFFC8B8A8),
                newsblurGreen = Color(0xFF709E5D),
                destructive = Color(0xFFE35A4F),
                showShadow = true,
            )

        ThemeValue.DARK ->
            SettingsPalette(
                background = Color(0xFF2C2C2E),
                cardBackground = Color(0xFF3A3A3C),
                secondaryBackground = Color(0xFF48484A),
                textPrimary = Color(0xFFF2F2F7),
                textSecondary = Color(0xFFAEAEB2),
                border = Color(0xFF545458),
                segmentedBackground = Color(0xFF707070),
                segmentedSelected = Color(0xFFBBBBBB),
                segmentedText = Color(0xFFCCCCCC),
                segmentedSelectedText = Color(0xFFFFFFFF),
                segmentedBorder = Color(0xFF555555),
                newsblurGreen = Color(0xFF709E5D),
                destructive = Color(0xFFFF867C),
                showShadow = false,
            )

        ThemeValue.BLACK ->
            SettingsPalette(
                background = Color(0xFF000000),
                cardBackground = Color(0xFF121214),
                secondaryBackground = Color(0xFF1C1C1E),
                textPrimary = Color(0xFFF2F2F7),
                textSecondary = Color(0xFF98989D),
                border = Color(0xFF303030),
                segmentedBackground = Color(0xFF303030),
                segmentedSelected = Color(0xFF888890),
                segmentedText = Color(0xFFAAAAAA),
                segmentedSelectedText = Color(0xFFFFFFFF),
                segmentedBorder = Color(0xFF444444),
                newsblurGreen = Color(0xFF709E5D),
                destructive = Color(0xFFFF867C),
                showShadow = false,
            )

        else ->
            SettingsPalette(
                background = Color(0xFFF0F2ED),
                cardBackground = Color(0xFFFFFFFF),
                secondaryBackground = Color(0xFFF7F7F5),
                textPrimary = Color(0xFF1C1C1E),
                textSecondary = Color(0xFF6E6E73),
                border = Color(0xFFD1D1D6),
                segmentedBackground = Color(0xFFE7E6E7),
                segmentedSelected = Color(0xFFDCE6F0),
                segmentedText = Color(0xFF909090),
                segmentedSelectedText = Color(0xFF000000),
                segmentedBorder = Color(0xFFC0C0C0),
                newsblurGreen = Color(0xFF709E5D),
                destructive = Color(0xFFE35A4F),
                showShadow = true,
            )
    }
}

private val NewsblurBlue = Color(0xFF0A84FF)
private val NewsblurOrange = Color(0xFFFF9500)
private val NewsblurPurple = Color(0xFFBF5AF2)
private val NewsblurGreen = Color(0xFF34C759)
private val NewsblurTeal = Color(0xFF30B0C7)
private val NewsblurIndigo = Color(0xFF5E5CE6)
private val NewsblurCyan = Color(0xFF32ADE6)
private val NewsblurRed = Color(0xFFFF453A)
