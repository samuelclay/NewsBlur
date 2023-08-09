package com.newsblur.activity

import android.os.Bundle
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.databinding.ActivityNotificationsBinding
import com.newsblur.di.IconLoader
import com.newsblur.domain.Feed
import com.newsblur.util.ImageLoader
import com.newsblur.util.UIUtils
import com.newsblur.util.setViewGone
import com.newsblur.util.setViewVisible
import com.newsblur.viewModel.NotificationsViewModel
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.flow.collectLatest
import javax.inject.Inject

@AndroidEntryPoint
class NotificationsActivity : NbActivity(), NotificationsAdapter.Listener {

    @IconLoader
    @Inject
    lateinit var imageLoader: ImageLoader

    private lateinit var binding: ActivityNotificationsBinding
    private lateinit var viewModel: NotificationsViewModel
    private lateinit var adapter: NotificationsAdapter

    override fun onCreate(bundle: Bundle?) {
        super.onCreate(bundle)
        viewModel = ViewModelProvider(this)[NotificationsViewModel::class.java]
        binding = ActivityNotificationsBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupUI()
        setupListeners()
    }

    private fun setupUI() {
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.notifications_title), true)
        adapter = NotificationsAdapter(imageLoader, this).also {
            binding.recyclerViewFeeds.adapter = it
        }
    }

    private fun setupListeners() {
        lifecycleScope.launchWhenStarted {
            viewModel.feeds.collectLatest {
                val feeds = it.values
                if (feeds.isNotEmpty()) {
                    binding.recyclerViewFeeds.setViewVisible()
                    binding.txtNoNotifications.setViewGone()
                } else {
                    binding.recyclerViewFeeds.setViewGone()
                    binding.txtNoNotifications.setViewVisible()
                }
                adapter.refreshFeeds(feeds)
            }
        }
    }

    override fun onFeedUpdated(feed: Feed) {
        viewModel.updateFeed(this, feed)
    }
}