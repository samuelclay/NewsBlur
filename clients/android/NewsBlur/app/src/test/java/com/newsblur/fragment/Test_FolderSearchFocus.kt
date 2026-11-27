package com.newsblur.fragment

import android.text.Editable
import android.text.TextUtils
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import com.newsblur.database.FolderListAdapter
import com.newsblur.databinding.ViewFeedListSearchHeaderBinding
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkStatic
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_FolderSearchFocus {
    @Test
    fun test_shortening_query_before_focus_restore_preserves_new_cursor() {
        val fragment = FolderListFragment()
        val input = mockk<EditText>(relaxed = true)
        val posted = slot<Runnable>()
        var text = "abcdefghi"
        var cursor = 9
        val editable = mockk<Editable>()
        every { editable.toString() } answers { text }
        every { editable.length } answers { text.length }
        every { input.text } returns editable
        every { input.hasFocus() } returns true
        every { input.selectionEnd } answers { cursor }
        every { input.post(capture(posted)) } returns true
        every { input.setSelection(any()) } answers {
            val index = firstArg<Int>()
            if (index !in 0..text.length) throw IndexOutOfBoundsException("setSelection($index) on ${text.length} characters")
            cursor = index
        }

        val adapter = mockk<FolderListAdapter>(relaxed = true)
        adapter.activeSearchQuery = text
        val header = ViewFeedListSearchHeaderBinding::class.java.declaredConstructors.single().apply { isAccessible = true }
            .newInstance(mockk<FrameLayout>(), mockk<ImageButton>(relaxed = true), input)
        FolderListFragment::class.java.getDeclaredField("searchHeaderBinding").apply { isAccessible = true }.set(fragment, header)
        FolderListFragment::class.java.getDeclaredField("adapter").apply { isAccessible = true }.set(fragment, adapter)

        mockkStatic(TextUtils::class)
        try {
            every { TextUtils.isEmpty(any()) } answers { firstArg<CharSequence>().isEmpty() }
            every { TextUtils.equals(any(), any()) } answers {
                firstArg<CharSequence>().toString() == secondArg<CharSequence>().toString()
            }
            fragment.setSearchQuery(text)
            text = "abcde"
            cursor = 2
            posted.captured.run()
            assertEquals(2, cursor)
        } finally {
            unmockkStatic(TextUtils::class)
        }
    }
}
