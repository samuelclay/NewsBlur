package com.newsblur.image

import java.net.URI
import java.net.URLDecoder

/**
 * Names and types a story photo's bytes for Copy, Save, and Share (StoryImageActions.kt). The
 * type comes from the bytes themselves, because a URL's extension often lies: image CDNs serve
 * WebP or PNG from ".jpg" paths.
 */
object StoryImageFile {
    private const val FALLBACK_NAME = "NewsBlur image"
    private const val MAX_NAME_LENGTH = 80

    fun mimeType(data: ByteArray): String =
        when {
            data.startsWith(0x89, 0x50, 0x4E, 0x47) -> "image/png"
            data.startsWith(0xFF, 0xD8, 0xFF) -> "image/jpeg"
            data.startsWith('G'.code, 'I'.code, 'F'.code, '8'.code) -> "image/gif"
            data.startsWith('R'.code, 'I'.code, 'F'.code, 'F'.code) && data.hasAt(8, "WEBP") -> "image/webp"
            data.hasAt(4, "ftypavif") -> "image/avif"
            data.hasAt(4, "ftypheic") || data.hasAt(4, "ftypmif1") -> "image/heic"
            data.startsWith('B'.code, 'M'.code) -> "image/bmp"
            // StoryImageLoader.kt only keeps bytes it could decode, so anything else is left to the
            // receiving app as the most common photo type.
            else -> "image/jpeg"
        }

    fun extension(mimeType: String): String =
        when (mimeType) {
            "image/png" -> "png"
            "image/gif" -> "gif"
            "image/webp" -> "webp"
            "image/avif" -> "avif"
            "image/heic" -> "heic"
            "image/bmp" -> "bmp"
            else -> "jpg"
        }

    /** The URL's last path segment, readable and safe as a file name, with [mimeType]'s extension. */
    fun fileName(
        url: String,
        mimeType: String,
    ): String {
        val lastSegment =
            runCatching {
                val uri = URI(url)
                if (uri.scheme?.lowercase() !in setOf("http", "https")) return@runCatching null
                URLDecoder.decode(uri.rawPath.orEmpty().substringAfterLast('/'), "UTF-8")
            }.getOrNull()
        val base =
            lastSegment
                ?.substringBeforeLast('.')
                ?.replace(Regex("[^A-Za-z0-9 ._-]"), "_")
                ?.trim(' ', '.', '_')
                ?.take(MAX_NAME_LENGTH)
                ?.takeIf { it.isNotEmpty() }
                ?: FALLBACK_NAME
        return "$base.${extension(mimeType)}"
    }

    private fun ByteArray.startsWith(vararg values: Int): Boolean =
        size >= values.size && values.indices.all { this[it] == values[it].toByte() }

    private fun ByteArray.hasAt(
        offset: Int,
        text: String,
    ): Boolean = size >= offset + text.length && text.indices.all { this[offset + it] == text[it].code.toByte() }
}
