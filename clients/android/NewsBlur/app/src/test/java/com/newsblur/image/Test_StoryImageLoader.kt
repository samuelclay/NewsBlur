package com.newsblur.image

import android.graphics.Bitmap
import com.newsblur.util.FileCache
import io.mockk.every
import io.mockk.mockk
import io.mockk.spyk
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertArrayEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.IOException

@Suppress("ktlint:standard:class-naming")
class Test_StoryImageLoader {
    @get:Rule val folder = TemporaryFolder()

    @Test fun test_linked_photo_loads_full_bytes_online_and_cached_thumbnail_offline() = runBlocking {
        val thumb = folder.newFile("thumbnail.jpg").apply { writeText("thumbnail") }
        val full = "full-size".toByteArray()
        val cache = mockk<FileCache>()
        every { cache.getCachedFile(any()) } returns null
        every { cache.cacheDir } returns folder.root
        var online = true
        val client = OkHttpClient.Builder().addInterceptor { chain ->
            if (!online) throw IOException("offline")
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1)
                .code(200).message("OK").body(full.toResponseBody()).build()
        }.build()
        val loader = spyk(StoryImageLoader(cache, client), recordPrivateCalls = true)
        every { loader["decode"](any<ByteArray>()) } returns mockk<Bitmap>()
        val source = StoryImageSource.parse(
            """{"generation":1,"token":"1","src":"https://example.com/full.jpg",
              "thumbnailSrc":"${StoryImageSource.READER_ORIGIN}/images/${thumb.name}",
              "naturalWidth":120,"naturalHeight":60,"rect":{"x":0,"y":0,"width":120,"height":60,"viewportWidth":320}}""",
        )!!
        assertArrayEquals(full, loader.load(source).data)
        online = false
        assertArrayEquals(thumb.readBytes(), loader.load(source).data)
    }
}
