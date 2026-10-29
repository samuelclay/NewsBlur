package com.newsblur.preference

import android.content.SharedPreferences
import com.google.gson.JsonParser
import com.newsblur.network.UserApi
import com.newsblur.util.PrefConstants
import com.newsblur.util.StoryButton
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Test_ListenPreferences.kt checks how ListenPreferences.kt carries the old device-only Ask AI toggle to the server. */
class Test_ListenPreferences {
    private val prefs = InMemoryPreferences()
    private val userApi = mockk<UserApi>()
    private val listenPreferences =
        ListenPreferences(prefs, userApi).apply {
            elapsedRealtime = { 1_000_000L }
        }

    // The web preferences dialog saves Ask AI as shown for almost everyone.
    private val serverShowsAskAi = JsonParser.parseString("""{"show_sideoption_ask_ai": true}""").asJsonObject

    @Test
    fun test_local_hide_wins_over_the_servers_shown_value() =
        runTest {
            prefs.edit().putBoolean(PrefConstants.SHOW_ASK_AI, false).commit()
            coEvery { userApi.setPreferences(any()) } returns true

            listenPreferences.applyServerPreferences(serverShowsAskAi)

            coVerify(exactly = 1) { userApi.setPreferences(mapOf(StoryButton.ASK_AI.prefKey to "false")) }
            assertFalse(listenPreferences.isStoryButtonVisible(StoryButton.ASK_AI))
            assertFalse(prefs.contains(PrefConstants.SHOW_ASK_AI))
        }

    @Test
    fun test_failed_send_keeps_the_legacy_key_and_the_local_hide() =
        runTest {
            prefs.edit().putBoolean(PrefConstants.SHOW_ASK_AI, false).commit()
            coEvery { userApi.setPreferences(any()) } returns false
            // ListenPreferences.kt logs the failed save through android.util.Log.
            mockkStatic(android.util.Log::class)
            every { android.util.Log.w(any<String>(), any<String>()) } returns 0

            listenPreferences.applyServerPreferences(serverShowsAskAi)

            assertFalse(listenPreferences.isStoryButtonVisible(StoryButton.ASK_AI))
            assertTrue(prefs.contains(PrefConstants.SHOW_ASK_AI))
            unmockkStatic(android.util.Log::class)
        }

    @Test
    fun test_legacy_shown_is_dropped_without_sending_and_the_server_value_applies() =
        runTest {
            prefs.edit().putBoolean(PrefConstants.SHOW_ASK_AI, true).commit()
            val serverHidesAskAi = JsonParser.parseString("""{"show_sideoption_ask_ai": false}""").asJsonObject

            listenPreferences.applyServerPreferences(serverHidesAskAi)

            coVerify(exactly = 0) { userApi.setPreferences(any()) }
            assertFalse(prefs.contains(PrefConstants.SHOW_ASK_AI))
            assertFalse(listenPreferences.isStoryButtonVisible(StoryButton.ASK_AI))
        }

    @Test
    fun test_without_a_legacy_key_the_server_value_applies() =
        runTest {
            listenPreferences.applyServerPreferences(serverShowsAskAi)

            coVerify(exactly = 0) { userApi.setPreferences(any()) }
            assertTrue(listenPreferences.isStoryButtonVisible(StoryButton.ASK_AI))
            assertEquals(true, prefs.getBoolean(StoryButton.ASK_AI.prefKey, false))
        }
}

/** An in-memory SharedPreferences for Test_ListenPreferences.kt, notifying listeners like the real one. */
private class InMemoryPreferences : SharedPreferences {
    private val values = mutableMapOf<String, Any?>()
    private val listeners = mutableSetOf<SharedPreferences.OnSharedPreferenceChangeListener>()

    override fun getAll(): MutableMap<String, *> = values.toMutableMap()

    override fun getString(
        key: String?,
        defValue: String?,
    ): String? = values[key] as? String ?: defValue

    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(
        key: String?,
        defValues: MutableSet<String>?,
    ): MutableSet<String>? = values[key] as? MutableSet<String> ?: defValues

    override fun getInt(
        key: String?,
        defValue: Int,
    ): Int = values[key] as? Int ?: defValue

    override fun getLong(
        key: String?,
        defValue: Long,
    ): Long = values[key] as? Long ?: defValue

    override fun getFloat(
        key: String?,
        defValue: Float,
    ): Float = values[key] as? Float ?: defValue

    override fun getBoolean(
        key: String?,
        defValue: Boolean,
    ): Boolean = values[key] as? Boolean ?: defValue

    override fun contains(key: String?): Boolean = key in values

    override fun edit(): SharedPreferences.Editor = Editor()

    override fun registerOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener) {
        listeners += listener
    }

    override fun unregisterOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener) {
        listeners -= listener
    }

    private inner class Editor : SharedPreferences.Editor {
        private val changes = mutableMapOf<String, Any?>()
        private val removals = mutableSetOf<String>()
        private var clear = false

        override fun putString(
            key: String,
            value: String?,
        ) = apply { changes[key] = value }

        override fun putStringSet(
            key: String,
            values: MutableSet<String>?,
        ) = apply { changes[key] = values }

        override fun putInt(
            key: String,
            value: Int,
        ) = apply { changes[key] = value }

        override fun putLong(
            key: String,
            value: Long,
        ) = apply { changes[key] = value }

        override fun putFloat(
            key: String,
            value: Float,
        ) = apply { changes[key] = value }

        override fun putBoolean(
            key: String,
            value: Boolean,
        ) = apply { changes[key] = value }

        override fun remove(key: String) = apply { removals += key }

        override fun clear() = apply { clear = true }

        override fun commit(): Boolean {
            if (clear) values.clear()
            removals.forEach { values.remove(it) }
            values.putAll(changes)
            (removals + changes.keys).forEach { key ->
                listeners.forEach { it.onSharedPreferenceChanged(this@InMemoryPreferences, key) }
            }
            return true
        }

        override fun apply() {
            commit()
        }
    }
}
