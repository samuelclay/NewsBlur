package com.newsblur.activity

import android.content.res.ColorStateList
import android.text.format.DateUtils
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.view.isVisible
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.newsblur.R
import com.newsblur.databinding.ViewDiscoverFeedRowBinding
import com.newsblur.databinding.ViewDiscoverStoryRowBinding
import com.newsblur.domain.DiscoverFeedPayload
import com.newsblur.domain.DiscoverStory
import com.newsblur.util.DiscoverFeedFreshnessFormatter
import com.newsblur.util.DiscoverStoryTextFormatter
import com.newsblur.util.DiscoverThemePalette
import com.newsblur.util.ImageLoader
import com.newsblur.viewModel.DiscoverFeedViewMode
import java.text.NumberFormat

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
            binding.discoverFeedDivider.setBackgroundColor(palette.borderColor)

            binding.discoverFeedTitle.text = feed.title

            val subscribersText = buildSubscriberLine(feed)
            binding.discoverFeedSubscribersGroup.isVisible = !subscribersText.isNullOrBlank()
            binding.discoverFeedSubscribersText.text = subscribersText
            binding.discoverFeedSubscribersText.setTextColor(palette.textSecondaryColor)
            binding.discoverFeedSubscribersIcon.imageTintList = ColorStateList.valueOf(palette.textSecondaryColor)

            val storiesText = buildStoriesPerMonthLine(feed)
            binding.discoverFeedStoriesGroup.isVisible = !storiesText.isNullOrBlank()
            binding.discoverFeedStoriesText.text = storiesText
            binding.discoverFeedStoriesText.setTextColor(palette.textSecondaryColor)
            binding.discoverFeedStoriesIcon.imageTintList = ColorStateList.valueOf(palette.textSecondaryColor)
            binding.discoverFeedMetaRow.isVisible = binding.discoverFeedSubscribersGroup.isVisible || binding.discoverFeedStoriesGroup.isVisible

            val freshnessInfo = buildFreshnessInfo(feed)
            binding.discoverFeedFreshnessRow.isVisible = freshnessInfo != null
            if (freshnessInfo != null) {
                val freshnessColor = if (freshnessInfo.isStale) palette.freshnessStaleColor else palette.freshnessActiveColor
                binding.discoverFeedFreshnessDot.backgroundTintList = ColorStateList.valueOf(freshnessColor)
                binding.discoverFeedFreshnessText.text = freshnessInfo.text
                binding.discoverFeedFreshnessText.setTextColor(freshnessColor)
            }

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
            storyBinding.discoverStoryTitle.text = DiscoverStoryTextFormatter.formatTitle(story.storyTitle)
            storyBinding.discoverStoryTitle.setTextColor(palette.textPrimaryColor)
            storyBinding.discoverStoryMeta.setTextColor(palette.textSecondaryColor)
            storyBinding.discoverStoryMeta.text = buildStoryMeta(story)
        }

        private fun buildSubscriberLine(feed: com.newsblur.domain.Feed): String? {
            val subscribers = feed.subscribers?.toIntOrNull() ?: 0
            if (subscribers <= 0) return null
            val formatted = NumberFormat.getIntegerInstance().format(subscribers)
            return binding.root.resources.getQuantityString(R.plurals.discover_subscribers, subscribers, formatted)
        }

        private fun buildStoriesPerMonthLine(feed: com.newsblur.domain.Feed): String? {
            if (feed.storiesPerMonth <= 0) return null
            val formatted = NumberFormat.getIntegerInstance().format(feed.storiesPerMonth)
            return binding.root.resources.getQuantityString(
                R.plurals.discover_stories_per_month,
                feed.storiesPerMonth,
                formatted,
            )
        }

        private fun buildFreshnessInfo(feed: com.newsblur.domain.Feed): FreshnessInfo? {
            val freshness = DiscoverFeedFreshnessFormatter.build(feed) ?: return null
            val relative =
                DateUtils.getRelativeTimeSpanString(
                    freshness.updatedAtMillis,
                    System.currentTimeMillis(),
                    DateUtils.MINUTE_IN_MILLIS,
                ).toString()
            val freshnessText =
                if (freshness.isStale) {
                    binding.root.context.getString(R.string.discover_stale_updated_relative, relative)
                } else {
                    binding.root.context.getString(R.string.discover_updated_relative, relative)
                }
            return FreshnessInfo(freshnessText, freshness.isStale)
        }

        private fun buildStoryMeta(story: DiscoverStory): String {
            val parts = mutableListOf<String>()
            if (story.storyAuthors.isNotBlank()) {
                parts.add(story.storyAuthors)
            }
            DiscoverFeedFreshnessFormatter.parseApiDateMillis(story.storyDate)?.let { storyDateMillis ->
                parts.add(
                    DateUtils.getRelativeTimeSpanString(
                        storyDateMillis,
                        System.currentTimeMillis(),
                        DateUtils.MINUTE_IN_MILLIS,
                    ).toString(),
                )
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

        private data class FreshnessInfo(
            val text: String,
            val isStale: Boolean,
        )
    }
}
