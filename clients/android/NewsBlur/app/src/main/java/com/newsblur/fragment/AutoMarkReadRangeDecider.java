package com.newsblur.fragment;

public final class AutoMarkReadRangeDecider {
    private AutoMarkReadRangeDecider() {}

    public static int findMarkEnd(
            int firstCompletelyVisiblePosition,
            int lastCompletelyVisiblePosition,
            int storyCount,
            int lastAutoMarkedPosition
    ) {
        if (storyCount <= 0) {
            return -1;
        }

        int markEnd = firstCompletelyVisiblePosition - 1;
        if (lastCompletelyVisiblePosition < storyCount - 1) {
            return markEnd;
        }

        if (markEnd > lastAutoMarkedPosition) {
            return markEnd;
        }

        // When the list is pinned at the bottom, unread-only mode can shrink the list before the
        // next story reaches the usual threshold. Advance by one remaining story instead of
        // draining the entire visible range at once.
        return Math.min(storyCount - 1, lastAutoMarkedPosition + 1);
    }
}
