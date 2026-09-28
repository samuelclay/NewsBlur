package com.newsblur.fragment

import android.view.View
import androidx.arch.core.executor.ArchTaskExecutor
import androidx.arch.core.executor.TaskExecutor
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.newsblur.domain.FolderQueryResult
import com.newsblur.viewModel.AllFoldersViewModel
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Test
import org.junit.Before
import org.junit.After

class FolderListStartupTest {
    @Before fun makeLiveDataSynchronous() {
        ArchTaskExecutor.getInstance().setDelegate(object : TaskExecutor() {
            override fun executeOnDiskIO(runnable: Runnable) = runnable.run()
            override fun postToMainThread(runnable: Runnable) = runnable.run()
            override fun isMainThread() = true
        })
    }

    @After fun restoreLiveDataExecutor() {
        ArchTaskExecutor.getInstance().setDelegate(null)
    }

    @Test fun creatingTheViewStartsCachedLoadingWithoutWaitingForSync() {
        val fragment = StartupFragment()
        val vm = mockk<AllFoldersViewModel>(relaxed = true)
        FolderListFragment::class.java.getDeclaredField("allFoldersViewModel").apply { isAccessible = true }.set(fragment, vm)
        every { vm.folders } returns MutableLiveData<FolderQueryResult>()
        every { vm.feeds } returns MutableLiveData()
        every { vm.socialFeeds } returns MutableLiveData()
        every { vm.savedStoryCounts } returns MutableLiveData()
        every { vm.savedSearch } returns MutableLiveData()

        fragment.onViewCreated(mockk<View>(), null)

        verify(exactly = 1) { vm.getData() }
    }

    private class StartupFragment : FolderListFragment() {
        private val owner = mockk<LifecycleOwner>(relaxed = true).also {
            every { it.lifecycle.currentState } returns Lifecycle.State.INITIALIZED
        }

        override fun getViewLifecycleOwner(): LifecycleOwner = owner
    }
}
