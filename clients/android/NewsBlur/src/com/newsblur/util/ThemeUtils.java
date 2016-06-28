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
