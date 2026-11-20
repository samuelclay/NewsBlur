package com.newsblur.image

import android.graphics.Bitmap
import com.newsblur.util.FileCache
import io.mockk.every
import io.mockk.mockk
import io.mockk.spyk
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.IOException

@Suppress("ktlint:standard:class-naming")
class Test_StoryImageLoader {
    @get:Rule val folder = TemporaryFolder()

    @Test fun test_linked_photo_uses_cached_thumbnail_if_full_image_is_unavailable() = runBlocking {
        val thumb = folder.newFile("thumbnail.jpg").apply { writeText("thumbnail") }
        val full = "full-size".toByteArray()
        val cache = mockk<FileCache>()
        every { cache.getCachedFile(any()) } returns null
        every { cache.cacheDir } returns folder.root
        var online = true
        var status = 200
        val client = OkHttpClient.Builder().addInterceptor { chain ->
            if (!online) throw IOException("offline")
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1)
                .code(status).message("OK").body(full.toResponseBody()).build()
        }.build()
        val loader = spyk(StoryImageLoader(cache, client), recordPrivateCalls = true)
        every { loader["decode"](any<ByteArray>()) } returns mockk<Bitmap>()
        val source = StoryImageSource.parse(
            """{"generation":1,"token":"1","src":"https://example.com/full.jpg",
              "thumbnailSrc":"${StoryImageSource.READER_ORIGIN}/images/${thumb.name}",
              "naturalWidth":120,"naturalHeight":60,"rect":{"x":0,"y":0,"width":120,"height":60,"viewportWidth":320}}""",
        )!!
        assertArrayEquals(full, loader.load(source).data)
        status = 404
        assertArrayEquals(thumb.readBytes(), loader.load(source).data)
        online = false
        assertArrayEquals(thumb.readBytes(), loader.load(source).data)
    }

    @Test fun test_unreadable_full_image_falls_back_to_remote_thumbnail_unless_cancelled() = runBlocking {
        val cache = mockk<FileCache>()
        every { cache.getCachedFile(any()) } returns null
        val paths = mutableListOf<String>()
        val client = OkHttpClient.Builder().addInterceptor { chain ->
            val path = chain.request().url.encodedPath
            paths.add(path)
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1)
                .code(200).message("OK").body(path.toResponseBody()).build()
        }.build()
        val loader = spyk(StoryImageLoader(cache, client), recordPrivateCalls = true)
        val source = StoryImageSource(
            1, "1", "https://example.com/full.jpg", "", 120f, 60f, 0f, 0f, 120f, 60f, 320f,
            thumbnailUrl = "https://example.com/thumb.jpg",
        )
        every { loader["decode"](any<ByteArray>()) } answers {
            if (firstArg<ByteArray>().decodeToString() == "/full.jpg") throw IOException("Invalid image")
            mockk<Bitmap>()
        }
        assertArrayEquals("/thumb.jpg".toByteArray(), loader.load(source).data)
        paths.clear()
        every { loader["decode"](any<ByteArray>()) } throws CancellationException("cancelled")
        assertThrows(CancellationException::class.java) { runBlocking { loader.load(source) } }
        assertEquals(listOf("/full.jpg"), paths)
    }
}
