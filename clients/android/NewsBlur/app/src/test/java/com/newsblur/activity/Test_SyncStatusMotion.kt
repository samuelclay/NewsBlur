package com.newsblur.activity

import android.view.View
import android.view.ViewPropertyAnimator
import android.widget.LinearLayout
import android.widget.TextView
import com.newsblur.R
import com.newsblur.databinding.ActivityMainBinding
import com.newsblur.fragment.FolderListFragment
import com.newsblur.keyboard.KeyboardManager
import com.newsblur.onboarding.SetupQueue
import com.newsblur.service.SyncServiceState
import com.newsblur.util.UIUtils
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import com.newsblur.service.NbSyncManager
import com.newsblur.service.NBSync
import com.newsblur.service.UnreadsSubService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import io.mockk.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class Test_SyncStatusMotion {
    @Test fun test_unread_download_progress_is_visible_until_all_stories_are_synced() {
        val state = com.newsblur.service.DefaultSyncServiceState()
        val f = Fixture()
        f.useState(state)
        mockkObject(UnreadsSubService.Companion)
        try {
            every { f.main.resources.getString(R.string.sync_status_unreads) } returns "Syncing %s stories"
            every { UnreadsSubService.pendingCount } returns "12"
            state.setServiceState(com.newsblur.service.ServiceState.UnreadsSync)
            f.invoke("updateStatusIndicators")
            verify(exactly = 1) { f.text.text = "Syncing 12 stories" }
            every { UnreadsSubService.pendingCount } returns "3"
            f.invoke("updateStatusIndicators")
            verify(exactly = 1) { f.text.text = "Syncing 3 stories" }
            assertTrue(f.delayed.isEmpty())
            state.setServiceState(com.newsblur.service.ServiceState.Idle)
            f.invoke("updateStatusIndicators")
            f.delayed.last().first.run()
            verify(exactly = 1) { f.text.text = "All Done" }
        } finally {
            unmockkObject(UnreadsSubService.Companion)
        }
    }

    @Test fun test_paused_visible_banner_receives_completion_without_general_sync_updates() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        val f = Fixture()
        val lifecycle = LifecycleRegistry.createUnsafe(f.main)
        every { f.main.lifecycle } returns lifecycle
        every { f.main.startSyncObservers() } answers { callOriginal() }
        every { f.main["handleSyncUpdate"](any<NBSync>()) } answers { callOriginal() }
        every { f.main["shouldObserveSyncStatusWhileStarted"]() } answers { callOriginal() }
        every { f.main["handleVisibleSyncStatus"]() } answers { callOriginal() }
        every { f.main.handleUpdate(any()) } answers { callOriginal() }
        try {
            lifecycle.currentState = Lifecycle.State.CREATED
            f.main.startSyncObservers()
            runCurrent()
            lifecycle.currentState = Lifecycle.State.RESUMED
            runCurrent()
            every { f.sync.getSyncStatusMessage(f.main, false) } returns "Counting is difficult"
            NbSyncManager.submitUpdate(NbSyncManager.UPDATE_STATUS)
            runCurrent()
            verify(exactly = 1) { f.text.text = "Counting is difficult" }

            lifecycle.currentState = Lifecycle.State.STARTED
            runCurrent()
            every { f.sync.getSyncStatusMessage(f.main, false) } returns null
            NbSyncManager.submitUpdate(NbSyncManager.UPDATE_STATUS or NbSyncManager.UPDATE_DB_READY or NbSyncManager.UPDATE_STORY)
            runCurrent()
            assertEquals("The visible paused banner must receive the worker's idle event", 1, f.delayed.size)
            f.delayed.single().first.run()
            verify(exactly = 1) { f.text.text = "All Done" }
            verify(exactly = 1) { f.main.handleUpdate(any()) }

            lifecycle.currentState = Lifecycle.State.CREATED
            runCurrent()
            every { f.sync.getSyncStatusMessage(f.main, false) } returns "A stopped screen must not redraw"
            NbSyncManager.submitUpdate(NbSyncManager.UPDATE_STATUS)
            runCurrent()
            verify(exactly = 0) { f.text.text = "A stopped screen must not redraw" }
        } finally {
            lifecycle.currentState = Lifecycle.State.DESTROYED
            runCurrent()
            Dispatchers.resetMain()
        }
    }
    @Test fun test_reader_page_jobs_do_not_restart_done_or_announce_global_completion() {
        val state = com.newsblur.service.DefaultSyncServiceState()
        val f = Fixture()
        f.useState(state)
        repeat(3) {
            state.setServiceState(com.newsblur.service.ServiceState.StorySync)
            f.invoke("updateStatusIndicators")
            state.setServiceState(com.newsblur.service.ServiceState.Idle)
            f.invoke("updateStatusIndicators")
        }
        assertTrue("Reader navigation must not create global Done timers", f.delayed.isEmpty())
        verify(exactly = 0) { f.text.text = "Fetching fresh stories…" }

        state.setServiceState(com.newsblur.service.ServiceState.RecountsSync)
        f.invoke("updateStatusIndicators")
        state.setServiceState(com.newsblur.service.ServiceState.Idle)
        f.invoke("updateStatusIndicators")
        f.delayed.last().first.run()
        val doneTimer = f.delayed.last()
        assertEquals(5000L, doneTimer.second)
        state.setServiceState(com.newsblur.service.ServiceState.StorySync)
        f.invoke("updateStatusIndicators")
        state.setServiceState(com.newsblur.service.ServiceState.Idle)
        f.invoke("updateStatusIndicators")
        assertEquals("A page fetch must not replace or extend the Done hold", doneTimer, f.delayed.last())
        verify(exactly = 1) { f.text.text = "All Done" }
        assertTrue(f.flag("isShowingDoneSyncStatus"))
    }

    @Test fun test_global_count_status_survives_interleaved_reader_jobs_until_worker_idle() {
        val state = com.newsblur.service.DefaultSyncServiceState()
        val f = Fixture()
        f.useState(state)
        state.setServiceState(com.newsblur.service.ServiceState.RecountsSync)
        f.invoke("updateStatusIndicators")
        state.setServiceState(com.newsblur.service.ServiceState.StorySync)
        f.invoke("updateStatusIndicators")
        assertTrue(f.flag("hasSeenActiveSyncStatus"))
        assertTrue(f.delayed.isEmpty())
        verify(exactly = 0) { f.text.text = "Fetching fresh stories…" }
        state.setServiceState(com.newsblur.service.ServiceState.Idle)
        f.invoke("updateStatusIndicators")
        f.delayed.last().first.run()
        verify(exactly = 1) { f.text.text = "All Done" }
    }

    @Test fun test_offline_status_is_not_suppressed_by_reader_work() {
        val f = Fixture()
        every { f.sync.isStoryContentSyncRunning() } returns true
        f.status("Offline")
        verify(exactly = 1) { f.text.text = "Offline" }
        assertFalse(f.flag("hasSeenActiveSyncStatus"))
        assertTrue(f.delayed.isEmpty())
    }
    @Before fun prepare() {
        mockkStatic(UIUtils::class, com.newsblur.util.Log::class)
        every { UIUtils.dp2px(any(), any<Int>()) } returns 20
        every { UIUtils.towardEndSign(any()) } returns 1f
    }
    @After fun cleanUp() { unmockkStatic(UIUtils::class, com.newsblur.util.Log::class) }

    @Test fun test_count_updates_do_not_restart_the_visible_banner_entrance() {
        val f = Fixture()
        f.show("Counting is difficult")
        f.show("Counting is difficult")
        verify(exactly = 0) { f.animator.start() }
        verify(exactly = 0) { f.animator.cancel() }
    }

    @Test fun test_updates_during_pending_and_running_entrance_start_only_once() {
        val f = Fixture(View.GONE)
        f.show("Counting is difficult")
        f.show("Counting is difficult")
        f.runPosts()
        f.show("Counting 100 feeds")
        verify(exactly = 1) { f.animator.start() }
        verify(exactly = 1) { f.animator.cancel() }
        verify { f.text.text = "Counting 100 feeds" }
    }

    @Test fun test_all_done_holds_then_exits_once_despite_repeated_status_polls() {
        val f = Fixture()
        f.status("Counting is difficult")
        f.finishCounting()
        f.status(null)
        assertEquals(listOf(300L, 5000L), f.delayed.map { it.second })
        verify { f.text.text = "All Done" }
        verify(exactly = 0) { f.animator.start() }
        f.delayed.last().first.run()
        f.runPosts()
        f.status(null)
        verify(exactly = 1) { f.animator.start() }
        f.endActions.last().run()
        assertEquals(View.GONE, f.visibility)
    }

    @Test fun test_phase_gap_does_not_briefly_announce_done_or_restart_banner() {
        val f = Fixture()
        f.status("Counting is difficult")
        f.status(null)
        f.status(null)
        assertEquals(1, f.delayed.size)
        val staleCompletion = f.delayed.single().first
        f.status("Fetching fresh stories")
        staleCompletion.run()
        verify(exactly = 0) { f.text.text = "All Done" }
        verify(exactly = 0) { f.animator.start() }
        assertTrue(f.flag("hasSeenActiveSyncStatus"))
    }

    @Test fun test_completion_rechecks_worker_even_if_new_status_was_not_delivered_yet() {
        val f = Fixture()
        f.status("Counting is difficult")
        f.status(null)
        every { f.sync.isSyncRunning() } returns true
        f.delayed.single().first.run()
        verify(exactly = 0) { f.text.text = "All Done" }
        assertTrue(f.flag("hasSeenActiveSyncStatus"))
    }

    @Test fun test_stale_done_timer_and_exit_cannot_hide_new_counting_phase() {
        val f = Fixture()
        f.status("Counting is difficult")
        f.finishCounting()
        val staleTimer = f.delayed.last().first
        staleTimer.run()
        f.runPosts()
        val staleExit = f.endActions.last()
        f.status("Counting again")
        f.runPosts()
        staleTimer.run()
        staleExit.run()
        assertEquals(View.VISIBLE, f.visibility)
        assertFalse(f.flag("isShowingDoneSyncStatus"))
        verify { f.text.text = "Counting again" }
    }

    @Test fun test_pending_exit_post_cannot_start_after_new_counting_phase() {
        val f = Fixture()
        f.status("Counting is difficult")
        f.finishCounting()
        f.delayed.last().first.run()
        f.status("Counting again")
        f.runPosts()
        verify(exactly = 1) { f.animator.start() }
        assertTrue(f.endActions.isEmpty())
        assertEquals(View.VISIBLE, f.visibility)
    }

    @Test fun test_missing_status_during_active_count_keeps_spinner() {
        val f = Fixture()
        f.status("Counting is difficult")
        every { f.sync.isSyncRunning() } returns true
        f.status(null)
        assertTrue(f.delayed.isEmpty())
        assertTrue(f.flag("hasSeenActiveSyncStatus"))
        every { f.sync.isSyncRunning() } returns false
        f.finishCounting()
        verify { f.text.text = "All Done" }
        verify(exactly = 0) { f.animator.start() }
    }

    @Test fun test_message_less_story_and_background_phases_finish_only_at_idle() {
        val state = com.newsblur.service.DefaultSyncServiceState()
        val f = Fixture()
        every { f.sync.isSyncRunning() } answers { state.isSyncRunning() }
        f.status("Counting is difficult")
        for (phase in listOf(com.newsblur.service.ServiceState.StorySync,
                             com.newsblur.service.ServiceState.UnreadsSync,
                             com.newsblur.service.ServiceState.ImagePrefetchSync)) {
            state.setServiceState(phase)
            f.status(null)
            assertTrue(f.delayed.isEmpty())
        }
        state.setServiceState(com.newsblur.service.ServiceState.Idle)
        f.finishCounting()
        verify { f.text.text = "All Done" }
        verify(exactly = 0) { f.animator.start() }
    }

    @Test fun test_pausing_visible_tablet_banner_preserves_active_count() {
        val f = Fixture()
        f.status("Counting is difficult")
        every { f.main["onPause"]() } answers { callOriginal() }
        try {
            f.invoke("onPause")
        } catch (error: java.lang.reflect.InvocationTargetException) {
            // Test_SyncStatusMotion.kt executes Main.java's lifecycle body; the JVM SDK stub ends at super.onPause.
            assertEquals("Method onPause in android.app.Activity not mocked. See https://developer.android.com/r/studio-ui/build/not-mocked for details.", error.cause?.message)
        }
        assertEquals(View.VISIBLE, f.visibility)
        assertTrue(f.flag("hasSeenActiveSyncStatus"))
        // Test_SyncStatusMotion.kt delivers the same service status after the tablet pane resumes.
        f.status("Counting is difficult")
        f.finishCounting()
        verify { f.text.text = "All Done" }
        verify(exactly = 0) { f.animator.start() }
    }

    private class Fixture(initialVisibility: Int = View.VISIBLE) {
        val main = mockk<Main>(relaxed = true)
        private val binding = mockk<ActivityMainBinding>(relaxed = true)
        private val container = mockk<LinearLayout>(relaxed = true)
        val text = mockk<TextView>(relaxed = true)
        val animator = mockk<ViewPropertyAnimator>(relaxed = true)
        val sync = mockk<SyncServiceState>(relaxed = true)
        private val posts = mutableListOf<Runnable>()
        val delayed = mutableListOf<Pair<Runnable, Long>>()
        val endActions = mutableListOf<Runnable>()
        var visibility = initialVisibility
        private val show = Main::class.java.declaredMethods.single { it.name == "showSyncStatusIndicator" }.apply { isAccessible = true }
        private val spinner = show.parameterTypes[1].enumConstants!!.single { it.toString() == "SPINNER" }
        init {
            setBinding("mainSyncStatusContainer", container)
            setBinding("mainSyncStatusText", text)
            setBinding("mainSyncStatusSpinner", mockk<com.google.android.material.progressindicator.CircularProgressIndicator>(relaxed = true))
            setBinding("mainSyncStatusDoneIcon", mockk<android.widget.ImageView>(relaxed = true))
            setBinding("content", mockk<androidx.swiperefreshlayout.widget.SwipeRefreshLayout>(relaxed = true))
            set("binding", binding)
            set("setupQueue", mockk<SetupQueue>(relaxed = true))
            set("keyboardManager", mockk<KeyboardManager>(relaxed = true))
            val folder = FolderListFragment()
            FolderListFragment::class.java.getDeclaredField("firstCursorSeenYet").apply { isAccessible = true }.set(folder, true)
            set("folderFeedList", folder)
            NbActivity::class.java.getDeclaredField("syncServiceState").apply { isAccessible = true }.set(main, sync)
            every { main.getString(R.string.loading) } returns "Loading"
            every { main.getString(R.string.sync_status_done) } returns "All Done"
            every { main.getString(R.string.sync_status_offline) } returns "Offline"
            every { container.visibility } answers { visibility }
            every { container.visibility = any() } answers { visibility = firstArg() }
            every { container.animate() } returns animator
            every { container.post(any()) } answers { posts.add(firstArg()); true }
            every { container.postDelayed(any(), any()) } answers { delayed.add(firstArg<Runnable>() to secondArg<Long>()); true }
            every { animator.translationX(any()) } returns animator
            every { animator.alpha(any()) } returns animator
            every { animator.setInterpolator(any()) } returns animator
            every { animator.setDuration(any()) } returns animator
            every { animator.withEndAction(any()) } answers { firstArg<Runnable?>()?.let { endActions.add(it) }; animator }
            for (accessory in show.parameterTypes[1].enumConstants!!) {
                every { main["showSyncStatusIndicator"](any<String>(), accessory) } answers { callOriginal() }
            }
            every { main["hideSyncStatusIndicator"](any<Boolean>()) } answers { callOriginal() }
            for (method in listOf("cancelPendingSyncStatusHide", "scheduleDoneSyncStatusHide", "updateStatusIndicators", "scheduleSyncStatusCompletion", "cancelPendingSyncStatusCompletion")) {
                every { main[method]() } answers { callOriginal() }
            }
            every { main["isOfflineSyncStatus"](matchNullable<String> { true }) } answers { callOriginal() }
        }
        fun show(message: String) { show.invoke(main, message, spinner) }
        fun useState(state: SyncServiceState) {
            NbActivity::class.java.getDeclaredField("syncServiceState").apply { isAccessible = true }.set(main, state)
            every { main.resources.getString(R.string.sync_status_stories) } returns "Fetching fresh stories…"
            every { main.resources.getString(R.string.sync_status_recounts) } returns "Counting is difficult"
        }
        fun status(message: String?) {
            every { sync.getSyncStatusMessage(main, false) } returns message
            invoke("updateStatusIndicators")
        }
        fun finishCounting() { status(null); delayed.last().first.run() }
        fun runPosts() { val pending = posts.toList(); posts.clear(); pending.forEach { it.run() } }
        fun invoke(name: String) { Main::class.java.getDeclaredMethod(name).apply { isAccessible = true }.invoke(main) }
        fun flag(name: String): Boolean = Main::class.java.getDeclaredField(name).apply { isAccessible = true }.getBoolean(main)
        private fun set(name: String, value: Any) { Main::class.java.getDeclaredField(name).apply { isAccessible = true }.set(main, value) }
        private fun setBinding(name: String, value: Any) { ActivityMainBinding::class.java.getDeclaredField(name).apply { isAccessible = true }.set(binding, value) }
    }
}
