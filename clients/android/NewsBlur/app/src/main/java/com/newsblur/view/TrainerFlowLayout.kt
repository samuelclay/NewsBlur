package com.newsblur.view

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import kotlin.math.max

/**
 * Lays its children out in rows that wrap at the right edge, like the WrappingHStack in
 * clients/ios/Classes/TrainerView.swift. The trainer's title words and classifier capsules
 * (fragment/IntelTrainerSections.kt) flow through it. Rows run right to left in RTL layouts.
 */
class TrainerFlowLayout
    @JvmOverloads
    constructor(
        context: Context,
        attrs: AttributeSet? = null,
    ) : ViewGroup(context, attrs) {
        var horizontalSpacing: Int = 0
            set(value) {
                field = value
                requestLayout()
            }

        var verticalSpacing: Int = 0
            set(value) {
                field = value
                requestLayout()
            }

        override fun onMeasure(
            widthMeasureSpec: Int,
            heightMeasureSpec: Int,
        ) {
            val maxWidth = MeasureSpec.getSize(widthMeasureSpec) - paddingLeft - paddingRight
            val widthMode = MeasureSpec.getMode(widthMeasureSpec)
            val childWidthSpec =
                MeasureSpec.makeMeasureSpec(
                    max(0, maxWidth),
                    if (widthMode == MeasureSpec.UNSPECIFIED) MeasureSpec.UNSPECIFIED else MeasureSpec.AT_MOST,
                )
            var rowWidth = 0
            var rowHeight = 0
            var usedWidth = 0
            var totalHeight = 0
            for (child in visibleChildren()) {
                child.measure(childWidthSpec, MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
                val gap = if (rowWidth > 0) horizontalSpacing else 0
                if (widthMode != MeasureSpec.UNSPECIFIED && rowWidth > 0 && rowWidth + gap + child.measuredWidth > maxWidth) {
                    totalHeight += rowHeight + verticalSpacing
                    rowWidth = 0
                    rowHeight = 0
                }
                rowWidth += (if (rowWidth > 0) horizontalSpacing else 0) + child.measuredWidth
                rowHeight = max(rowHeight, child.measuredHeight)
                usedWidth = max(usedWidth, rowWidth)
            }
            totalHeight += rowHeight
            val width =
                if (widthMode == MeasureSpec.EXACTLY) {
                    MeasureSpec.getSize(widthMeasureSpec)
                } else {
                    usedWidth + paddingLeft + paddingRight
                }
            setMeasuredDimension(width, resolveSize(totalHeight + paddingTop + paddingBottom, heightMeasureSpec))
        }

        override fun onLayout(
            changed: Boolean,
            left: Int,
            top: Int,
            right: Int,
            bottom: Int,
        ) {
            val maxWidth = right - left - paddingLeft - paddingRight
            val isRtl = layoutDirection == View.LAYOUT_DIRECTION_RTL
            var x = 0
            var y = paddingTop
            var rowHeight = 0
            val row = mutableListOf<View>()

            fun placeRow() {
                var offset = 0
                for (child in row) {
                    // Each child sits centered in its row, like an HStack.
                    val childTop = y + (rowHeight - child.measuredHeight) / 2
                    val childLeft =
                        if (isRtl) {
                            right - left - paddingRight - offset - child.measuredWidth
                        } else {
                            paddingLeft + offset
                        }
                    child.layout(childLeft, childTop, childLeft + child.measuredWidth, childTop + child.measuredHeight)
                    offset += child.measuredWidth + horizontalSpacing
                }
                row.clear()
            }

            for (child in visibleChildren()) {
                val gap = if (x > 0) horizontalSpacing else 0
                if (x > 0 && x + gap + child.measuredWidth > maxWidth) {
                    placeRow()
                    y += rowHeight + verticalSpacing
                    x = 0
                    rowHeight = 0
                }
                x += (if (x > 0) horizontalSpacing else 0) + child.measuredWidth
                rowHeight = max(rowHeight, child.measuredHeight)
                row += child
            }
            placeRow()
        }

        private fun visibleChildren(): List<View> = (0 until childCount).map(::getChildAt).filter { it.visibility != View.GONE }
    }
