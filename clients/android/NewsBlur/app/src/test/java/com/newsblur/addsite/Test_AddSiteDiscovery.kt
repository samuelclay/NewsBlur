package com.newsblur.addsite

import androidx.lifecycle.SavedStateHandle
import com.google.gson.JsonParser
import com.newsblur.MainDispatcherRule
import com.newsblur.discover.DiscoveryApi
import com.newsblur.discover.DiscoveryTab
import com.newsblur.discover.DiscoveryViewModel
import com.newsblur.network.FeedApi
import com.newsblur.preference.DiscoveryPreferencesFixture
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class Test_AddSiteDiscovery {
    @get:Rule val main = MainDispatcherRule()
    private val api = mockk<DiscoveryApi>()
    private val feeds = mockk<FeedApi>()
    private val viewPreferences = DiscoveryPreferencesFixture().preference

    private fun model(saved: SavedStateHandle, freshLaunch: Boolean = false) =
        DiscoveryViewModel(api, feeds, saved, viewPreferences).apply {
            workerDispatcher = main.dispatcher
            if (freshLaunch) seedFolder(saved[DiscoveryViewModel.FOLDER] ?: com.newsblur.util.AppConstants.ROOT_FOLDER)
        }

    @Test fun test_shortcuts_open_their_destination_with_the_chosen_folder() = runTest {
        coEvery { api.request(any(), any(), any()) } returns JsonParser.parseString("{}").asJsonObject
        AddSiteDiscoveryShortcut.entries.forEach { shortcut ->
            val saved = SavedStateHandle(mapOf(DiscoveryViewModel.TAB to shortcut.tab.name, DiscoveryViewModel.FOLDER to "Reading ▸ Science"))
            val model = model(saved, freshLaunch = true)
            model.start()
            advanceUntilIdle()
            assertEquals(shortcut.tab, model.state.value.tab)
            assertEquals("Reading ▸ Science", model.state.value.folder)
            assertEquals("", model.state.value.page.query)
        }
        assertEquals(DiscoveryTab.SEARCH, AddSiteDiscoveryShortcut.TRENDING.tab)
        coVerify(exactly = 1) { api.request("/discover/trending", any(), false) }
    }

    @Test fun test_recreation_preserves_changes_after_launching_from_a_shortcut() = runTest {
        coEvery { api.request(any(), any(), any()) } returns JsonParser.parseString("{}").asJsonObject
        val saved = SavedStateHandle(mapOf(DiscoveryViewModel.TAB to DiscoveryTab.REDDIT.name, DiscoveryViewModel.FOLDER to "Reading"))
        val model = model(saved, freshLaunch = true)
        model.start()
        model.selectTab(DiscoveryTab.PODCASTS)
        model.queryChanged("science")
        model.chooseFolder("Podcasts")
        advanceUntilIdle()

        val restored = model(saved)
        restored.start()
        advanceUntilIdle()
        assertEquals(DiscoveryTab.PODCASTS, restored.state.value.tab)
        assertEquals("science", restored.state.value.page.query)
        assertEquals("Podcasts", restored.state.value.folder)
    }
}
