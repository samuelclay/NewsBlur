package com.newsblur.fragment

import android.view.View
import android.widget.LinearLayout
import android.widget.RelativeLayout
import com.newsblur.databinding.FragmentReadingitemBinding
import com.newsblur.databinding.ReadingItemActionsBinding
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Test

class ReaderArticleFooterVisibilityTest {
    @Test
    fun populatedClusterDoesNotAppearUnderNativeTitleWhileArticleIsPreparing() {
        val fragment = mockk<ReadingItemFragment>(relaxed = true)
        val binding = mockk<FragmentReadingitemBinding>(relaxed = true)
        val actions = mockk<ReadingItemActionsBinding>(relaxed = true)
        val cluster = mockk<LinearLayout>(relaxed = true)
        val divider = mockk<View>(relaxed = true)
        val buttons = mockk<LinearLayout>(relaxed = true)
        val comments = mockk<RelativeLayout>(relaxed = true)
        FragmentReadingitemBinding::class.java.getField("readingStoryClusterContainer").apply { isAccessible = true }.set(binding, cluster)
        FragmentReadingitemBinding::class.java.getField("readingStoryClusterDivider").apply { isAccessible = true }.set(binding, divider)
        ReadingItemActionsBinding::class.java.getField("actionsContainer").apply { isAccessible = true }.set(actions, buttons)
        ReadingItemActionsBinding::class.java.getField("commentsContainer").apply { isAccessible = true }.set(actions, comments)
        every { cluster.visibility } returns View.VISIBLE
        every { divider.visibility } returns View.VISIBLE
        setField(fragment, "binding", binding)
        setField(fragment, "readingItemActionsBinding", actions)
        setField(fragment, "articleReveal", ReaderArticleReveal {})
        // ReadingItemFragment.kt may receive document completion before the body fade finishes.
        setField(fragment, "hasCompletedInitialStoryRender", true)
        every { fragment["syncStoryLoadingUi"]() } answers { callOriginal() }
        ReadingItemFragment::class.java.getDeclaredMethod("syncStoryLoadingUi").apply {
            isAccessible = true
            invoke(fragment)
        }
        verify { cluster.visibility = View.INVISIBLE }
        verify { actions.actionsContainer.visibility = View.GONE }
        verify { actions.commentsContainer.visibility = View.INVISIBLE }
    }

    private fun setField(fragment: ReadingItemFragment, name: String, value: Any) {
        ReadingItemFragment::class.java.getDeclaredField(name).apply {
            isAccessible = true
            set(fragment, value)
        }
    }
}
