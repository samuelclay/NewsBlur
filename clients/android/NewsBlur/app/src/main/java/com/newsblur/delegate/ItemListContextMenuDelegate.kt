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
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.FeedUtils.Companion.triggerSync
import com.newsblur.util.ListTextSize
import com.newsblur.util.ListTextSize.Companion.fromSize
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.ReadFilter
import com.newsblur.util.ReadingActionListener
import com.newsblur.util.SpacingStyle
import com.newsblur.util.StoryContentPreviewStyle
import com.newsblur.util.StoryListStyle
import com.newsblur.util.StoryOrder
import com.newsblur.util.ThumbnailStyle
import com.newsblur.util.UIUtils

interface ItemListContextMenuDelegate {
    fun onCreateMenuOptions(menu: Menu, menuInflater: MenuInflater, fs: FeedSet): Boolean

    fun onPrepareMenuOptions(menu: Menu, fs: FeedSet, showSavedSearch: Boolean): Boolean

    fun onOptionsItemSelected(item: MenuItem, fragment: ItemSetFragment, fs: FeedSet, searchInputView: EditText, saveSearchFeedId: String?): Boolean
}

open class ItemListContextMenuDelegateImpl(
        private val activity: ItemsList,
        private val feedUtils: FeedUtils,
        private val prefsRepo: PrefsRepo,
        private val syncServiceState: SyncServiceState,
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
        val storyOrder = prefsRepo.getStoryOrder(fs)
        if (storyOrder == StoryOrder.NEWEST) {
            menu.findItem(R.id.menu_story_order_newest).isChecked = true
        } else if (storyOrder == StoryOrder.OLDEST) {
            menu.findItem(R.id.menu_story_order_oldest).isChecked = true
        }

        val readFilter = prefsRepo.getReadFilter(fs)
        if (readFilter == ReadFilter.ALL) {
            menu.findItem(R.id.menu_read_filter_all_stories).isChecked = true
        } else if (readFilter == ReadFilter.UNREAD) {
            menu.findItem(R.id.menu_read_filter_unread_only).isChecked = true
        }

        when (prefsRepo.getStoryListStyle(fs)) {
            StoryListStyle.GRID_F -> menu.findItem(R.id.menu_list_style_grid_f).isChecked = true
            StoryListStyle.GRID_M -> menu.findItem(R.id.menu_list_style_grid_m).isChecked = true
            StoryListStyle.GRID_C -> menu.findItem(R.id.menu_list_style_grid_c).isChecked = true
            else -> menu.findItem(R.id.menu_list_style_list).isChecked = true
        }

        when (prefsRepo.getSelectedTheme()) {
            ThemeValue.LIGHT -> menu.findItem(R.id.menu_theme_light).isChecked = true
            ThemeValue.DARK -> menu.findItem(R.id.menu_theme_dark).isChecked = true
            ThemeValue.BLACK -> menu.findItem(R.id.menu_theme_black).isChecked = true
            ThemeValue.AUTO -> menu.findItem(R.id.menu_theme_auto).isChecked = true
        }

        if (showSavedSearch) {
            menu.findItem(R.id.menu_save_search).isVisible = true
        }

        when (prefsRepo.getStoryContentPreviewStyle()) {
            StoryContentPreviewStyle.NONE -> menu.findItem(R.id.menu_story_content_preview_none).isChecked = true
            StoryContentPreviewStyle.SMALL -> menu.findItem(R.id.menu_story_content_preview_small).isChecked = true
            StoryContentPreviewStyle.MEDIUM -> menu.findItem(R.id.menu_story_content_preview_medium).isChecked = true
            StoryContentPreviewStyle.LARGE -> menu.findItem(R.id.menu_story_content_preview_large).isChecked = true
        }

        when (prefsRepo.getThumbnailStyle()) {
            ThumbnailStyle.LEFT_SMALL -> menu.findItem(R.id.menu_story_thumbnail_left_small).isChecked = true
            ThumbnailStyle.LEFT_LARGE -> menu.findItem(R.id.menu_story_thumbnail_left_large).isChecked = true
            ThumbnailStyle.RIGHT_SMALL -> menu.findItem(R.id.menu_story_thumbnail_right_small).isChecked = true
            ThumbnailStyle.RIGHT_LARGE -> menu.findItem(R.id.menu_story_thumbnail_right_large).isChecked = true
            ThumbnailStyle.OFF -> menu.findItem(R.id.menu_story_thumbnail_no_preview).isChecked = true
        }

        val spacingStyle = prefsRepo.getSpacingStyle()
        if (spacingStyle === SpacingStyle.COMFORTABLE) {
            menu.findItem(R.id.menu_spacing_comfortable).isChecked = true
        } else if (spacingStyle == SpacingStyle.COMPACT) {
            menu.findItem(R.id.menu_spacing_compact).isChecked = true
        }

        when (fromSize(prefsRepo.getListTextSize())) {
            ListTextSize.XS -> menu.findItem(R.id.menu_text_size_xs).isChecked = true
            ListTextSize.S -> menu.findItem(R.id.menu_text_size_s).isChecked = true
            ListTextSize.M -> menu.findItem(R.id.menu_text_size_m).isChecked = true
            ListTextSize.L -> menu.findItem(R.id.menu_text_size_l).isChecked = true
            ListTextSize.XL -> menu.findItem(R.id.menu_text_size_xl).isChecked = true
            ListTextSize.XXL -> menu.findItem(R.id.menu_text_size_xxl).isChecked = true
        }

        val isMarkReadOnScroll = prefsRepo.isMarkReadOnFeedScroll()
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
            prefsRepo.setSelectedTheme(ThemeValue.AUTO)
            UIUtils.restartActivity(activity)
        } else if (item.itemId == R.id.menu_theme_light) {
            prefsRepo.setSelectedTheme(ThemeValue.LIGHT)
            UIUtils.restartActivity(activity)
        } else if (item.itemId == R.id.menu_theme_dark) {
            prefsRepo.setSelectedTheme(ThemeValue.DARK)
            UIUtils.restartActivity(activity)
        } else if (item.itemId == R.id.menu_theme_black) {
            prefsRepo.setSelectedTheme(ThemeValue.BLACK)
            UIUtils.restartActivity(activity)
        } else if (item.itemId == R.id.menu_spacing_comfortable) {
            updateSpacingStyle(fragment, SpacingStyle.COMFORTABLE)
        } else if (item.itemId == R.id.menu_spacing_compact) {
            updateSpacingStyle(fragment, SpacingStyle.COMPACT)
        } else if (item.itemId == R.id.menu_list_style_list) {
            prefsRepo.updateStoryListStyle(fs, StoryListStyle.LIST)
            fragment.updateListStyle()
        } else if (item.itemId == R.id.menu_list_style_grid_f) {
            prefsRepo.updateStoryListStyle(fs, StoryListStyle.GRID_F)
            fragment.updateListStyle()
        } else if (item.itemId == R.id.menu_list_style_grid_m) {
            prefsRepo.updateStoryListStyle(fs, StoryListStyle.GRID_M)
            fragment.updateListStyle()
        } else if (item.itemId == R.id.menu_list_style_grid_c) {
            prefsRepo.updateStoryListStyle(fs, StoryListStyle.GRID_C)
            fragment.updateListStyle()
        } else if (item.itemId == R.id.menu_save_search) {
            saveSearchFeedId?.let {
                val query: String = searchInputView.text.toString()
                val frag = SaveSearchFragment.newInstance(it, query)
                frag.show(activity.supportFragmentManager, SaveSearchFragment::class.java.name)
            }
        } else if (item.itemId == R.id.menu_story_content_preview_none) {
            prefsRepo.setStoryContentPreviewStyle(StoryContentPreviewStyle.NONE)
            fragment.notifyContentPrefsChanged()
        } else if (item.itemId == R.id.menu_story_content_preview_small) {
            prefsRepo.setStoryContentPreviewStyle(StoryContentPreviewStyle.SMALL)
            fragment.notifyContentPrefsChanged()
        } else if (item.itemId == R.id.menu_story_content_preview_medium) {
            prefsRepo.setStoryContentPreviewStyle(StoryContentPreviewStyle.MEDIUM)
            fragment.notifyContentPrefsChanged()
        } else if (item.itemId == R.id.menu_story_content_preview_large) {
            prefsRepo.setStoryContentPreviewStyle(StoryContentPreviewStyle.LARGE)
            fragment.notifyContentPrefsChanged()
        } else if (item.itemId == R.id.menu_mark_read_on_scroll_disabled) {
            prefsRepo.setMarkReadOnScroll(false)
        } else if (item.itemId == R.id.menu_mark_read_on_scroll_enabled) {
            prefsRepo.setMarkReadOnScroll(true)
        } else if (item.itemId == R.id.menu_story_thumbnail_left_small) {
            prefsRepo.setThumbnailStyle(ThumbnailStyle.LEFT_SMALL)
            fragment.updateThumbnailStyle()
        } else if (item.itemId == R.id.menu_story_thumbnail_left_large) {
            prefsRepo.setThumbnailStyle(ThumbnailStyle.LEFT_LARGE)
            fragment.updateThumbnailStyle()
        } else if (item.itemId == R.id.menu_story_thumbnail_right_small) {
            prefsRepo.setThumbnailStyle(ThumbnailStyle.RIGHT_SMALL)
            fragment.updateThumbnailStyle()
        } else if (item.itemId == R.id.menu_story_thumbnail_right_large) {
            prefsRepo.setThumbnailStyle(ThumbnailStyle.RIGHT_LARGE)
            fragment.updateThumbnailStyle()
        } else if (item.itemId == R.id.menu_story_thumbnail_no_preview) {
            prefsRepo.setThumbnailStyle(ThumbnailStyle.OFF)
            fragment.updateThumbnailStyle()
        }

        return false
    }

    private fun updateTextSizeStyle(fragment: ItemSetFragment, listTextSize: ListTextSize) {
        prefsRepo.setListTextSize(listTextSize.size)
        fragment.updateTextSize()
    }

    private fun updateSpacingStyle(fragment: ItemSetFragment, spacingStyle: SpacingStyle) {
        prefsRepo.setSpacingStyle(spacingStyle)
        fragment.updateSpacingStyle()
    }

    private fun updateStoryOrder(fragment: ItemSetFragment, fs: FeedSet, storyOrder: StoryOrder) {
        prefsRepo.updateStoryOrder(fs, storyOrder)
        restartReadingSession(fragment, fs)
    }

    private fun updateReadFilter(fragment: ItemSetFragment, fs: FeedSet, readFilter: ReadFilter) {
        prefsRepo.updateReadFilter(fs, readFilter)
        restartReadingSession(fragment, fs)
    }

    private fun restartReadingSession(fragment: ItemSetFragment, fs: FeedSet) {
        syncServiceState.resetFetchState(fs)
        feedUtils.prepareReadingSession(fs, true)
        triggerSync(activity)
        fragment.resetEmptyState()
        fragment.hasUpdated()
        fragment.scrollToTop()
    }
}