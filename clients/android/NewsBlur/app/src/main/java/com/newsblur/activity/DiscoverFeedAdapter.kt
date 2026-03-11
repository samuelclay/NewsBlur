package com.newsblur.activity

import android.content.res.ColorStateList
import android.text.format.DateFormat
import android.text.format.DateUtils
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.newsblur.R
import com.newsblur.databinding.ViewDiscoverFeedRowBinding
import com.newsblur.databinding.ViewDiscoverStoryRowBinding
import com.newsblur.domain.DiscoverFeedPayload
import com.newsblur.domain.DiscoverStory
import com.newsblur.util.DiscoverThemePalette
import com.newsblur.util.ImageLoader
import com.newsblur.viewModel.DiscoverFeedViewMode
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class DiscoverFeedAdapter(
    private val layoutInflater: LayoutInflater,
    private val iconLoader: ImageLoader,
    private var palette: DiscoverThemePalette,
    private var subscribedFeedIds: Set<String>,
    private val listener: Listener,
) : RecyclerView.Adapter<DiscoverFeedAdapter.DiscoverFeedViewHolder>() {
    private val feeds = mutableListOf<DiscoverFeedPayload>()
    private var viewMode = DiscoverFeedViewMode.GRID

    fun submit(
        newFeeds: List<DiscoverFeedPayload>,
        newViewMode: DiscoverFeedViewMode,
        newPalette: DiscoverThemePalette,
        newSubscribedFeedIds: Set<String>,
    ) {
        feeds.clear()
        feeds.addAll(newFeeds)
        viewMode = newViewMode
        palette = newPalette
        subscribedFeedIds = newSubscribedFeedIds
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(
        parent: ViewGroup,
        viewType: Int,
    ): DiscoverFeedViewHolder {
        val view = layoutInflater.inflate(R.layout.view_discover_feed_row, parent, false)
        return DiscoverFeedViewHolder(ViewDiscoverFeedRowBinding.bind(view))
    }

    override fun onBindViewHolder(
        holder: DiscoverFeedViewHolder,
        position: Int,
    ) {
        holder.bind(feeds[position])
    }

    override fun getItemCount(): Int = feeds.size

    inner class DiscoverFeedViewHolder(
        private val binding: ViewDiscoverFeedRowBinding,
    ) : RecyclerView.ViewHolder(binding.root) {
        fun bind(payload: DiscoverFeedPayload) {
            val feed = payload.feed
            val isSubscribed = subscribedFeedIds.contains(feed.feedId)
            binding.discoverFeedCard.setCardBackgroundColor(palette.surfaceColor)
            binding.discoverFeedCard.strokeColor = palette.borderColor
            binding.discoverFeedTitle.setTextColor(palette.textPrimaryColor)
            binding.discoverFeedMeta.setTextColor(palette.textSecondaryColor)
            binding.discoverFeedFreshness.setTextColor(palette.textSecondaryColor)
            binding.discoverFeedDivider.setBackgroundColor(palette.borderColor)

            binding.discoverFeedTitle.text = feed.title
            binding.discoverFeedMeta.text = buildMetaLine(feed)

            val freshnessLine = buildFreshnessLine(feed)
            binding.discoverFeedFreshness.visibility = if (freshnessLine.isNullOrBlank()) View.GONE else View.VISIBLE
            binding.discoverFeedFreshness.text = freshnessLine

            binding.discoverFeedIcon.setImageDrawable(null)
            if (!feed.faviconUrl.isNullOrBlank()) {
                iconLoader.displayImage(feed.faviconUrl, binding.discoverFeedIcon)
            }

            binding.discoverFeedSubscribed.visibility = if (isSubscribed) View.VISIBLE else View.GONE
            binding.discoverFeedTry.visibility = if (isSubscribed) View.GONE else View.VISIBLE
            binding.discoverFeedAdd.visibility = if (isSubscribed) View.GONE else View.VISIBLE
            binding.discoverFeedSubscribed.text = binding.root.context.getString(R.string.discover_subscribed)
            binding.discoverFeedSubscribed.setTextColor(palette.accentColor)
            styleButton(
                binding.discoverFeedTry,
                backgroundColor = palette.secondaryButtonBackgroundColor,
                textColor = palette.secondaryButtonTextColor,
            )
            styleButton(
                binding.discoverFeedAdd,
                backgroundColor = palette.accentColor,
                textColor = palette.accentTextColor,
            )

            binding.discoverFeedTry.setOnClickListener { listener.onTryFeed(payload) }
            binding.discoverFeedAdd.setOnClickListener { listener.onAddFeed(payload) }

            val showStories = viewMode == DiscoverFeedViewMode.LIST && payload.stories.isNotEmpty()
            binding.discoverFeedDivider.visibility = if (showStories) View.VISIBLE else View.GONE
            binding.discoverStoryContainer.visibility = if (showStories) View.VISIBLE else View.GONE

            binding.discoverStoryContainer.removeAllViews()
            if (showStories) {
                payload.stories.take(MAX_STORIES).forEach { story ->
                    val storyBinding =
                        ViewDiscoverStoryRowBinding.inflate(layoutInflater, binding.discoverStoryContainer, false)
                    bindStory(storyBinding, story)
                    binding.discoverStoryContainer.addView(storyBinding.root)
                }
            }
        }

        private fun bindStory(
            storyBinding: ViewDiscoverStoryRowBinding,
            story: DiscoverStory,
        ) {
            storyBinding.discoverStoryDot.backgroundTintList = ColorStateList.valueOf(palette.accentColor)
            storyBinding.discoverStoryTitle.text = story.storyTitle
            storyBinding.discoverStoryTitle.setTextColor(palette.textPrimaryColor)
            storyBinding.discoverStoryMeta.setTextColor(palette.textSecondaryColor)
            storyBinding.discoverStoryMeta.text = buildStoryMeta(story)
        }

        private fun buildMetaLine(feed: com.newsblur.domain.Feed): String {
            val parts = mutableListOf<String>()
            val subscribers = feed.subscribers?.toIntOrNull() ?: 0
            if (subscribers > 0) {
                val formatted = NumberFormat.getIntegerInstance().format(subscribers)
                val label =
                    binding.root.resources.getQuantityString(
                        R.plurals.discover_subscribers,
                        subscribers,
                        formatted,
                    )
                parts.add(label)
            }
            if (feed.storiesPerMonth > 0) {
                val formatted = NumberFormat.getIntegerInstance().format(feed.storiesPerMonth)
                val label =
                    binding.root.resources.getQuantityString(
                        R.plurals.discover_stories_per_month,
                        feed.storiesPerMonth,
                        formatted,
                    )
                parts.add(label)
            }
            return parts.joinToString(separator = " \u2022 ")
        }

        private fun buildFreshnessLine(feed: com.newsblur.domain.Feed): String? {
            val parts = mutableListOf<String>()
            parseApiDate(feed.lastStoryDate)?.let { lastStoryDate ->
                val daysAgo = ((System.currentTimeMillis() - lastStoryDate.time) / DateUtils.DAY_IN_MILLIS).toInt()
                val freshness =
                    if (daysAgo < 1) {
                        binding.root.context.getString(R.string.discover_updated_today)
                    } else if (daysAgo < 365) {
                        val relative = DateUtils.getRelativeTimeSpanString(lastStoryDate.time, System.currentTimeMillis(), DateUtils.DAY_IN_MILLIS)
                        binding.root.context.getString(R.string.discover_updated_relative, relative)
                    } else {
                        val formattedDate = DateFormat.getMediumDateFormat(binding.root.context).format(lastStoryDate)
                        binding.root.context.getString(R.string.discover_stale_date, formattedDate)
                    }
                parts.add(freshness)
            }
            if (feed.lastUpdated > 0) {
                val fetchedAt = System.currentTimeMillis() - (feed.lastUpdated * DateUtils.SECOND_IN_MILLIS)
                val relative = DateUtils.getRelativeTimeSpanString(fetchedAt, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS)
                parts.add(binding.root.context.getString(R.string.discover_last_fetched_relative, relative))
            }
            return parts.takeIf { it.isNotEmpty() }?.joinToString(separator = " \u2022 ")
        }

        private fun buildStoryMeta(story: DiscoverStory): String {
            val parts = mutableListOf<String>()
            if (story.storyAuthors.isNotBlank()) {
                parts.add(story.storyAuthors)
            }
            parseApiDate(story.storyDate)?.let { storyDate ->
                parts.add(DateUtils.getRelativeTimeSpanString(storyDate.time, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS).toString())
            }
            return parts.joinToString(separator = " \u2022 ")
        }

        private fun styleButton(
            button: MaterialButton,
            backgroundColor: Int,
            textColor: Int,
        ) {
            button.backgroundTintList = ColorStateList.valueOf(backgroundColor)
            button.strokeColor = ColorStateList.valueOf(backgroundColor)
            button.setTextColor(textColor)
        }
    }

    interface Listener {
        fun onTryFeed(payload: DiscoverFeedPayload)

        fun onAddFeed(payload: DiscoverFeedPayload)
    }

    companion object {
        private const val MAX_STORIES = 3
        private val apiDateFormat by lazy {
            SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
        }

        private fun parseApiDate(rawDate: String?): Date? {
            if (rawDate.isNullOrBlank()) return null
            return runCatching { apiDateFormat.parse(rawDate) }.getOrNull()
        }
    }
}
