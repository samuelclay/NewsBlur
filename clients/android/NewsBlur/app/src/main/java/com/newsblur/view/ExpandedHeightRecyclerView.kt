package com.newsblur.view

import android.content.Context
import android.util.AttributeSet
import android.view.View
import androidx.recyclerview.widget.RecyclerView

class ExpandedHeightRecyclerView
    @JvmOverloads
    constructor(
        context: Context,
        attrs: AttributeSet? = null,
        defStyleAttr: Int = 0,
    ) : RecyclerView(context, attrs, defStyleAttr) {
        override fun onMeasure(
            widthSpec: Int,
            heightSpec: Int,
        ) {
            val expandedHeightSpec =
                View.MeasureSpec.makeMeasureSpec(
                    Int.MAX_VALUE shr 2,
                    View.MeasureSpec.AT_MOST,
                )
            super.onMeasure(widthSpec, expandedHeightSpec)
        }
    }
