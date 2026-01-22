package com.newsblur.domain;

import com.google.gson.annotations.SerializedName;

/**
 * Represents a custom icon for a folder or feed.
 * Icons can be preset icons from bundled assets, emojis, or user-uploaded images.
 */
public class CustomIcon {

    public static final String TYPE_PRESET = "preset";
    public static final String TYPE_EMOJI = "emoji";
    public static final String TYPE_UPLOAD = "upload";
    public static final String TYPE_NONE = "none";

    public static final String ICON_SET_HEROICONS = "heroicons-solid";
    public static final String ICON_SET_LUCIDE = "lucide";

    @SerializedName("icon_type")
    public String iconType;   // "preset", "emoji", "upload", "none"

    @SerializedName("icon_data")
    public String iconData;   // icon name, emoji, or base64 encoded image

    @SerializedName("icon_color")
    public String iconColor;  // hex color like "#ff5722" (for preset icons)

    @SerializedName("icon_set")
    public String iconSet;    // "lucide" or "heroicons-solid"

    public boolean isValid() {
        return iconType != null && !TYPE_NONE.equals(iconType) && iconData != null && !iconData.isEmpty();
    }

    public boolean isPreset() {
        return TYPE_PRESET.equals(iconType);
    }

    public boolean isEmoji() {
        return TYPE_EMOJI.equals(iconType);
    }

    public boolean isUpload() {
        return TYPE_UPLOAD.equals(iconType);
    }

    public String getIconSetOrDefault() {
        return iconSet != null && !iconSet.isEmpty() ? iconSet : ICON_SET_HEROICONS;
    }
}
