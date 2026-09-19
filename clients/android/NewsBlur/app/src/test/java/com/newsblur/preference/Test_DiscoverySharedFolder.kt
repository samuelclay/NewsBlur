package com.newsblur.preference

import androidx.lifecycle.SavedStateHandle
import com.newsblur.MainDispatcherRule
import com.newsblur.discover.DiscoveryFeed
import com.newsblur.discover.DiscoveryViewModel
import com.newsblur.domain.Feed
import com.newsblur.domain.Folder
import com.newsblur.network.FeedApi
import com.newsblur.network.domain.AddFeedResponse
import com.newsblur.util.AppConstants
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class Test_DiscoverySharedFolder {
    @get:Rule val main = MainDispatcherRule()

    private fun model(
        preference: DiscoveryViewPreferences,
        saved: SavedStateHandle = SavedStateHandle(),
        feedApi: FeedApi = mockk(),
    ) = DiscoveryViewModel(mockk(), feedApi, saved, preference).apply { workerDispatcher = main.dispatcher }

    private fun folder(name: String, vararg parents: String) = Folder().apply {
        this.name = name
        this.parents = parents.toMutableList()
    }

    @Test fun test_folder_choice_updates_the_other_retained_discovery_host() = runTest {
        val fixture = DiscoveryPreferencesFixture()
        val discovery = DiscoveryViewModel(mockk(), mockk(), SavedStateHandle(), fixture.preference)
        val related = DiscoveryViewModel(mockk(), mockk(), SavedStateHandle(), fixture.preference)
        runCurrent()
        related.chooseFolder("Technology - Gadgets")
        runCurrent()
        assertEquals("Technology - Gadgets", discovery.state.value.folder)
        discovery.chooseFolder("Blogs")
        runCurrent()
        assertEquals("Blogs", related.state.value.folder)
    }

    @Test fun test_new_instances_and_stale_saved_or_root_launch_context_keep_latest_shared_folder() = runTest {
        val fixture = DiscoveryPreferencesFixture()
        val related = model(fixture.preference)
        related.chooseFolder("Reading ▸ Science")
        val restored = model(DiscoveryViewPreferences(fixture.shared), SavedStateHandle(mapOf(DiscoveryViewModel.FOLDER to "Old folder")))
        assertEquals("Reading ▸ Science", restored.state.value.folder)
        restored.seedFolder(AppConstants.ROOT_FOLDER)
        restored.seedFolder("")
        assertEquals("Reading ▸ Science", restored.state.value.folder)

        val fresh = model(DiscoveryViewPreferences(fixture.shared), SavedStateHandle(mapOf(DiscoveryViewModel.FOLDER to AppConstants.ROOT_FOLDER)))
        assertEquals("Reading ▸ Science", fresh.state.value.folder)
        fresh.seedFolder("Blogs")
        runCurrent()
        assertEquals("Blogs", related.state.value.folder)
        assertEquals("Blogs", restored.state.value.folder)
        assertEquals("Blogs", model(DiscoveryViewPreferences(fixture.shared)).state.value.folder)
    }

    @Test fun test_actual_folder_metadata_validates_full_paths_and_resets_deleted_folder_everywhere() = runTest {
        val fixture = DiscoveryPreferencesFixture()
        val first = model(fixture.preference)
        val second = model(fixture.preference)
        first.chooseFolder("Reading ▸ Science")
        val folders = listOf(folder("Reading"), folder("Science", "Reading"), folder("Science", "Work"))
        first.setFolders(folders, emptySet())
        runCurrent()
        assertEquals("Reading ▸ Science", first.state.value.folder)
        assertEquals("Reading ▸ Science", second.state.value.folder)
        assertEquals(3, first.state.value.folders.size)

        first.setFolders(listOf(folder("Science", "Work")), emptySet())
        runCurrent()
        assertEquals(AppConstants.ROOT_FOLDER, first.state.value.folder)
        assertEquals(AppConstants.ROOT_FOLDER, second.state.value.folder)
        assertEquals(AppConstants.ROOT_FOLDER, fixture.preference.folderSelection().folder)

        first.chooseFolder("Deleted")
        first.setFolders(emptyList(), emptySet())
        runCurrent()
        assertEquals(AppConstants.ROOT_FOLDER, second.state.value.folder)
        assertTrue(first.state.value.folders.isEmpty())
    }

    @Test fun test_account_switch_and_logout_do_not_restore_or_write_another_accounts_folder() = runTest {
        val fixture = DiscoveryPreferencesFixture()
        val saved = SavedStateHandle(mapOf(DiscoveryViewModel.FOLDER to "Private"))
        val old = model(fixture.preference, saved)
        old.seedFolder("Private")
        old.setFolders(listOf(folder("Private")), emptySet())
        runCurrent()
        fixture.login("account-b")
        runCurrent()
        assertEquals(AppConstants.ROOT_FOLDER, old.state.value.folder)
        assertTrue(old.state.value.folders.isEmpty())

        val next = model(DiscoveryViewPreferences(fixture.shared), saved)
        assertEquals(AppConstants.ROOT_FOLDER, next.state.value.folder)
        next.chooseFolder("Work ▸ Research")
        old.chooseFolder("Private")
        old.setFolders(listOf(folder("Private")), emptySet())
        runCurrent()
        assertEquals("Work ▸ Research", next.state.value.folder)
        assertEquals(AppConstants.ROOT_FOLDER, old.state.value.folder)

        fixture.clear()
        runCurrent()
        assertEquals(AppConstants.ROOT_FOLDER, next.state.value.folder)
        fixture.login("account-c")
        assertEquals(AppConstants.ROOT_FOLDER, model(DiscoveryViewPreferences(fixture.shared), saved).state.value.folder)
    }

    @Test fun test_add_uses_latest_shared_full_path_even_before_observers_receive_it() = runTest {
        val fixture = DiscoveryPreferencesFixture()
        val feedApi = mockk<FeedApi>()
        coEvery { feedApi.addFeed("https://example.com/rss", "Reading ▸ Science") } returns AddFeedResponse().apply {
            code = 1
            feed = Feed().apply { feedId = "42" }
        }
        val discovery = model(fixture.preference, feedApi = feedApi)
        val related = model(fixture.preference)
        runCurrent()
        fixture.notifyChanges = false
        related.chooseFolder("Reading ▸ Science")
        assertEquals(AppConstants.ROOT_FOLDER, discovery.state.value.folder)
        discovery.add(DiscoveryFeed("https://example.com/rss", "Example"))
        runCurrent()
        coVerify(exactly = 1) { feedApi.addFeed("https://example.com/rss", "Reading ▸ Science") }
    }

    @Test fun test_old_account_host_cannot_add_using_the_new_accounts_folder() = runTest {
        val fixture = DiscoveryPreferencesFixture()
        val feedApi = mockk<FeedApi>()
        val old = model(fixture.preference, feedApi = feedApi)
        fixture.login("account-b")
        model(fixture.preference).chooseFolder("New account folder")
        old.add(DiscoveryFeed("https://example.com/rss", "Example"))
        runCurrent()
        coVerify(exactly = 0) { feedApi.addFeed(any(), any()) }
        assertTrue(old.state.value.error.orEmpty().contains("account changed"))
    }
}
