package com.newsblur.database

import android.view.ViewGroup
import androidx.fragment.app.FragmentManager
import androidx.fragment.app.FragmentTransaction
import com.newsblur.fragment.ReadingItemFragment
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Test

class ReadingAdapterPageReleaseTest {
    @Test
    fun leavingTheResidentPageWindowRemovesTheFragmentInsteadOfRetainingEveryVisitedStory() {
        val manager = mockk<FragmentManager>()
        val transaction = mockk<FragmentTransaction>(relaxed = true)
        every { manager.beginTransaction() } returns transaction
        val fragment = mockk<ReadingItemFragment>(relaxed = true)
        val adapter = mockk<ReadingAdapter>(relaxed = true)
        every { adapter.destroyItem(any(), any(), any()) } answers { callOriginal() }
        setField(adapter, "fm", manager)

        adapter.destroyItem(mockk<ViewGroup>(), 0, fragment)

        verify(exactly = 1) { transaction.remove(fragment) }
        verify(exactly = 0) { transaction.detach(fragment) }
    }

    private fun setField(
        target: ReadingAdapter,
        name: String,
        value: Any,
    ) {
        ReadingAdapter::class.java.getDeclaredField(name).apply {
            isAccessible = true
            set(target, value)
        }
    }
}
