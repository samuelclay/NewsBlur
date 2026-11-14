package com.newsblur.image

import org.junit.Assert.assertEquals
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_StoryImageFile {
    private fun bytes(vararg values: Int) = ByteArray(values.size) { values[it].toByte() } + ByteArray(16)

    @Test fun test_recognizes_common_image_formats_by_their_bytes() {
        assertEquals("image/png", StoryImageFile.mimeType(bytes(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)))
        assertEquals("image/jpeg", StoryImageFile.mimeType(bytes(0xFF, 0xD8, 0xFF, 0xE0)))
        assertEquals("image/gif", StoryImageFile.mimeType("GIF89a".toByteArray() + ByteArray(8)))
        assertEquals("image/webp", StoryImageFile.mimeType("RIFF\u0000\u0000\u0000\u0000WEBPVP8 ".toByteArray()))
    }

    @Test fun test_unknown_bytes_are_saved_as_jpeg() {
        assertEquals("image/jpeg", StoryImageFile.mimeType("<svg></svg>".toByteArray()))
        assertEquals("image/jpeg", StoryImageFile.mimeType(ByteArray(0)))
    }

    @Test fun test_file_name_comes_from_the_url_with_the_real_extension() {
        assertEquals("router.png", StoryImageFile.fileName("https://example.com/img/router.jpg?w=800", "image/png"))
        assertEquals("intro-1790676017.jpg", StoryImageFile.fileName("https://example.com/gallery/intro-1790676017.jpg", "image/jpeg"))
    }

    @Test fun test_file_name_falls_back_and_drops_unsafe_characters() {
        assertEquals("NewsBlur image.gif", StoryImageFile.fileName("data:image/gif;base64,R0lGOD", "image/gif"))
        assertEquals("NewsBlur image.jpg", StoryImageFile.fileName("https://example.com/", "image/jpeg"))
        assertEquals("a_b_c.webp", StoryImageFile.fileName("https://example.com/a%2Fb%3Ac.webp", "image/webp"))
    }
}
