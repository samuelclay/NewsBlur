package com.newsblur

import org.junit.Assert
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.CharBuffer
import java.nio.charset.CodingErrorAction
import kotlin.system.measureNanoTime
import kotlin.system.measureTimeMillis

class StoryContentTruncatingTest {

    private val maxBytes = 1024 * 1000 // 1MB

    @Test
    fun readShortJsonTime() {
        measureNanoTime {
            ResourceUtil.readJsonResource("shortContent.json")
        }.also {
            println("readShortJsonTime took $it nanos")
        }
    }

    @Test
    fun readLongJsonTime() {
        measureTimeMillis {
            ResourceUtil.readJsonResource("longContent.json")
        }.also {
            println("readLongJsonTime took $it millis")
        }
    }

    @Test
    fun truncateShortJsonTest() {
        measureTimeMillis {
            val content = ResourceUtil.readJsonResource("shortContent.json")
            val truncated = truncateUtf8ByteLength(content, maxBytes)
            Assert.assertEquals(content, truncated)
        }.also {
            println("truncateShortJsonTest took $it millis")
        }
    }

    @Test
    fun truncateLongJsonTest() {
        measureTimeMillis {
            val content = ResourceUtil.readJsonResource("longContent.json")
            val truncated = truncateUtf8ByteLength(content, maxBytes)
            Assert.assertNotEquals(content, truncated)
        }.also {
            println("truncateLongJsonTest took $it millis")
        }
    }

    private fun truncateUtf8ByteLength(value: String, maxBytes: Int): String {
        val start = System.currentTimeMillis()
        val bytes = value.encodeToByteArray()
        if (bytes.size <= maxBytes) return value.also {
            println("truncateUtf8ByteLength took ${System.currentTimeMillis() - start} millis")
        }
        val byteBuffer = ByteBuffer.wrap(bytes, 0, maxBytes)
        val charBuffer = CharBuffer.allocate(maxBytes)
        val decoder = Charsets.UTF_8.newDecoder()
        decoder.onMalformedInput(CodingErrorAction.IGNORE)
        decoder.decode(byteBuffer, charBuffer, true)
        decoder.flush(charBuffer)
        return String(charBuffer.array(), 0, charBuffer.position()).also {
            println("truncateUtf8ByteLength took ${System.currentTimeMillis() - start} millis")
        }
    }
}