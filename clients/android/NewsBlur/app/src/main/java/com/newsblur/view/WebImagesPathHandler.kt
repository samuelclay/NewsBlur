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
        val file = File(storyImagesDir, path)
        val exists = file.exists()
        if (!exists) return null

        val mimeType = URLConnection.guessContentTypeFromName(file.name) ?: "image/*"
        return WebResourceResponse(mimeType, null, FileInputStream(file))
    }
}
