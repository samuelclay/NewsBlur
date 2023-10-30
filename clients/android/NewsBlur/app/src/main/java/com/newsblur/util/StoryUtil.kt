package com.newsblur.util

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
}