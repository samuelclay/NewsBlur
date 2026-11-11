package com.newsblur.web

import android.webkit.WebResourceResponse
import androidx.webkit.WebViewAssetLoader
import java.io.File
import java.io.FileInputStream
import java.net.URLConnection

class WebImagesPathHandler(
    private val storyImagesDir: File,
) : WebViewAssetLoader.PathHandler {
    override fun handle(path: String): WebResourceResponse? {
        val file = cachedImage(path) ?: return null

        val mimeType = URLConnection.guessContentTypeFromName(file.name) ?: "image/*"
        return WebResourceResponse(mimeType, null, FileInputStream(file))
    }

    // WebImagesPathHandler.kt receives the decoded URL path, so "..%2f" must not reach files outside the image cache.
    internal fun cachedImage(path: String): File? =
        runCatching {
            File(storyImagesDir, path).canonicalFile.takeIf { it.isFile && it.parentFile == storyImagesDir.canonicalFile }
        }.getOrNull()
}
