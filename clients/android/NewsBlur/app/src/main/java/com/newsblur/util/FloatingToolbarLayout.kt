package com.newsblur.util

/** FloatingToolbarLayout.kt mirrors StoryTitlesHeaderBar.swift's fit priorities without view dependencies. */
object FloatingToolbarLayout {
    data class Fit(
        val merged: Boolean,
        val options: Int,
        val discoverText: Boolean,
        val searchText: Boolean,
    )

    fun fit(
        width: Int,
        fullOptions: Int,
        compactOptions: Int,
        discover: Int,
        search: Int,
        showDiscover: Boolean = true,
        showSearch: Boolean = true,
        showMark: Boolean = true,
    ): Fit {
        val leadingCount = 1 + (if (showDiscover) 1 else 0) + (if (showSearch) 1 else 0)
        val gaps = (leadingCount - 1) * 6
        val mark = if (showMark) 79 else 0
        val minimumDiscover = if (showDiscover) 44 else 0
        val minimumSearch = if (showSearch) 44 else 0
        val merged = showMark && width < minimumDiscover + minimumSearch + 44 + mark + gaps + 32
        val edges = 24
        val fixed = mark + gaps + edges
        val optionsSpace = width - fixed - minimumDiscover - minimumSearch
        val optionsMode =
            when {
                fullOptions <= optionsSpace -> 2
                compactOptions <= optionsSpace -> 1
                else -> 0
            }
        val optionsWidth =
            when (optionsMode) {
                2 -> fullOptions
                1 -> compactOptions
                else -> 44
            }
        val searchText = showSearch && fixed + optionsWidth + minimumDiscover + search <= width
        val discoverSpace = width - fixed - optionsWidth - if (showSearch) (if (searchText) search else 44) else 0
        return Fit(merged, optionsMode, showDiscover && discover <= discoverSpace, searchText)
    }

    data class Popover(
        val x: Int,
        val y: Int,
        val width: Int,
        val height: Int,
    )

    fun popover(
        left: Int,
        top: Int,
        right: Int,
        bottom: Int,
        anchorLeft: Int,
        anchorTop: Int,
        anchorRight: Int,
        anchorBottom: Int,
        desiredWidth: Int,
        desiredHeight: Int,
        gap: Int,
    ): Popover {
        val width = desiredWidth.coerceAtMost((right - left - gap * 2).coerceAtLeast(1))
        val above = (anchorTop - top - gap * 2).coerceAtLeast(1)
        val below = (bottom - anchorBottom - gap * 2).coerceAtLeast(1)
        val placeAbove = above > below
        val height = desiredHeight.coerceAtMost(if (placeAbove) above else below).coerceAtLeast(1)
        val x = (anchorRight - width).coerceIn(left + gap, (right - width - gap).coerceAtLeast(left + gap))
        val y = if (placeAbove) anchorTop - gap - height else anchorBottom + gap
        return Popover(x, y, width, height)
    }
}
