package com.newsblur.database

/**
 * ReadingPageOrder.kt maps the reader's story positions to ViewPager pages. ViewPager always lays its
 * pages out left to right, whatever the layout direction, so in Arabic and Hebrew ReadingAdapter.kt
 * numbers the pages from the last story down. The next story then sits to the left, where the Next
 * button points, and swiping toward the end edge moves forward just as it does left to right.
 *
 * Reading.kt keeps working in story positions, which stay put when more stories load, and converts
 * only where it reads or moves the pager. The mapping is its own inverse.
 */
internal class ReadingPageOrder(
    val mirrored: Boolean,
) {
    fun pageFor(
        storyPosition: Int,
        count: Int,
    ): Int = flip(storyPosition, count)

    fun storyPositionFor(
        page: Int,
        count: Int,
    ): Int = flip(page, count)

    private fun flip(
        index: Int,
        count: Int,
    ): Int = if (mirrored && count > 0) count - 1 - index else index
}

/**
 * ReadingPageOrder.kt turns ViewPager page selections into the story selections Reading.kt acts on.
 * When more stories load into a mirrored pager, every page number shifts, and ViewPager follows the
 * current story to its new page and reports it as selected again. That repeat is not a new
 * selection, so it is dropped rather than restarting the story's mark read timer. Left to right,
 * appended stories never move the current page and every selection passes through unchanged.
 */
internal class ReadingPageSelections(
    private val order: ReadingPageOrder,
) {
    private var lastPosition = -1
    private var lastStoryHash: String? = null

    /** Returns true when the story at [storyPosition] should reach Reading.kt as a new selection. */
    fun select(
        storyPosition: Int,
        storyHash: String?,
    ): Boolean {
        val isRepeat = order.mirrored && storyHash != null && storyPosition == lastPosition && storyHash == lastStoryHash
        lastPosition = storyPosition
        lastStoryHash = storyHash
        return !isRepeat
    }
}
