package com.newsblur.view

import android.content.Context
import android.util.AttributeSet
import androidx.appcompat.widget.AppCompatImageView
import com.newsblur.R
import com.newsblur.util.ThumbnailStyle

class StoryThumbnailView
@JvmOverloads constructor(context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0)
    : AppCompatImageView(context, attrs, defStyleAttr) {

    init {
        clipToOutline = true
        scaleType = ScaleType.CENTER_CROP
    }

    fun setThumbnailStyle(thumbnailStyle: ThumbnailStyle) {
        if (thumbnailStyle.isSmall()) {
            setBackgroundResource(R.drawable.shape_rounded_corners_6dp)
        } else {
            setBackgroundResource(0)
        }
    }
}