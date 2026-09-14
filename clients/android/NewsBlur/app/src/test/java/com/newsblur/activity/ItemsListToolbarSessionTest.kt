package com.newsblur.activity

import android.content.Intent
import androidx.activity.result.ActivityResult
import com.newsblur.util.FeedSet
import com.newsblur.util.UIUtils
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.Test

class ItemsListToolbarSessionTest {
    @Test
    fun relatedStoryLaunchesInheritTheCurrentReaderVisibility() {
        mockkStatic(UIUtils::class)
        try {
            val reading = mockk<Reading>(relaxed = true)
            val feedSet = mockk<FeedSet>()
            every { UIUtils.startReadingActivity(any(), any(), any(), any(), any()) } returns Unit
            every { UIUtils.startReadingActivity(reading, feedSet, any(), null) } answers { callOriginal() }
            for (hidden in listOf(true, false)) {
                every { reading.isToolbarHidden() } returns hidden
                UIUtils.startReadingActivity(reading, feedSet, "related-$hidden", null)
                verify { UIUtils.startReadingActivity(reading, feedSet, "related-$hidden", null, hidden) }
            }
        } finally {
            unmockkStatic(UIUtils::class)
        }
    }

    @Test
    fun titleSelectionsReuseHiddenAndThenVisibleReaderState() {
        mockkStatic(UIUtils::class)
        try {
            val titles = mockk<ItemsList>(relaxed = true)
            every { titles["launchReadingActivity"](any<FeedSet>(), any<String>()) } answers { callOriginal() }
            every { titles["handleReadingActivityResult"](any<ActivityResult>()) } answers { callOriginal() }
            val feedSet = mockk<FeedSet>()
            val launch = ItemsList::class.java.getDeclaredMethod(
                "launchReadingActivity", FeedSet::class.java, String::class.java,
            ).apply { isAccessible = true }
            val receive = ItemsList::class.java.getDeclaredMethod(
                "handleReadingActivityResult", ActivityResult::class.java,
            ).apply { isAccessible = true }
            every { UIUtils.startReadingActivity(any(), any(), any(), any(), any()) } returns Unit

            launch.invoke(titles, feedSet, "first")
            verify { UIUtils.startReadingActivity(titles, feedSet, "first", any(), false) }

            for (hidden in listOf(true, false)) {
                val data = mockk<Intent>()
                every { data.getStringExtra(Reading.LAST_READING_STORY_HASH) } returns null
                every { data.getBooleanExtra(Reading.EXTRA_TOOLBAR_HIDDEN, any()) } returns hidden
                val result = mockk<ActivityResult>()
                every { result.data } returns data
                receive.invoke(titles, result)
                launch.invoke(titles, feedSet, "next-$hidden")
                verify { UIUtils.startReadingActivity(titles, feedSet, "next-$hidden", any(), hidden) }
            }

            // ItemsList.java owns this state; another titles session must start with its header visible.
            val otherTitles = mockk<ItemsList>(relaxed = true)
            every { otherTitles["launchReadingActivity"](any<FeedSet>(), any<String>()) } answers { callOriginal() }
            launch.invoke(otherTitles, feedSet, "other")
            verify { UIUtils.startReadingActivity(otherTitles, feedSet, "other", any(), false) }
        } finally {
            unmockkStatic(UIUtils::class)
        }
    }
}
