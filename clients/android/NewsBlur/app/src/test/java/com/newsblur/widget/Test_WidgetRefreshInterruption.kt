package com.newsblur.widget

import com.newsblur.domain.Story
import com.newsblur.network.StoryApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.Log
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import kotlinx.coroutines.awaitCancellation
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.locks.ReentrantLock

class Test_WidgetRefreshInterruption {
    @After
    fun tear_down() = unmockkAll()

    @Test
    fun test_cancelled_launcher_refresh_preserves_stories_and_interrupt_without_crashing() {
        mockkStatic(Log::class)
        every { Log.d(any<Any>(), any()) } returns Unit
        val prefs = mockk<PrefsRepo>(relaxed = true)
        every { prefs.getUniqueLoginKey() } returns "widget-test"
        every { prefs.getWidgetFeedIds() } returns null
        val api = mockk<StoryApi>()
        val fetching = CountDownLatch(1)
        coEvery { api.getStories(any(), any(), any(), any(), any()) } coAnswers {
            fetching.countDown()
            awaitCancellation()
        }
        val factory = mockk<WidgetRemoteViewsFactory>()
        every { factory.onDataSetChanged() } answers { callOriginal() }
        val stories = mutableListOf(Story())
        val lock = ReentrantLock()
        setField(factory, "prefsRepo", prefs)
        setField(factory, "storyApi", api)
        setField(factory, "storyItems", stories)
        setField(factory, "storiesLock", lock)
        val failure = AtomicReference<Throwable>()
        val interrupted = AtomicBoolean()
        val worker = Thread {
            try {
                factory.onDataSetChanged()
                interrupted.set(Thread.currentThread().isInterrupted)
            } catch (throwable: Throwable) {
                failure.set(throwable)
            }
        }
        worker.start()
        try {
            assertTrue("Widget refresh did not request stories", fetching.await(5, TimeUnit.SECONDS))
            worker.interrupt()
            worker.join(5000)
            assertFalse("Widget refresh did not stop", worker.isAlive)
            assertNull("Launcher cancellation escaped the widget callback", failure.get())
            assertTrue("Widget callback must preserve the caller's interrupt", interrupted.get())
            assertEquals(1, stories.size)
            assertTrue("Widget refresh retained its data lock", lock.tryLock())
            lock.unlock()
        } finally {
            worker.interrupt()
            worker.join(5000)
        }
    }

    private fun setField(factory: WidgetRemoteViewsFactory, name: String, value: Any) {
        // WidgetRemoteViewsFactory.kt's callback runs with real coroutines and no Android service.
        WidgetRemoteViewsFactory::class.java.getDeclaredField(name)
            .apply { isAccessible = true }.set(factory, value)
    }
}
