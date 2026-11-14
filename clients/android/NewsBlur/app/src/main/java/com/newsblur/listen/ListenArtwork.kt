package com.newsblur.listen

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.network.APIConstants
import com.newsblur.util.CustomIconRenderer
import com.newsblur.util.FileCache
import com.newsblur.util.UIUtils
import java.io.ByteArrayOutputStream

/**
 * ListenArtwork.kt draws the lock screen and notification artwork: the feed's favicon centered on its own
 * feed colors, since a bare 16 pixel favicon would be blown up and blurry.
 */
object ListenArtwork {
    private const val SIZE_PX = 320
    private const val ICON_PX = 168

    class Result(
        val icon: Bitmap?,
        val artworkPng: ByteArray,
    )

    /** Runs on a background thread: it may download the favicon into the icon cache. */
    fun render(
        context: Context,
        story: ListenStory,
        iconCache: FileCache,
    ): Result {
        val icon = loadIcon(context, story, iconCache)
        val artwork = Bitmap.createBitmap(SIZE_PX, SIZE_PX, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(artwork)
        val top = UIUtils.decodeColourValue(story.feedColor, Color.rgb(0x70, 0x9E, 0x5D))
        val bottom = UIUtils.decodeColourValue(story.feedFade, Color.rgb(0x4E, 0x73, 0x3F))
        val background =
            Paint().apply {
                shader =
                    LinearGradient(
                        0f,
                        0f,
                        0f,
                        SIZE_PX.toFloat(),
                        top,
                        bottom,
                        Shader.TileMode.CLAMP,
                    )
            }
        canvas.drawRect(0f, 0f, SIZE_PX.toFloat(), SIZE_PX.toFloat(), background)
        if (icon != null) {
            val plate =
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.argb(235, 255, 255, 255)
                }
            val plateInset = (SIZE_PX - ICON_PX) / 2f - 24f
            canvas.drawRoundRect(
                RectF(plateInset, plateInset, SIZE_PX - plateInset, SIZE_PX - plateInset),
                36f,
                36f,
                plate,
            )
            // Tiny favicons stay crisp when scaled without filtering.
            val iconPaint = Paint().apply { isFilterBitmap = icon.width >= 64 }
            val inset = (SIZE_PX - ICON_PX) / 2
            canvas.drawBitmap(
                icon,
                null,
                Rect(inset, inset, inset + ICON_PX, inset + ICON_PX),
                iconPaint,
            )
        }
        val bytes = ByteArrayOutputStream()
        artwork.compress(Bitmap.CompressFormat.PNG, 100, bytes)
        artwork.recycle()
        return Result(icon, bytes.toByteArray())
    }

    private fun loadIcon(
        context: Context,
        story: ListenStory,
        iconCache: FileCache,
    ): Bitmap? {
        story.feedId?.let { feedId ->
            BlurDatabaseHelper.getFeedIcon(feedId)?.let { customIcon ->
                CustomIconRenderer.renderIcon(context, customIcon, ICON_PX)?.let { return it }
            }
        }
        val raw = story.faviconUrl?.takeIf { it.isNotBlank() } ?: return null
        // Favicons can be server-relative paths like /rss_feeds/icon/123.
        val url = if (raw.startsWith("/")) APIConstants.buildUrl(raw) else raw
        iconCache.cacheFile(url)
        val file = iconCache.getCachedFile(url)?.takeIf { it.exists() } ?: return null
        return BitmapFactory.decodeFile(file.absolutePath)
    }
}
