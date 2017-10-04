package com.newsblur.util;

import android.content.Context;

import com.newsblur.R;

/**
 * Created by mark on 20/05/2014.
 */
public class ThemeUtils {

    private ThemeUtils() {} // util class - no instances

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
