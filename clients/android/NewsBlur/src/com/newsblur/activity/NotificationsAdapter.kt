package com.newsblur.activity

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.databinding.ViewNotificationsItemBinding
import com.newsblur.domain.Feed
import com.newsblur.util.FeedExt
import com.newsblur.util.FeedExt.disableNotificationType
import com.newsblur.util.FeedExt.enableNotificationType
import com.newsblur.util.FeedExt.isNotifyAndroid
import com.newsblur.util.FeedExt.isNotifyEmail
import com.newsblur.util.FeedExt.isNotifyFocus
import com.newsblur.util.FeedExt.isNotifyIOS
import com.newsblur.util.FeedExt.isNotifyUnread
import com.newsblur.util.FeedExt.isNotifyWeb
import com.newsblur.util.FeedExt.setNotifyFocus
import com.newsblur.util.FeedExt.setNotifyUnread
import com.newsblur.util.ImageLoader

class NotificationsAdapter(
        private val imageLoader: ImageLoader,
        private val listener: Listener,
) : RecyclerView.Adapter<NotificationsAdapter.ViewHolder>() {

    private val feeds: MutableList<Feed> = mutableListOf()

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ViewNotificationsItemBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding, imageLoader)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(feeds[position], listener)

    override fun getItemCount(): Int = feeds.size

    fun refreshFeeds(feeds: Collection<Feed>) {
        this.feeds.clear()
        this.feeds.addAll(feeds)
        this.notifyItemRangeInserted(0, feeds.size)
    }

    class ViewHolder(val binding: ViewNotificationsItemBinding, val imageLoader: ImageLoader) : RecyclerView.ViewHolder(binding.root) {

        fun bind(feed: Feed, listener: Listener) {
            binding.textTitle.text = feed.title
            imageLoader.displayImage(feed.faviconUrl, binding.imgIcon, binding.imgIcon.height, true)

            with(binding.groupFilter) {
                if (feed.isNotifyUnread()) check(binding.btnUnread.id)
                else if (feed.isNotifyFocus()) check(binding.btnFocus.id)
            }

            with(binding.groupPlatform) {
                if (feed.isNotifyEmail()) check(binding.btnEmail.id)
                if (feed.isNotifyWeb()) check(binding.btnWeb.id)
                if (feed.isNotifyIOS()) check(binding.btnIos.id)
                if (feed.isNotifyAndroid()) check(binding.btnAndroid.id)
            }

            binding.groupFilter.addOnButtonCheckedListener { _, checkedId, isChecked ->
                updateFilter(feed, checkedId, isChecked)
                listener.onFeedUpdated(feed)
            }
            binding.groupPlatform.addOnButtonCheckedListener { _, checkedId, isChecked ->
                updatePlatform(feed, checkedId, isChecked)
                listener.onFeedUpdated(feed)
            }
        }

        private fun updateFilter(feed: Feed, checkedBtnId: Int, isChecked: Boolean) {
            when (checkedBtnId) {
                binding.btnUnread.id -> if (isChecked) feed.setNotifyUnread()
                binding.btnFocus.id -> if (isChecked) feed.setNotifyFocus()
            }
        }

        private fun updatePlatform(feed: Feed, checkedBtnId: Int, isChecked: Boolean) {
            when (checkedBtnId) {
                binding.btnEmail.id -> FeedExt.NOTIFY_EMAIL
                binding.btnWeb.id -> FeedExt.NOTIFY_WEB
                binding.btnIos.id -> FeedExt.NOTIFY_IOS
                binding.btnIos.id -> FeedExt.NOTIFY_ANDROID
                else -> null
            }?.let {
                if (isChecked) feed.enableNotificationType(it)
                else feed.disableNotificationType(it)
            }
        }
    }

    interface Listener {
        fun onFeedUpdated(feed: Feed)
    }
}