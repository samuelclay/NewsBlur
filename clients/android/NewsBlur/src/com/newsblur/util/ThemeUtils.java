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

    public static int getProfileActivitiesLinkColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.linkblue);
        } else {
            return getColor(context, R.color.dark_linkblue);
        }
    }

    public static int getProfileActivitiesContentColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.text);
        } else {
            return getColor(context, R.color.white);
        }
    }

    public static int getProfileActivitiesQuoteColor(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return getColor(context, R.color.gray55);
        } else {
            return getColor(context, R.color.gray80);
        }
    }

    public static int getSelectorOverlayBackgroundText(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return R.drawable.selector_overlay_bg_text;
        } else {
            return R.drawable.selector_overlay_bg_dark_text;
        }
    }

    public static int getSelectorOverlayBackgroundStory(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return R.drawable.selector_overlay_bg_story;
        } else {
            return R.drawable.selector_overlay_bg_dark_story;
        }
    }
    
    public static int getSelectorOverlayBackgroundRight(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return R.drawable.selector_overlay_bg_right;
        } else {
            return R.drawable.selector_overlay_bg_dark_right;
        }
    }

    public static int getSelectorOverlayBackgroundRightDone(Context context) {
        if (PrefsUtils.isLightThemeSelected(context)) {
            return R.drawable.selector_overlay_bg_right_done;
        } else {
            return R.drawable.selector_overlay_bg_dark_right_done;
        }
    }
}
