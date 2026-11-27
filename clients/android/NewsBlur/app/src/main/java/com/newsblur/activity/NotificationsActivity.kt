package com.newsblur.activity

import android.os.Bundle
import androidx.core.view.isVisible
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.newsblur.R
import com.newsblur.databinding.ActivityNotificationsBinding
import com.newsblur.di.IconLoader
import com.newsblur.domain.Feed
import com.newsblur.util.DeviceNotifications
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.FeedExt.isNotifyAndroid
import com.newsblur.util.ImageLoader
import com.newsblur.util.UIUtils
import com.newsblur.util.setViewGone
import com.newsblur.util.setViewVisible
import com.newsblur.viewModel.NotificationsViewModel
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class NotificationsActivity :
    NbActivity(),
    NotificationsAdapter.Listener {
    @IconLoader
    @Inject
    lateinit var imageLoader: ImageLoader

    private lateinit var binding: ActivityNotificationsBinding
    private lateinit var viewModel: NotificationsViewModel
    private lateinit var adapter: NotificationsAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewModel = ViewModelProvider(this)[NotificationsViewModel::class.java]
        binding = ActivityNotificationsBinding.inflate(layoutInflater)
        applyView(binding)

        setupUI()
        setupListeners()
    }

    override fun onResume() {
        super.onResume()
        // Android's permission dialog and the app's system settings both return here.
        updateNotificationsOffBanner()
    }

    private fun setupUI() {
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.notifications_title), true)
        adapter =
            NotificationsAdapter(imageLoader, this).also {
                binding.content.adapter = it
            }
    }

    private fun setupListeners() {
        binding.btnEnableNotifications.setOnClickListener {
            DeviceNotifications.turnOn(this, prefsRepo)
            updateNotificationsOffBanner()
        }
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                launch {
                    viewModel.feeds.collectLatest {
                        val feeds = it.values
                        if (feeds.isNotEmpty()) {
                            binding.content.setViewVisible()
                            binding.txtNoNotifications.setViewGone()
                        } else {
                            binding.content.setViewGone()
                            binding.txtNoNotifications.setViewVisible()
                        }
                        adapter.refreshFeeds(feeds)
                        updateNotificationsOffBanner()
                    }
                }
            }
        }
    }

    override fun onFeedUpdated(feed: Feed) {
        viewModel.updateFeed(this, feed)
        updateNotificationsOffBanner()
    }

    override fun onAndroidNotificationsEnabled() {
        DeviceNotifications.turnOn(this, prefsRepo)
        updateNotificationsOffBanner()
    }

    /** NotificationsActivity.kt: feeds set to notify on Android stay silent while this device has notifications off. */
    private fun updateNotificationsOffBanner() {
        val hasAndroidFeeds = viewModel.feeds.value.values.any { it.isNotifyAndroid() }
        binding.notificationsOffBanner.isVisible = hasAndroidFeeds && !DeviceNotifications.isOn(this, prefsRepo)
    }
}
