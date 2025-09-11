package com.newsblur.util

import android.content.res.Configuration
import android.text.TextUtils
import com.newsblur.domain.Story
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
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

    suspend fun buildMinimalHtml(
            storyHtml: String,
            fontCss: String,
            themeValue: PrefConstants.ThemeValue,
            nightMask: Int,
    ): String = withContext(Dispatchers.Default) {
        val sb = StringBuilder(8 * 1024)
        sb.append("<html><head>")
        sb.append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, maximum-scale=1, minimum-scale=1, user-scalable=0\"/>")
        sb.append(fontCss)
        sb.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"reading.css\"/>")

        when (themeValue) {
            PrefConstants.ThemeValue.LIGHT -> sb.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"light_reading.css\"/>")
            PrefConstants.ThemeValue.DARK -> sb.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"dark_reading.css\"/>")
            PrefConstants.ThemeValue.BLACK -> sb.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"black_reading.css\"/>")
            PrefConstants.ThemeValue.AUTO -> when (nightMask) {
                Configuration.UI_MODE_NIGHT_YES -> sb.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"dark_reading.css\"/>")
                else -> sb.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"light_reading.css\"/>")
            }
        }

        sb.append("<script src=\"mark.min.js\"></script>")
        sb.append("<script src=\"storyHighlights.js\"></script>")

        sb.append("</head><body><div class=\"NB-story\">")
        sb.append(storyHtml)
        sb.append("<script type=\"text/javascript\" src=\"storyDetailView.js\"></script>")
        sb.append("</div></body></html>")
        sb.toString()
    }
}