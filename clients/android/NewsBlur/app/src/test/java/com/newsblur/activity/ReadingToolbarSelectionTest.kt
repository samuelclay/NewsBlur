package com.newsblur.activity

import android.view.View
import androidx.appcompat.widget.AppCompatImageButton
import androidx.constraintlayout.widget.ConstraintLayout
import com.newsblur.databinding.ActivityReadingBinding
import com.newsblur.util.UIUtils
import androidx.lifecycle.LifecycleCoroutineScope
import androidx.lifecycle.lifecycleScope
import com.newsblur.database.ReadingAdapter
import com.newsblur.util.executeAsyncTask
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import org.junit.Test

class ReadingToolbarSelectionTest {
    @Test
    fun fullscreenExitRestoresCurrentControlVisibilityWithoutExpandingToolbar() {
        mockkStatic(UIUtils::class)
        try {
            val reading = mockk<Reading>(relaxed = true)
            val binding = mockk<ActivityReadingBinding>(relaxed = true)
            val left = mockk<ConstraintLayout>(relaxed = true)
            val right = mockk<ConstraintLayout>(relaxed = true)
            fun bindField(name: String, value: Any) {
                ActivityReadingBinding::class.java.getDeclaredField(name).apply {
                    isAccessible = true
                    set(binding, value)
                }
            }
            bindField("readingOverlayLeftGroup", left)
            bindField("readingOverlayRightGroup", right)
            bindField("readingOverlaySend", mockk<AppCompatImageButton>(relaxed = true))
            bindField("readingOverlayLeftSeparator", mockk<View>(relaxed = true))
            Reading::class.java.getDeclaredField("binding").apply {
                isAccessible = true
                set(reading, binding)
            }
            every { binding.root.measuredWidth } returns 0
            every { reading.runOnUiThread(any()) } answers { firstArg<Runnable>().run() }
            every { reading.enableOverlays() } answers { callOriginal() }
            every { reading["setOverlayAlpha"](any<Float>()) } answers { callOriginal() }
            every { UIUtils.setViewAlpha(any(), any(), any()) } returns Unit
            for (fraction in listOf(0f, 1f, 0.5f)) {
                Reading::class.java.getDeclaredField("toolbarVisibleFraction").apply {
                    isAccessible = true
                    setFloat(reading, fraction)
                }
                reading.enableOverlays()
                verify { UIUtils.setViewAlpha(left, fraction, true) }
                verify { UIUtils.setViewAlpha(right, fraction, true) }
            }
        } finally {
            unmockkStatic(UIUtils::class)
        }
    }

    @Test
    fun storySelectionDoesNotForceToolbarVisibleAfterBackgroundWork() {
        mockkStatic("androidx.lifecycle.LifecycleOwnerKt", "com.newsblur.util.ExtensionsKt")
        try {
            val reading = mockk<Reading>(relaxed = true)
            val adapter = mockk<ReadingAdapter>(relaxed = true)
            val scope = mockk<LifecycleCoroutineScope>(relaxed = true)
            every { adapter.getStory(any()) } returns null
            Reading::class.java.getDeclaredField("readingAdapter").apply {
                isAccessible = true
                set(reading, adapter)
            }
            every { reading.lifecycleScope } returns scope
            every { scope.executeAsyncTask<Any?>(any(), any(), any()) } answers {
                // Reading.kt must preserve visibility even when a delayed selection finishes.
                val background = thirdArg<suspend () -> Any?>()
                runBlocking { background() }
                Job()
            }
            every { reading.onPageSelected(any()) } answers { callOriginal() }

            reading.onPageSelected(1)
            reading.onPageSelected(20)
            reading.onPageSelected(0)

            verify(exactly = 0) { reading.enableOverlays() }
        } finally {
            unmockkStatic("androidx.lifecycle.LifecycleOwnerKt", "com.newsblur.util.ExtensionsKt")
        }
    }
}
