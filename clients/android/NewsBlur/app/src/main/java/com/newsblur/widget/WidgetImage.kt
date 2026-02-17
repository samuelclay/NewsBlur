package com.newsblur.widget

import android.content.Context
import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.ImageLoader
import com.newsblur.util.ThumbnailStyle
import com.newsblur.util.UIUtils
import kotlin.math.min

object WidgetImage {
    fun prefetch(
        context: Context,
        prefsRepo: PrefsRepo,
        iconLoader: ImageLoader,
        thumbnailLoader: ImageLoader,
        stories: List<Story>,
    ) {
        val iconPx = UIUtils.dp2px(context, 19)
        val thumbPx = UIUtils.dp2px(context, 64)
        val limit = min(stories.size, WidgetUtils.STORIES_LIMIT)

        for (i in 0 until limit) {
            val s = stories[i]
            iconLoader.prefetchToCache(s.extern_faviconUrl, iconPx)

            if (prefsRepo.getThumbnailStyle() != ThumbnailStyle.OFF && !s.thumbnailUrl.isNullOrEmpty()) {
                thumbnailLoader.prefetchToCache(s.thumbnailUrl, thumbPx)
            }
        }
    }
}
