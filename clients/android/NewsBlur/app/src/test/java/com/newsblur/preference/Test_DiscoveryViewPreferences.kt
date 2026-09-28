package com.newsblur.preference

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModelStore
import com.newsblur.MainDispatcherRule
import com.newsblur.discover.DiscoveryViewModel
import com.newsblur.viewModel.DiscoverFeedViewMode
import com.newsblur.viewModel.DiscoverFeedsViewModel
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class Test_DiscoveryViewPreferences {
    @get:Rule val main = MainDispatcherRule()

    private fun discovery(preferences: DiscoveryViewPreferences, saved: SavedStateHandle = SavedStateHandle()) =
        DiscoveryViewModel(mockk(), mockk(), saved, preferences)

    private fun related(preferences: DiscoveryViewPreferences) = DiscoverFeedsViewModel(preferences, mockk())

    @Test fun test_absent_and_invalid_preferences_default_both_surfaces_to_list() {
        for (stored in listOf(null, "obsolete")) {
            val preferences = DiscoveryPreferencesFixture(stored).preference
            assertFalse(discovery(preferences).state.value.grid)
            assertEquals(DiscoverFeedViewMode.LIST, related(preferences).uiState.value.viewMode)
        }
    }

    @Test fun test_existing_explicit_choices_survive_cold_instances_and_stale_saved_state() {
        for (stored in listOf("grid", "list")) {
            val fixture = DiscoveryPreferencesFixture(stored)
            val expectedGrid = stored == "grid"
            val staleSaved = SavedStateHandle(mapOf("grid" to !expectedGrid))
            assertEquals(expectedGrid, discovery(DiscoveryViewPreferences(fixture.shared), staleSaved).state.value.grid)
            assertEquals(
                if (expectedGrid) DiscoverFeedViewMode.GRID else DiscoverFeedViewMode.LIST,
                related(DiscoveryViewPreferences(fixture.shared)).uiState.value.viewMode,
            )
        }
        val noChoice = DiscoveryPreferencesFixture().preference
        assertFalse(discovery(noChoice, SavedStateHandle(mapOf("grid" to true))).state.value.grid)
    }

    @Test fun test_toggles_persist_both_ways_and_update_the_other_retained_view_model() = runTest {
        val fixture = DiscoveryPreferencesFixture()
        val discovery = discovery(fixture.preference)
        val related = related(DiscoveryViewPreferences(fixture.shared))
        runCurrent()

        discovery.toggleGrid()
        assertEquals("grid", fixture.storedMode)
        assertTrue(discovery.state.value.grid)
        runCurrent()
        assertEquals(DiscoverFeedViewMode.GRID, related.uiState.value.viewMode)
        assertTrue(discovery(DiscoveryViewPreferences(fixture.shared)).state.value.grid)

        related.setViewMode(DiscoverFeedViewMode.LIST)
        assertEquals("list", fixture.storedMode)
        runCurrent()
        assertFalse(discovery.state.value.grid)
        assertFalse(discovery(DiscoveryViewPreferences(fixture.shared)).state.value.grid)

        related.setViewMode(DiscoverFeedViewMode.GRID)
        runCurrent()
        assertTrue(discovery.state.value.grid)
        discovery.toggleGrid()
        runCurrent()
        assertEquals(DiscoverFeedViewMode.LIST, related.uiState.value.viewMode)
        assertEquals(DiscoverFeedViewMode.LIST, related(DiscoveryViewPreferences(fixture.shared)).uiState.value.viewMode)
    }

    @Test fun test_clearing_shared_preferences_restores_list_in_retained_views() = runTest {
        val fixture = DiscoveryPreferencesFixture("grid")
        val discovery = discovery(fixture.preference)
        val related = related(fixture.preference)
        runCurrent()
        fixture.clear()
        runCurrent()
        assertFalse(discovery.state.value.grid)
        assertEquals(DiscoverFeedViewMode.LIST, related.uiState.value.viewMode)
    }

    @Test fun test_cleared_view_models_unregister_preference_listeners() = runTest {
        val fixture = DiscoveryPreferencesFixture()
        val store = ViewModelStore()
        store.put("discovery", discovery(fixture.preference))
        store.put("related", related(fixture.preference))
        runCurrent()
        assertEquals(3, fixture.listeners.size)
        store.clear()
        runCurrent()
        assertTrue(fixture.listeners.isEmpty())
    }
}
