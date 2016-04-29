package com.newsblur.util;

import android.content.Context;

import com.newsblur.R;

/**
 * Created by mark on 20/05/2014.
 */
public class ThemeUtils {

    private ThemeUtils() {} // util class - no instances

    // Resources.getColor(rid) was deprecated for a version that actually has a native
    // understanding of themes, but isn't available unless platform version > Build.M.
    // If we ever bump min platform version to M or higher, we could greatly simplify
    // or totally remove this whole utility class.
    @SuppressWarnings("deprecation")
    private static int getColor(Context context, int id) {
        return context.getResources().getColor(id);
    }

    public static int getStoryTitleUnreadColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.story_title_unread);
        } else {
            return getColor(context, R.color.dark_story_title_unread);
        }
    }

    public static int getStoryTitleReadColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.story_title_read);
        } else {
            return getColor(context, R.color.story_title_read);
        }
    }

    public static int getStoryContentUnreadColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.story_content_unread);
        } else {
            return getColor(context, R.color.dark_story_content_unread);
        }
    }

    public static int getStoryContentReadColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.story_content_read);
        } else {
            return getColor(context, R.color.story_content_read);
        }
    }

    public static int getStoryAuthorUnreadColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.story_author_unread);
        } else {
            return getColor(context, R.color.story_author_unread);
        }
    }

    public static int getStoryAuthorReadColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.story_author_read);
        } else {
            return getColor(context, R.color.story_author_read);
        }
    }

    public static int getStoryDateUnreadColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.story_date_unread);
        } else {
            return getColor(context, R.color.dark_story_date_unread);
        }
    }

    public static int getStoryDateReadColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.story_date_read);
        } else {
            return getColor(context, R.color.story_date_read);
        }
    }

    public static int getStoryFeedUnreadColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.story_feed_unread);
        } else {
            return getColor(context, R.color.dark_story_feed_unread);
        }
    }

    public static int getStoryFeedReadColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.story_feed_read);
        } else {
            return getColor(context, R.color.story_feed_read);
        }
    }

    public static int getProfileActivitiesLinkColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.linkblue);
        } else {
            return getColor(context, R.color.dark_linkblue);
        }
    }

    public static int getProfileActivitiesContentColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.darkgray);
        } else {
            return getColor(context, R.color.white);
        }
    }

    public static int getProfileActivitiesQuoteColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.midgray);
        } else {
            return getColor(context, R.color.lightgray);
        }
    }
}
