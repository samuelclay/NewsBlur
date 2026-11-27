package com.newsblur.view

import android.content.Context
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView

/**
 * StoryGridLayoutManager.kt lays out the story list (ItemSetFragment.java). While NewStoriesEntrance.kt pushes
 * the list down to make room for new stories, the rows that were on screen sit below the screen's bottom edge in
 * the final layout, so it asks for that much extra layout space to keep them drawn.
 */
class StoryGridLayoutManager(
    context: Context,
    spanCount: Int,
) : GridLayoutManager(context, spanCount) {
    var extraEndSpacePx: Int = 0

    override fun calculateExtraLayoutSpace(
        state: RecyclerView.State,
        extraLayoutSpace: IntArray,
    ) {
        super.calculateExtraLayoutSpace(state, extraLayoutSpace)
        if (extraEndSpacePx > 0) extraLayoutSpace[1] = maxOf(extraLayoutSpace[1], extraEndSpacePx)
    }
}
