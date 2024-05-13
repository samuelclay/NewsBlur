package com.newsblur.util

import android.text.TextUtils
import com.newsblur.domain.Story
import java.nio.ByteBuffer
import java.nio.CharBuffer
import java.nio.charset.CodingErrorAction

object StoryUtil {

    @JvmStatic
    fun truncateContent(value: String): String {
        val maxBytes = 1024 * 300 // 300 kbs
        val bytes = value.encodeToByteArray()
        if (bytes.size <= maxBytes) return value
        val byteBuffer = ByteBuffer.wrap(bytes, 0, maxBytes)
        val charBuffer = CharBuffer.allocate(maxBytes)
        val decoder = Charsets.UTF_8.newDecoder()
        decoder.onMalformedInput(CodingErrorAction.IGNORE)
        decoder.decode(byteBuffer, charBuffer, true)
        decoder.flush(charBuffer)
        return String(charBuffer.array(), 0, charBuffer.position())
    }

    @JvmStatic
    fun getStoryHashes(stories: List<Story>): Set<String> = stories.map { it.storyHash }.toSet()

    @JvmStatic
    fun getOldestStoryTimestamp(stories: List<Story>): Long =
            stories.minByOrNull { it.timestamp }?.timestamp ?: System.currentTimeMillis()

    @JvmStatic
    fun getNewestStoryTimestamp(stories: MutableList<Story>): Long =
            stories.maxByOrNull { it.timestamp }?.timestamp ?: 0L

    @JvmStatic
    fun nullSafeJoin(delimiter: CharSequence, tokens: Array<Any?>?): String {
        if (tokens.isNullOrEmpty()) return ""
        return TextUtils.join(delimiter, tokens)
    }
}