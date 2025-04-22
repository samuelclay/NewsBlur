package com.newsblur.activity

import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.newsblur.R
import com.newsblur.domain.Feed
import com.newsblur.domain.Folder
import com.newsblur.util.FeedOrderFilter
import com.newsblur.util.FolderViewFilter
import com.newsblur.util.ListOrderFilter
import com.newsblur.util.PrefsUtils
import com.newsblur.util.WidgetBackground
import com.newsblur.viewModel.FeedFolderData
import com.newsblur.viewModel.FeedFolderViewModel
import com.newsblur.widget.WidgetUtils.updateWidget
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

abstract class FeedChooser : NbActivity() {

    private lateinit var feedFolderViewModel: FeedFolderViewModel
    protected lateinit var adapter: FeedChooserAdapter

    protected val feeds = ArrayList<Feed>()
    protected val folders = ArrayList<Folder>()
    protected val folderNames = ArrayList<String>()
    protected val folderChildren = ArrayList<ArrayList<Feed>>()

    abstract fun bindLayout()

    abstract fun setupList()

    abstract fun processData(data: FeedFolderData)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        feedFolderViewModel = ViewModelProvider(this)[FeedFolderViewModel::class.java]
        bindLayout()
        setupList()
        setupObservers()
        loadData()
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        val inflater = menuInflater
        inflater.inflate(R.menu.menu_feed_chooser, menu)
        return true
    }

    override fun onPrepareOptionsMenu(menu: Menu): Boolean {
        super.onPrepareOptionsMenu(menu)
        val listOrderFilter = PrefsUtils.getFeedChooserListOrder(this)
        if (listOrderFilter == ListOrderFilter.ASCENDING) {
            menu.findItem(R.id.menu_sort_order_ascending).setChecked(true)
        } else if (listOrderFilter == ListOrderFilter.DESCENDING) {
            menu.findItem(R.id.menu_sort_order_descending).setChecked(true)
        }

        val feedOrderFilter = PrefsUtils.getFeedChooserFeedOrder(this)
        if (feedOrderFilter == FeedOrderFilter.NAME) {
            menu.findItem(R.id.menu_sort_by_name).setChecked(true)
        } else if (feedOrderFilter == FeedOrderFilter.SUBSCRIBERS) {
            menu.findItem(R.id.menu_sort_by_subs).setChecked(true)
        } else if (feedOrderFilter == FeedOrderFilter.STORIES_MONTH) {
            menu.findItem(R.id.menu_sort_by_stories_month).setChecked(true)
        } else if (feedOrderFilter == FeedOrderFilter.RECENT_STORY) {
            menu.findItem(R.id.menu_sort_by_recent_story).setChecked(true)
        } else if (feedOrderFilter == FeedOrderFilter.OPENS) {
            menu.findItem(R.id.menu_sort_by_number_opens).setChecked(true)
        }

        val folderViewFilter = PrefsUtils.getFeedChooserFolderView(this)
        if (folderViewFilter == FolderViewFilter.NESTED) {
            menu.findItem(R.id.menu_folder_view_nested).setChecked(true)
        } else if (folderViewFilter == FolderViewFilter.FLAT) {
            menu.findItem(R.id.menu_folder_view_flat).setChecked(true)
        }

        val widgetBackground = PrefsUtils.getWidgetBackground(this)
        if (widgetBackground == WidgetBackground.DEFAULT) {
            menu.findItem(R.id.menu_widget_background_default).setChecked(true)
        } else if (widgetBackground == WidgetBackground.TRANSPARENT) {
            menu.findItem(R.id.menu_widget_background_transparent).setChecked(true)
        }
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        if (item.itemId == android.R.id.home) {
            finish()
            return true
        } else if (item.itemId == R.id.menu_sort_order_ascending) {
            replaceListOrderFilter(ListOrderFilter.ASCENDING)
            return true
        } else if (item.itemId == R.id.menu_sort_order_descending) {
            replaceListOrderFilter(ListOrderFilter.DESCENDING)
            return true
        } else if (item.itemId == R.id.menu_sort_by_name) {
            replaceFeedOrderFilter(FeedOrderFilter.NAME)
            return true
        } else if (item.itemId == R.id.menu_sort_by_subs) {
            replaceFeedOrderFilter(FeedOrderFilter.SUBSCRIBERS)
            return true
        } else if (item.itemId == R.id.menu_sort_by_recent_story) {
            replaceFeedOrderFilter(FeedOrderFilter.RECENT_STORY)
            return true
        } else if (item.itemId == R.id.menu_sort_by_stories_month) {
            replaceFeedOrderFilter(FeedOrderFilter.STORIES_MONTH)
            return true
        } else if (item.itemId == R.id.menu_sort_by_number_opens) {
            replaceFeedOrderFilter(FeedOrderFilter.OPENS)
            return true
        } else if (item.itemId == R.id.menu_folder_view_nested) {
            replaceFolderView(FolderViewFilter.NESTED)
            return true
        } else if (item.itemId == R.id.menu_folder_view_flat) {
            replaceFolderView(FolderViewFilter.FLAT)
            return true
        } else if (item.itemId == R.id.menu_widget_background_default) {
            setWidgetBackground(WidgetBackground.DEFAULT)
            return true
        } else if (item.itemId == R.id.menu_widget_background_transparent) {
            setWidgetBackground(WidgetBackground.TRANSPARENT)
            return true
        } else {
            return super.onOptionsItemSelected(item)
        }
    }

    protected open fun setAdapterData() {
        adapter.setData(folderNames, folderChildren, feeds)
    }

    private fun setupObservers() {
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.CREATED) {
                launch {
                    feedFolderViewModel.feedFolderData.collectLatest {
                        processData(it)
                    }
                }
            }
        }
    }

    private fun replaceFeedOrderFilter(feedOrderFilter: FeedOrderFilter) {
        PrefsUtils.setFeedChooserFeedOrder(this, feedOrderFilter)
        adapter.replaceFeedOrder(feedOrderFilter)
    }

    private fun replaceListOrderFilter(listOrderFilter: ListOrderFilter) {
        PrefsUtils.setFeedChooserListOrder(this, listOrderFilter)
        adapter.replaceListOrder(listOrderFilter)
    }

    private fun replaceFolderView(folderViewFilter: FolderViewFilter) {
        PrefsUtils.setFeedChooserFolderView(this, folderViewFilter)
        adapter.replaceFolderView(folderViewFilter)
        setAdapterData()
    }

    private fun setWidgetBackground(widgetBackground: WidgetBackground) {
        PrefsUtils.setWidgetBackground(this, widgetBackground)
        updateWidget(this)
    }

    private fun loadData() {
        feedFolderViewModel.getData()
    }
}
