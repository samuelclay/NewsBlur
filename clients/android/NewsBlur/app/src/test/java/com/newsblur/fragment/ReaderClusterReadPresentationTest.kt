package com.newsblur.fragment

import android.content.Context
import android.graphics.Color
import android.text.Spanned
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import com.newsblur.R
import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.FeedUtils
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.StoryClusterBadgeViewBinder
import com.newsblur.util.StoryClusterThemeStyle
import com.newsblur.util.StoryUtils
import com.newsblur.util.UIUtils
import com.newsblur.view.StoryThumbnailView
import io.mockk.Runs
import io.mockk.clearMocks
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.mockkStatic
import io.mockk.unmockkObject
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.Test

class ReaderClusterReadPresentationTest {
    @Test fun explicitUnreadAndPreferenceChangesKeepChildUndimmedInEveryTheme() {
        mockkStatic(Color::class, UIUtils::class, StoryUtils::class)
        mockkObject(StoryClusterBadgeViewBinder)
        try {
            every { Color.parseColor(any()) } answers {
                val hex = firstArg<String>().removePrefix("#")
                (if (hex.length == 6) "FF$hex" else hex).toLong(16).toInt()
            }
            every { UIUtils.dp2px(any(), any<Int>()) } answers { secondArg() }
            every { UIUtils.decodeColourValue(any(), any()) } answers { secondArg() }
            every { UIUtils.fromHtml(any()) } returns mockk<Spanned>()
            every { StoryUtils.formatRelativeShortDate(any()) } returns "1m"
            every { StoryClusterBadgeViewBinder.bind(any(), any(), any(), any(), any()) } just Runs

            for (theme in listOf(ThemeValue.LIGHT, ThemeValue.DARK, ThemeValue.BLACK, ThemeValue.SEPIA)) {
                val fixture = Fixture(theme)
                val palette = StoryClusterThemeStyle.palette(theme)

                fixture.child.read = true
                fixture.bind()
                withReadStateContext("theme=$theme, read=true") {
                    verify { fixture.title.setTextColor(palette.readTitleColor) }
                    verify { fixture.sentiment.imageAlpha = 38 }
                }

                fixture.child.read = false
                for (enabled in listOf(true, false, true)) {
                    every { fixture.prefs.isClusterMarkReadEnabled() } returns enabled
                    clearMocks(fixture.title, fixture.sentiment, fixture.outerBar, answers = false)
                    fixture.bind()

                    withReadStateContext("theme=$theme, clusterMarkRead=$enabled, read=false") {
                        verify(exactly = 1) { fixture.title.setTextColor(palette.titleColor) }
                        verify(exactly = 1) { fixture.sentiment.imageAlpha = 255 }
                        verify(exactly = 1) { fixture.outerBar.alpha = 1f }
                        verify { StoryClusterBadgeViewBinder.bind(fixture.badge, fixture.context, any(), palette, false) }
                        verify {
                            fixture.fragment["bindClusterPreview"](
                                fixture.preview, fixture.badge, fixture.title, fixture.date, "https://example.com/child.jpg", false,
                            )
                        }
                    }
                }
            }
        } finally {
            unmockkObject(StoryClusterBadgeViewBinder)
            unmockkStatic(Color::class, UIUtils::class, StoryUtils::class)
        }
    }

    private inline fun withReadStateContext(context: String, assertions: () -> Unit) {
        try {
            assertions()
        } catch (failure: AssertionError) {
            throw AssertionError(context, failure)
        }
    }

    private class Fixture(theme: ThemeValue) {
        val context = mockk<Context>(relaxed = true)
        val prefs = mockk<PrefsRepo>(relaxed = true)
        val fragment = mockk<ReadingItemFragment>(relaxed = true)
        val title = mockk<TextView>(relaxed = true)
        val date = mockk<TextView>(relaxed = true)
        val badge = mockk<TextView>(relaxed = true)
        val sentiment = mockk<ImageView>(relaxed = true)
        val preview = mockk<StoryThumbnailView>(relaxed = true)
        val outerBar = mockk<View>(relaxed = true)
        val child = Story.ClusterStory().apply {
            storyHash = "2:child"
            feedId = "2"
            title = "Related story"
            imageUrls = arrayOf("https://example.com/child.jpg")
        }
        private val view = mockk<View>(relaxed = true)

        init {
            val feedUtils = mockk<FeedUtils>(relaxed = true)
            every { fragment.prefsRepo } returns prefs
            every { fragment.feedUtils } returns feedUtils
            every { fragment.requireContext() } returns context
            every { prefs.getResolvedTheme(context) } returns theme
            every { sentiment.layoutParams } returns mockk<ViewGroup.LayoutParams>(relaxed = true)
            every { view.findViewById<TextView>(R.id.story_cluster_title) } returns title
            every { view.findViewById<TextView>(R.id.story_cluster_date) } returns date
            every { view.findViewById<TextView>(R.id.story_cluster_badge) } returns badge
            every { view.findViewById<ImageView>(R.id.story_cluster_sentiment) } returns sentiment
            every { view.findViewById<ImageView>(R.id.story_cluster_feed_icon) } returns mockk(relaxed = true)
            every { view.findViewById<StoryThumbnailView>(R.id.story_cluster_preview) } returns preview
            every { view.findViewById<View>(R.id.story_cluster_bar_outer) } returns outerBar
            every { fragment.bindClusterItemView(any(), any(), any(), any(), any()) } answers { callOriginal() }
        }

        fun bind() {
            fragment.bindClusterItemView(view, child, false, 1, {})
        }
    }
}
