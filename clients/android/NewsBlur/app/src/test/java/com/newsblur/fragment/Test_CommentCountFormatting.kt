package com.newsblur.fragment

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.newsblur.R
import com.newsblur.util.ImageLoader
import com.newsblur.view.FlowLayout
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Test

class Test_CommentCountFormatting {
    @Test
    fun test_single_share_preserves_a_translation_ending_in_a_format_placeholder() {
        checkCount("topShareViews", R.id.shared_by, R.plurals.friends_shares_count, 1)
    }

    @Test
    fun test_all_comment_and_share_labels_use_native_plural_selection() {
        val labels = listOf(
            Triple("topCommentViews", R.id.comment_by, R.plurals.friends_comments_count),
            Triple("topShareViews", R.id.shared_by, R.plurals.friends_shares_count),
            Triple("publicCommentViews", R.id.reading_public_comment_total, R.plurals.public_comment_count),
            Triple("friendCommentViews", R.id.reading_friend_comment_total, R.plurals.friends_comments_count),
            Triple("friendShareViews", R.id.reading_friend_emptyshare_total, R.plurals.friends_shares_count),
        )
        for ((field, label, resource) in labels) {
            for (count in listOf(1, 2, 5)) checkCount(field, label, resource, count)
        }
    }

    private fun checkCount(field: String, labelId: Int, pluralId: Int, count: Int) {
        val context = mockk<Context>(relaxed = true)
        val fragment = mockk<ReadingItemFragment>(relaxed = true)
        val root = mockk<View>(relaxed = true)
        val label = mockk<TextView>(relaxed = true)
        every { fragment.requireContext() } returns context
        // Test_CommentCountFormatting.kt reproduces translations whose placeholder comes last.
        every { context.getString(any()) } returns "Count: %d"
        every { context.resources.getQuantityString(pluralId, count, count) } returns "Count: $count"
        for (id in listOf(R.id.comment_by, R.id.shared_by, R.id.reading_friend_comment_total,
            R.id.reading_friend_emptyshare_total, R.id.reading_public_comment_total)) {
            every { root.findViewById<View>(id) } returns mockk<TextView>(relaxed = true)
        }
        every { root.findViewById<View>(labelId) } returns label
        for (id in listOf(R.id.reading_social_shareimages, R.id.reading_social_commentimages)) {
            every { root.findViewById<View>(id) } returns mockk<FlowLayout>(relaxed = true)
        }
        for (id in listOf(R.id.reading_public_comment_container, R.id.reading_friend_comment_container,
            R.id.reading_friend_emptyshare_container)) {
            every { root.findViewById<View>(id) } returns mockk<LinearLayout>(relaxed = true)
        }
        val task = SetupCommentSectionTask(fragment, root, mockk<LayoutInflater>(), null, mockk<ImageLoader>())
        @Suppress("UNCHECKED_CAST")
        val views = SetupCommentSectionTask::class.java.getDeclaredField(field)
            .apply { isAccessible = true }.get(task) as MutableList<View>
        repeat(count) { views.add(mockk(relaxed = true)) }

        SetupCommentSectionTask::class.java.getDeclaredMethod("onPostExecute")
            .apply { isAccessible = true }.invoke(task)

        verify { label.text = "Count: $count" }
        verify { context.resources.getQuantityString(pluralId, count, count) }
    }
}
