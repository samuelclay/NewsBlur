package com.newsblur.delegate

import android.view.Menu
import android.view.MenuInflater
import android.view.MenuItem
import android.view.View
import android.widget.EditText
import androidx.core.view.isVisible
import com.newsblur.R
import com.newsblur.activity.ItemsList
import com.newsblur.fragment.ItemSetFragment
import com.newsblur.fragment.SaveSearchFragment
import com.newsblur.service.NBSyncService
import com.newsblur.util.*
import com.newsblur.util.FeedUtils.Companion.triggerSync
import com.newsblur.util.ListTextSize.Companion.fromSize
import com.newsblur.util.PrefConstants.ThemeValue

interface ItemListContextMenuDelegate {
    fun onCreateMenuOptions(menu: Menu, menuInflater: MenuInflater, fs: FeedSet): Boolean

    fun onPrepareMenuOptions(menu: Menu, fs: FeedSet, showSavedSearch: Boolean): Boolean

    fun onOptionsItemSelected(item: MenuItem, fragment: ItemSetFragment, fs: FeedSet, searchInputView: EditText, saveSearchFeedId: String?): Boolean
}

open class ItemListContextMenuDelegateImpl(
        private val activity: ItemsList,
        private val feedUtils: FeedUtils,
) : ItemListContextMenuDelegate, ReadingActionListener by activity {

    override fun onCreateMenuOptions(menu: Menu, menuInflater: MenuInflater, fs: FeedSet): Boolean {
        menuInflater.inflate(R.menu.itemslist, menu)

        if (fs.isGlobalShared ||
                fs.isAllSocial ||
                fs.isFilterSaved ||
                fs.isAllSaved ||
                fs.isSingleSavedTag ||
                fs.isInfrequent ||
                fs.isAllRead) {
            menu.findItem(R.id.menu_mark_all_as_read).isVisible = false
        }

        if (fs.isGlobalShared ||
                fs.isAllSocial ||
                fs.isAllRead) {
            menu.findItem(R.id.menu_story_order).isVisible = false
        }

        if (fs.isGlobalShared ||
                fs.isFilterSaved ||
                fs.isAllSaved ||
                fs.isSingleSavedTag ||
                fs.isInfrequent ||
                fs.isAllRead) {
            menu.findItem(R.id.menu_read_filter).isVisible = false
            menu.findItem(R.id.menu_mark_read_on_scroll).isVisible = false
            menu.findItem(R.id.menu_story_content_preview_style).isVisible = false
            menu.findItem(R.id.menu_story_thumbnail_style).isVisible = false
        }

        if (fs.isGlobalShared ||
                fs.isAllSocial ||
                fs.isInfrequent ||
                fs.isAllRead) {
            menu.findItem(R.id.menu_search_stories).isVisible = false
        }

        if (!fs.isSingleNormal || fs.isFilterSaved) {
            menu.findItem(R.id.menu_notifications).isVisible = false
            menu.findItem(R.id.menu_delete_feed).isVisible = false
            menu.findItem(R.id.menu_instafetch_feed).isVisible = false
            menu.findItem(R.id.menu_intel).isVisible = false
            menu.findItem(R.id.menu_rename_feed).isVisible = false
            menu.findItem(R.id.menu_statistics).isVisible = false
        }

        if (!fs.isInfrequent) {
            menu.findItem(R.id.menu_infrequent_cutoff).isVisible = false
        }

        return true
    }

    override fun onPrepareMenuOptions(menu: Menu, fs: FeedSet, showSavedSearch: Boolean): Boolean {
        val storyOrder = PrefsUtils.getStoryOrder(activity, fs)
        if (storyOrder == StoryOrder.NEWEST) {
            menu.findItem(R.id.menu_story_order_newest).isChecked = true
        } else if (storyOrder == StoryOrder.OLDEST) {
            menu.findItem(R.id.menu_story_order_oldest).isChecked = true
        }

        val readFilter = PrefsUtils.getReadFilter(activity, fs)
        if (readFilter == ReadFilter.ALL) {
            menu.findItem(R.id.menu_read_filter_all_stories).isChecked = true
        } else if (readFilter == ReadFilter.UNREAD) {
            menu.findItem(R.id.menu_read_filter_unread_only).isChecked = true
        }

        when (PrefsUtils.getStoryListStyle(activity, fs)) {
            StoryListStyle.GRID_F -> menu.findItem(R.id.menu_list_style_grid_f).isChecked = true
            StoryListStyle.GRID_M -> menu.findItem(R.id.menu_list_style_grid_m).isChecked = true
            StoryListStyle.GRID_C -> menu.findItem(R.id.menu_list_style_grid_c).isChecked = true
            else -> menu.findItem(R.id.menu_list_style_list).isChecked = true
        }

        when (PrefsUtils.getSelectedTheme(activity)) {
            ThemeValue.LIGHT -> menu.findItem(R.id.menu_theme_light).isChecked = true
            ThemeValue.DARK -> menu.findItem(R.id.menu_theme_dark).isChecked = true
            ThemeValue.BLACK -> menu.findItem(R.id.menu_theme_black).isChecked = true
            ThemeValue.AUTO -> menu.findItem(R.id.menu_theme_auto).isChecked = true
            else -> Unit
        }

        if (showSavedSearch) {
            menu.findItem(R.id.menu_save_search).isVisible = true
        }

        when (PrefsUtils.getStoryContentPreviewStyle(activity)) {
            StoryContentPreviewStyle.NONE -> menu.findItem(R.id.menu_story_content_preview_none).isChecked = true
            StoryContentPreviewStyle.SMALL -> menu.findItem(R.id.menu_story_content_preview_small).isChecked = true
            StoryContentPreviewStyle.MEDIUM -> menu.findItem(R.id.menu_story_content_preview_medium).isChecked = true
            StoryContentPreviewStyle.LARGE -> menu.findItem(R.id.menu_story_content_preview_large).isChecked = true
            else -> Unit
        }

        when (PrefsUtils.getThumbnailStyle(activity)) {
            ThumbnailStyle.LEFT_SMALL -> menu.findItem(R.id.menu_story_thumbnail_left_small).isChecked = true
            ThumbnailStyle.LEFT_LARGE -> menu.findItem(R.id.menu_story_thumbnail_left_large).isChecked = true
            ThumbnailStyle.RIGHT_SMALL -> menu.findItem(R.id.menu_story_thumbnail_right_small).isChecked = true
            ThumbnailStyle.RIGHT_LARGE -> menu.findItem(R.id.menu_story_thumbnail_right_large).isChecked = true
            ThumbnailStyle.OFF -> menu.findItem(R.id.menu_story_thumbnail_no_preview).isChecked = true
            else -> Unit
        }

        val spacingStyle = PrefsUtils.getSpacingStyle(activity)
        if (spacingStyle === SpacingStyle.COMFORTABLE) {
            menu.findItem(R.id.menu_spacing_comfortable).isChecked = true
        } else if (spacingStyle == SpacingStyle.COMPACT) {
            menu.findItem(R.id.menu_spacing_compact).isChecked = true
        }

        when (fromSize(PrefsUtils.getListTextSize(activity))) {
            ListTextSize.XS -> menu.findItem(R.id.menu_text_size_xs).isChecked = true
            ListTextSize.S -> menu.findItem(R.id.menu_text_size_s).isChecked = true
            ListTextSize.M -> menu.findItem(R.id.menu_text_size_m).isChecked = true
            ListTextSize.L -> menu.findItem(R.id.menu_text_size_l).isChecked = true
            ListTextSize.XL -> menu.findItem(R.id.menu_text_size_xl).isChecked = true
            ListTextSize.XXL -> menu.findItem(R.id.menu_text_size_xxl).isChecked = true
        }

        val isMarkReadOnScroll = PrefsUtils.isMarkReadOnFeedScroll(activity)
        if (isMarkReadOnScroll) {
            menu.findItem(R.id.menu_mark_read_on_scroll_enabled).isChecked = true
        } else {
            menu.findItem(R.id.menu_mark_read_on_scroll_disabled).isChecked = true
        }

        return true
    }

    override fun onOptionsItemSelected(
            item: MenuItem,
            fragment: ItemSetFragment,
            fs: FeedSet,
            searchInputView: EditText,
            saveSearchFeedId: String?,
    ): Boolean {
        if (item.itemId == android.R.id.home) {
            activity.finish()
            return true
        } else if (item.itemId == R.id.menu_mark_all_as_read) {
            feedUtils.markRead(activity, fs, null, null, R.array.mark_all_read_options, this)
            return true
        } else if (item.itemId == R.id.menu_story_order_newest) {
            updateStoryOrder(fragment, fs, StoryOrder.NEWEST)
            return true
        } else if (item.itemId == R.id.menu_story_order_oldest) {
            updateStoryOrder(fragment, fs, StoryOrder.OLDEST)
            return true
        } else if (item.itemId == R.id.menu_read_filter_all_stories) {
            updateReadFilter(fragment, fs, ReadFilter.ALL)
            return true
        } else if (item.itemId == R.id.menu_read_filter_unread_only) {
            updateReadFilter(fragment, fs, ReadFilter.UNREAD)
            return true
        } else if (item.itemId == R.id.menu_text_size_xs) {
            updateTextSizeStyle(fragment, ListTextSize.XS)
            return true
        } else if (item.itemId == R.id.menu_text_size_s) {
            updateTextSizeStyle(fragment, ListTextSize.S)
            return true
        } else if (item.itemId == R.id.menu_text_size_m) {
            updateTextSizeStyle(fragment, ListTextSize.M)
            return true
        } else if (item.itemId == R.id.menu_text_size_l) {
            updateTextSizeStyle(fragment, ListTextSize.L)
            return true
        } else if (item.itemId == R.id.menu_text_size_xl) {
            updateTextSizeStyle(fragment, ListTextSize.XL)
            return true
        } else if (item.itemId == R.id.menu_text_size_xxl) {
            updateTextSizeStyle(fragment, ListTextSize.XXL)
            return true
        } else if (item.itemId == R.id.menu_search_stories) {
            if (!searchInputView.isVisible) {
                searchInputView.visibility = View.VISIBLE
                searchInputView.requestFocus()
            } else {
                searchInputView.text.clear()
                searchInputView.visibility = View.GONE
            }
        } else if (item.itemId == R.id.menu_theme_auto) {
            PrefsUtils.setSelectedTheme(activity, ThemeValue.AUTO)
            UIUtils.restartActivity(activity)
        } else if (item.itemId == R.id.menu_theme_light) {
            PrefsUtils.setSelectedTheme(activity, ThemeValue.LIGHT)
            UIUtils.restartActivity(activity)
        } else if (item.itemId == R.id.menu_theme_dark) {
            PrefsUtils.setSelectedTheme(activity, ThemeValue.DARK)
            UIUtils.restartActivity(activity)
        } else if (item.itemId == R.id.menu_theme_black) {
            PrefsUtils.setSelectedTheme(activity, ThemeValue.BLACK)
            UIUtils.restartActivity(activity)
        } else if (item.itemId == R.id.menu_spacing_comfortable) {
            updateSpacingStyle(fragment, SpacingStyle.COMFORTABLE)
        } else if (item.itemId == R.id.menu_spacing_compact) {
            updateSpacingStyle(fragment, SpacingStyle.COMPACT)
        } else if (item.itemId == R.id.menu_list_style_list) {
            PrefsUtils.updateStoryListStyle(activity, fs, StoryListStyle.LIST)
            fragment.updateListStyle()
        } else if (item.itemId == R.id.menu_list_style_grid_f) {
            PrefsUtils.updateStoryListStyle(activity, fs, StoryListStyle.GRID_F)
            fragment.updateListStyle()
        } else if (item.itemId == R.id.menu_list_style_grid_m) {
            PrefsUtils.updateStoryListStyle(activity, fs, StoryListStyle.GRID_M)
            fragment.updateListStyle()
        } else if (item.itemId == R.id.menu_list_style_grid_c) {
            PrefsUtils.updateStoryListStyle(activity, fs, StoryListStyle.GRID_C)
            fragment.updateListStyle()
        } else if (item.itemId == R.id.menu_save_search) {
            saveSearchFeedId?.let {
                val query: String = searchInputView.text.toString()
                val frag = SaveSearchFragment.newInstance(it, query)
                frag.show(activity.supportFragmentManager, SaveSearchFragment::class.java.name)
            }
        } else if (item.itemId == R.id.menu_story_content_preview_none) {
            PrefsUtils.setStoryContentPreviewStyle(activity, StoryContentPreviewStyle.NONE)
            fragment.notifyContentPrefsChanged()
        } else if (item.itemId == R.id.menu_story_content_preview_small) {
            PrefsUtils.setStoryContentPreviewStyle(activity, StoryContentPreviewStyle.SMALL)
            fragment.notifyContentPrefsChanged()
        } else if (item.itemId == R.id.menu_story_content_preview_medium) {
            PrefsUtils.setStoryContentPreviewStyle(activity, StoryContentPreviewStyle.MEDIUM)
            fragment.notifyContentPrefsChanged()
        } else if (item.itemId == R.id.menu_story_content_preview_large) {
            PrefsUtils.setStoryContentPreviewStyle(activity, StoryContentPreviewStyle.LARGE)
            fragment.notifyContentPrefsChanged()
        } else if (item.itemId == R.id.menu_mark_read_on_scroll_disabled) {
            PrefsUtils.setMarkReadOnScroll(activity, false)
        } else if (item.itemId == R.id.menu_mark_read_on_scroll_enabled) {
            PrefsUtils.setMarkReadOnScroll(activity, true)
        } else if (item.itemId == R.id.menu_story_thumbnail_left_small) {
            PrefsUtils.setThumbnailStyle(activity, ThumbnailStyle.LEFT_SMALL)
            fragment.updateThumbnailStyle()
        } else if (item.itemId == R.id.menu_story_thumbnail_left_large) {
            PrefsUtils.setThumbnailStyle(activity, ThumbnailStyle.LEFT_LARGE)
            fragment.updateThumbnailStyle()
        } else if (item.itemId == R.id.menu_story_thumbnail_right_small) {
            PrefsUtils.setThumbnailStyle(activity, ThumbnailStyle.RIGHT_SMALL)
            fragment.updateThumbnailStyle()
        } else if (item.itemId == R.id.menu_story_thumbnail_right_large) {
            PrefsUtils.setThumbnailStyle(activity, ThumbnailStyle.RIGHT_LARGE)
            fragment.updateThumbnailStyle()
        } else if (item.itemId == R.id.menu_story_thumbnail_no_preview) {
            PrefsUtils.setThumbnailStyle(activity, ThumbnailStyle.OFF)
            fragment.updateThumbnailStyle()
        }

        return false
    }

    private fun updateTextSizeStyle(fragment: ItemSetFragment, listTextSize: ListTextSize) {
        PrefsUtils.setListTextSize(activity, listTextSize.size)
        fragment.updateTextSize()
    }

    private fun updateSpacingStyle(fragment: ItemSetFragment, spacingStyle: SpacingStyle) {
        PrefsUtils.setSpacingStyle(activity, spacingStyle)
        fragment.updateSpacingStyle()
    }

    private fun updateStoryOrder(fragment: ItemSetFragment, fs: FeedSet, storyOrder: StoryOrder) {
        PrefsUtils.updateStoryOrder(activity, fs, storyOrder)
        restartReadingSession(fragment, fs)
    }

    private fun updateReadFilter(fragment: ItemSetFragment, fs: FeedSet, readFilter: ReadFilter) {
        PrefsUtils.updateReadFilter(activity, fs, readFilter)
        restartReadingSession(fragment, fs)
    }

    private fun restartReadingSession(fragment: ItemSetFragment, fs: FeedSet) {
        NBSyncService.resetFetchState(fs)
        feedUtils.prepareReadingSession(fs, true)
        triggerSync(activity)
        fragment.resetEmptyState()
        fragment.hasUpdated()
        fragment.scrollToTop()
    }
}