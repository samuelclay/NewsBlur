package com.newsblur.image

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Build
import android.util.Base64
import com.newsblur.util.FileCache
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import okhttp3.Call
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.net.URLDecoder
import java.nio.ByteBuffer

class StoryImageLoader(private val cache: FileCache, private val client: OkHttpClient) {
    @Volatile private var call: Call? = null
    @Volatile private var cancelled = false

    fun cancel() {
        cancelled = true
        call?.cancel()
    }

    suspend fun load(source: StoryImageSource): Bitmap = withContext(Dispatchers.IO) {
        ensureActive()
        val localName = StoryImageSource.cachedFileName(source.url)
        val cached = if (localName != null) File(cache.cacheDir, localName) else cache.getCachedFile(source.url)
        val data = when {
            cached?.isFile == true -> cached.inputStream().use { readBounded(it) }
            localName != null -> error("Cached image is no longer available")
            source.url.startsWith("data:", ignoreCase = true) -> {
                val comma = source.url.indexOf(',')
                require(comma > 0)
                val encoded = source.url.substring(comma + 1)
                if (source.url.substring(0, comma).endsWith(";base64", ignoreCase = true)) {
                    Base64.decode(encoded, Base64.DEFAULT)
                } else {
                    URLDecoder.decode(encoded.replace("+", "%2B"), "UTF-8").toByteArray(Charsets.UTF_8)
                }.also { require(it.size <= MAX_BYTES) }
            }
            else -> {
                val request = client.newCall(Request.Builder().url(source.url).build())
                call = request
                if (cancelled) request.cancel()
                request.execute().use { response ->
                    check(response.isSuccessful)
                    val body = response.body ?: error("Empty image response")
                    require(body.contentLength() <= MAX_BYTES)
                    body.byteStream().use { readBounded(it) }
                }
            }
        }
        ensureActive()
        decode(data).also { ensureActive() }
    }

    private fun readBounded(input: InputStream): ByteArray {
        val result = ByteArrayOutputStream()
        val buffer = ByteArray(16 * 1024)
        while (true) {
            check(!cancelled)
            val read = input.read(buffer)
            if (read < 0) break
            require(result.size() + read <= MAX_BYTES)
            result.write(buffer, 0, read)
        }
        return result.toByteArray()
    }

    private fun decode(data: ByteArray): Bitmap {
        if (Build.VERSION.SDK_INT >= 28) {
            return ImageDecoder.decodeBitmap(ImageDecoder.createSource(ByteBuffer.wrap(data))) { decoder, info, _ ->
                val scale = minOf(1f, 4096f / maxOf(info.size.width, info.size.height))
                decoder.setTargetSize(maxOf(1, (info.size.width * scale).toInt()), maxOf(1, (info.size.height * scale).toInt()))
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        }
        // StoryImageLoader.kt also respects EXIF orientation on Android 8, before ImageDecoder existed.
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(data, 0, data.size, options)
        require(options.outWidth > 0 && options.outHeight > 0)
        options.inJustDecodeBounds = false
        options.inSampleSize = 1
        while (maxOf(options.outWidth, options.outHeight) / options.inSampleSize > 4096) options.inSampleSize *= 2
        val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size, options) ?: error("Unsupported image")
        val orientation = runCatching {
            ExifInterface(ByteArrayInputStream(data)).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val transform = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> transform.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> transform.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> transform.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { transform.setRotate(90f); transform.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_90 -> transform.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> { transform.setRotate(270f); transform.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_270 -> transform.setRotate(270f)
        }
        if (transform.isIdentity) return bitmap
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, transform, true).also { if (it !== bitmap) bitmap.recycle() }
    }

    companion object {
        private const val MAX_BYTES = 32 * 1024 * 1024
    }
}
