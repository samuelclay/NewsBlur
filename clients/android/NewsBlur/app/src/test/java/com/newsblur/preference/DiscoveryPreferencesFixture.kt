package com.newsblur.preference

import android.content.SharedPreferences
import com.newsblur.util.PrefConstants
import io.mockk.every
import io.mockk.mockk

internal class DiscoveryPreferencesFixture(initialMode: String? = null, account: String = "account-a") {
    private val values = mutableMapOf<String, String>()
    val listeners = mutableSetOf<SharedPreferences.OnSharedPreferenceChangeListener>()
    var notifyChanges = true
    val shared = mockk<SharedPreferences>(relaxed = true)
    val preference: DiscoveryViewPreferences
    val storedMode: String? get() = values[VIEW_MODE]

    init {
        initialMode?.let { values[VIEW_MODE] = it }
        values[PrefConstants.PREF_UNIQUE_LOGIN] = account
        val pending = mutableMapOf<String, String?>()
        val editor = mockk<SharedPreferences.Editor>(relaxed = true)
        every { editor.putString(any(), any()) } answers {
            pending[firstArg()] = secondArg()
            editor
        }
        every { editor.remove(any()) } answers {
            pending[firstArg()] = null
            editor
        }
        every { editor.apply() } answers {
            val changes = pending.toMap()
            changes.forEach { (key, value) -> if (value == null) values.remove(key) else values[key] = value }
            pending.clear()
            if (notifyChanges) {
                changes.keys.forEach { key -> listeners.toList().forEach { it.onSharedPreferenceChanged(shared, key) } }
            }
        }
        every { shared.getString(any(), any()) } answers { values[firstArg()] ?: secondArg() }
        every { shared.edit() } returns editor
        every { shared.registerOnSharedPreferenceChangeListener(any()) } answers { listeners.add(firstArg()); Unit }
        every { shared.unregisterOnSharedPreferenceChangeListener(any()) } answers { listeners.remove(firstArg()); Unit }
        preference = DiscoveryViewPreferences(shared)
    }

    fun clear() {
        values.clear()
        listeners.toList().forEach { it.onSharedPreferenceChanged(shared, null) }
    }

    fun login(account: String) {
        shared.edit().putString(PrefConstants.PREF_UNIQUE_LOGIN, account).apply()
    }

    private companion object {
        const val VIEW_MODE = "discover_feeds_view_mode"
    }
}
