package com.newsblur.fragment;

public final class ReturnedStoryScrollDecider {
    private ReturnedStoryScrollDecider() {}

    public static boolean shouldScrollToReturnedStory(
            int returnedStoryPosition,
            int firstVisiblePosition,
            int lastVisiblePosition
    ) {
        if (returnedStoryPosition < 0) {
            return false;
        }
        if (firstVisiblePosition < 0 || lastVisiblePosition < 0) {
            return true;
        }
        return returnedStoryPosition < firstVisiblePosition || returnedStoryPosition > lastVisiblePosition;
    }
}
