package com.newsblur.view

import android.content.Context
import android.util.AttributeSet
import android.view.ViewGroup
import androidx.appcompat.widget.AppCompatImageView
import com.newsblur.R
import com.newsblur.util.ThumbnailStyle

class StoryThumbnailView
    @JvmOverloads
    constructor(
        context: Context,
        attrs: AttributeSet? = null,
        defStyleAttr: Int = 0,
    ) : AppCompatImageView(context, attrs, defStyleAttr) {
        private var expandedWidth: Int = 0
        private var expandedHeight: Int = 0
        private var expandedLeftMargin: Int = 0
        private var expandedTopMargin: Int = 0
        private var expandedRightMargin: Int = 0
        private var expandedBottomMargin: Int = 0

        init {
            clipToOutline = true
            scaleType = ScaleType.CENTER_CROP
        }

        fun setExpandedLayout(
            width: Int,
            height: Int,
            leftMargin: Int,
            topMargin: Int,
            rightMargin: Int,
            bottomMargin: Int,
        ) {
            expandedWidth = width
            expandedHeight = height
            expandedLeftMargin = leftMargin
            expandedTopMargin = topMargin
            expandedRightMargin = rightMargin
            expandedBottomMargin = bottomMargin
            if (visibility == VISIBLE) {
                (layoutParams as? ViewGroup.MarginLayoutParams)?.let { params ->
                    params.width = width
                    params.height = height
                    params.setMargins(leftMargin, topMargin, rightMargin, bottomMargin)
                    layoutParams = params
                }
            }
        }

        fun setThumbnailStyle(thumbnailStyle: ThumbnailStyle) {
            if (thumbnailStyle.isSmall()) {
                setBackgroundResource(R.drawable.shape_rounded_corners_6dp)
            } else {
                setBackgroundResource(0)
            }
        }

        override fun setVisibility(visibility: Int) {
            (layoutParams as? ViewGroup.MarginLayoutParams)?.let { params ->
                if (visibility == VISIBLE) {
                    if (expandedWidth > 0) params.width = expandedWidth
                    if (expandedHeight > 0) params.height = expandedHeight
                    params.setMargins(
                        expandedLeftMargin,
                        expandedTopMargin,
                        expandedRightMargin,
                        expandedBottomMargin,
                    )
                } else {
                    if (params.width > 0) expandedWidth = params.width
                    if (params.height > 0) expandedHeight = params.height
                    expandedLeftMargin = params.leftMargin
                    expandedTopMargin = params.topMargin
                    expandedRightMargin = params.rightMargin
                    expandedBottomMargin = params.bottomMargin
                    params.width = 0
                    params.height = 0
                    params.setMargins(0, 0, 0, 0)
                }
                layoutParams = params
            }
            super.setVisibility(visibility)
        }
    }
