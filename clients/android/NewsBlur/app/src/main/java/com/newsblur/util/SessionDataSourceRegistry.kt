package com.newsblur.util

import java.util.LinkedHashMap
import java.util.concurrent.atomic.AtomicLong

object SessionDataSourceRegistry {
    private const val MAX_ENTRIES = 32
    private val nextKey = AtomicLong(0)

    data class Entry(
        val sessionDataSource: SessionDataSource?,
        val storyListSessionDataSource: SessionDataSource?,
    )

    private val entries =
        object : LinkedHashMap<String, Entry>(MAX_ENTRIES, 0.75f, true) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Entry>?): Boolean = size > MAX_ENTRIES
        }

    @JvmStatic
    @Synchronized
    fun register(
        sessionDataSource: SessionDataSource?,
        storyListSessionDataSource: SessionDataSource?,
    ): String? {
        if (sessionDataSource == null && storyListSessionDataSource == null) return null

        val key = nextKey.incrementAndGet().toString(Character.MAX_RADIX)
        entries[key] = Entry(sessionDataSource, storyListSessionDataSource)
        return key
    }

    @JvmStatic
    @Synchronized
    fun get(key: String?): Entry? {
        if (key.isNullOrBlank()) return null
        return entries[key]
    }

    @JvmStatic
    @Synchronized
    fun remove(key: String?) {
        if (key.isNullOrBlank()) return
        entries.remove(key)
    }

    @JvmStatic
    @Synchronized
    fun clearForTests() {
        entries.clear()
        nextKey.set(0)
    }
}
