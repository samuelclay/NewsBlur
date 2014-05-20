package com.newsblur.util;

import android.content.Context;
import android.graphics.Color;

import com.newsblur.R;

/**
 * Created by mark on 20/05/2014.
 */
public class ThemeUtils {

    public static int getStoryTitleUnreadColor(Context context) {
        return context.getResources().getColor(R.color.story_title_unread);
    }

    public static int getStoryTitleReadColor(Context context) {
        return context.getResources().getColor(R.color.story_title_read);
    }

    public static int getStoryContentUnreadColor(Context context) {
        return context.getResources().getColor(R.color.story_content_unread);
    }

    public static int getStoryContentReadColor(Context context) {
        return context.getResources().getColor(R.color.story_content_read);
    }

    public static int getStoryAuthorUnreadColor(Context context) {
        return context.getResources().getColor(R.color.story_author_unread);
    }

    public static int getStoryAuthorReadColor(Context context) {
        return context.getResources().getColor(R.color.story_author_read);
    }

    public static int getStoryDateUnreadColor(Context context) {
        return context.getResources().getColor(R.color.story_date_unread);
    }

    public static int getStoryDateReadColor(Context context) {
        return context.getResources().getColor(R.color.story_date_read);
    }

    public static int getStoryFeedUnreadColor(Context context) {
        return context.getResources().getColor(R.color.story_feed_unread);
    }

    public static int getStoryFeedReadColor(Context context) {
        return context.getResources().getColor(R.color.story_feed_read);
    }
}
