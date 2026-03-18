package com.newsblur.widget

import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import com.newsblur.R
import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.ImageLoader
import com.newsblur.util.StoryUtils
import com.newsblur.util.ThumbnailStyle
import com.newsblur.util.UIUtils
import java.security.MessageDigest

object WidgetRow {
    fun create(
        context: Context,
        prefsRepo: PrefsRepo,
        iconLoader: ImageLoader,
        thumbnailLoader: ImageLoader,
        story: Story,
    ): RemoteViews {
        val rv = WidgetRemoteViews(context.packageName, R.layout.view_widget_story_item)

        rv.setTextViewText(R.id.story_item_title, story.title)
        rv.setTextViewText(R.id.story_item_content, story.shortContent)
        rv.setTextViewText(R.id.story_item_author, story.authors)
        rv.setTextViewText(R.id.story_item_feedtitle, story.extern_feedTitle)
        rv.setTextViewText(R.id.story_item_date, StoryUtils.formatShortDate(context, story.timestamp))

        // Reset to avoid stale state.
        rv.setImageViewResource(R.id.story_item_feedicon, R.drawable.logo)
        rv.setViewVisibility(R.id.story_item_feedicon, View.VISIBLE)

        rv.setImageViewResource(R.id.story_item_thumbnail, R.drawable.logo)
        rv.setViewVisibility(R.id.story_item_thumbnail, View.VISIBLE)

        // Cached-only image loads (your current behavior).
        iconLoader.displayWidgetImageCachedOnly(
            story.extern_faviconUrl,
            R.id.story_item_feedicon,
            UIUtils.dp2px(context, 19),
            rv,
        )

        if (prefsRepo.getThumbnailStyle() != ThumbnailStyle.OFF && !story.thumbnailUrl.isNullOrEmpty()) {
            thumbnailLoader.displayWidgetImageCachedOnly(
                story.thumbnailUrl,
                R.id.story_item_thumbnail,
                UIUtils.dp2px(context, 64),
                rv,
            )
        } else {
            rv.setViewVisibility(R.id.story_item_thumbnail, View.GONE)
            rv.setImageViewResource(R.id.story_item_thumbnail, R.drawable.logo)
        }

        rv.setViewBackgroundColor(
            R.id.story_item_favicon_borderbar_1,
            UIUtils.decodeColourValue(story.extern_feedColor, Color.GRAY),
        )
        rv.setViewBackgroundColor(
            R.id.story_item_favicon_borderbar_2,
            UIUtils.decodeColourValue(story.extern_feedFade, Color.LTGRAY),
        )

        rv.setOnClickFillInIntent(
            R.id.view_widget_item,
            android.content.Intent().putExtra(WidgetUtils.EXTRA_ITEM_ID, story.storyHash),
        )

        return rv
    }

    fun id64(s: String): Long {
        val md = MessageDigest.getInstance("SHA-256")
        val bytes = md.digest(s.toByteArray(Charsets.UTF_8))
        var out = 0L
        for (i in 0 until 8) out = (out shl 8) or (bytes[i].toLong() and 0xff)
        return out
    }
}
