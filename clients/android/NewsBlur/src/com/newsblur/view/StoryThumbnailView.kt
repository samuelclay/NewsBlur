package com.newsblur.view

import android.content.Context
import android.util.AttributeSet
import android.widget.FrameLayout
import android.widget.ImageView
import com.newsblur.R
import com.newsblur.util.ThumbnailStyle

class StoryThumbnailView : FrameLayout {

    lateinit var imageView: ImageView

    constructor(context: Context) : super(context) {
        init(context)
    }

    constructor(context: Context, attrs: AttributeSet) : super(context, attrs) {
        init(context)
    }

    constructor(context: Context, attrs: AttributeSet, defStyleAttr: Int) : super(context, attrs, defStyleAttr) {
        init(context)
    }

    private fun init(context: Context) {
        clipToOutline = true
        imageView = ImageView(context)
        imageView.layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        imageView.scaleType = ImageView.ScaleType.CENTER_CROP
        addView(imageView)
    }

    fun setThumbnailStyle(thumbnailStyle: ThumbnailStyle) {
        if (thumbnailStyle == ThumbnailStyle.LEFT_SMALL || thumbnailStyle == ThumbnailStyle.RIGHT_SMALL) {
            setBackgroundResource(R.drawable.shape_story_thumbnail_small)
        } else {
            setBackgroundResource(0)
        }
    }
}