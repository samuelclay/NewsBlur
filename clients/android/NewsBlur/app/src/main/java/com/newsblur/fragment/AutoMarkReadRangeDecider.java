package com.newsblur.fragment;

/**
 * Decides how far to advance the "mark read on scroll" marker in
 * {@link ItemSetFragment}. A story becomes eligible to be auto-marked in two
 * cases:
 *
 *  1. It has fully scrolled off the top of the viewport — i.e. its position is
 *     strictly less than the first visible item.
 *  2. It is the topmost partially-visible item and its vertical midpoint has
 *     crossed the top edge of the viewport (which corresponds to the bottom of
 *     the feed bar). This lets users actually see the unread-to-read
 *     transition instead of the row disappearing before they notice.
 *
 * File: app/src/main/java/com/newsblur/fragment/AutoMarkReadRangeDecider.java
 */
public final class AutoMarkReadRangeDecider {
    private AutoMarkReadRangeDecider() {}

    /**
     * @param firstVisiblePosition the position returned by
     *        {@code LayoutManager#findFirstVisibleItemPosition()}. A position is
     *        "visible" if any part of it is in the viewport, so the item at
     *        this position is still partially on screen.
     * @param topRowHalfwayPastFold {@code true} if the top visible row's
     *        vertical midpoint is at or above the top of the viewport, meaning
     *        the row is at least halfway hidden under the feed bar. When true,
     *        the top visible row is also marked.
     * @param storyCount the number of stories in the adapter (excluding the
     *        fleuron footer row).
     * @return the highest story index that should be auto-marked as read, or
     *         {@code -1} if nothing should be marked.
     */
    public static int findMarkEnd(int firstVisiblePosition, boolean topRowHalfwayPastFold, int storyCount) {
        if (storyCount <= 0) return -1;
        if (firstVisiblePosition < 0) return -1;

        int markEnd = firstVisiblePosition - 1;
        if (topRowHalfwayPastFold && firstVisiblePosition < storyCount) {
            markEnd = firstVisiblePosition;
        }
        if (markEnd < 0) return -1;
        if (markEnd >= storyCount) return storyCount - 1;
        return markEnd;
    }
}
