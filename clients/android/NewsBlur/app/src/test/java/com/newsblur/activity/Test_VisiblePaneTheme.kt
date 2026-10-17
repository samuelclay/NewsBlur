package com.newsblur.activity

import android.content.Context
import android.content.SharedPreferences
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.PrefConstants
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.After
import org.junit.Before
import org.junit.Test

class Test_VisiblePaneTheme {
    @Before
    fun setUp() {
        mockkStatic(UIUtils::class)
        every { UIUtils.restartActivity(any()) } returns Unit
    }

    @After
    fun tearDown() {
        unmockkStatic(UIUtils::class)
    }

    @Test
    fun test_already_resumed_peers_each_reload_once_when_the_theme_changes() {
        val panes = listOf(Fixture(), Fixture())
        panes.forEach { it.resume() }
        panes.forEach {
            it.theme = ThemeValue.DARK
            it.notify(PrefConstants.THEME)
            it.notify(PrefConstants.THEME)
            it.notify(PrefConstants.THEME_DARK_VARIANT)
        }
        panes.forEach { verify(exactly = 1) { UIUtils.restartActivity(it.activity) } }
    }

    @Test
    fun test_paused_pane_defers_theme_refresh_until_it_resumes() {
        val pane = Fixture()
        pane.resume()
        invoke(pane.activity, "stopObservingThemeChanges")
        pane.theme = ThemeValue.BLACK
        // NbActivity.kt must ignore a callback queued before the listener was unregistered.
        pane.notify(PrefConstants.THEME)
        verify(exactly = 0) { UIUtils.restartActivity(pane.activity) }
        verify { pane.preferences.unregisterOnSharedPreferenceChangeListener(pane.listener.captured) }

        pane.resume()

        verify(exactly = 1) { UIUtils.restartActivity(pane.activity) }
    }

    @Test
    fun test_unrelated_preferences_do_not_recreate_visible_panes() {
        val pane = Fixture()
        pane.resume()
        pane.notify(PrefConstants.STORY_LIST_SPLIT_RATIO)
        verify(exactly = 0) { UIUtils.restartActivity(pane.activity) }
    }

    private class Fixture {
        val activity = mockk<NbActivity>(relaxed = true)
        val preferences = mockk<SharedPreferences>(relaxed = true)
        val listener = slot<SharedPreferences.OnSharedPreferenceChangeListener>()
        private val repo = mockk<PrefsRepo>(relaxed = true)
        var theme = ThemeValue.LIGHT

        init {
            NbActivity::class.java.getDeclaredField("prefsRepo").apply {
                isAccessible = true
                set(activity, repo)
            }
            NbActivity::class.java.getDeclaredField("lastTheme").apply {
                isAccessible = true
                set(activity, ThemeValue.LIGHT)
            }
            every { repo.getSelectedTheme() } answers { theme }
            every { activity.prefsRepo } returns repo
            every { activity.getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE) } returns preferences
            every { preferences.registerOnSharedPreferenceChangeListener(capture(listener)) } just Runs
            every { activity["startObservingThemeChanges"]() } answers { callOriginal() }
            every { activity["stopObservingThemeChanges"]() } answers { callOriginal() }
            every { activity["refreshThemeIfChanged"]() } answers { callOriginal() }
            every { activity["onSharedPreferenceChanged"](any<SharedPreferences>(), any<String>()) } answers { callOriginal() }
        }

        fun resume() = invoke(activity, "startObservingThemeChanges")

        fun notify(key: String) = listener.captured.onSharedPreferenceChanged(preferences, key)
    }

    companion object {
        private fun invoke(activity: NbActivity, method: String) {
            NbActivity::class.java.getDeclaredMethod(method).apply {
                isAccessible = true
                invoke(activity)
            }
        }
    }
}
