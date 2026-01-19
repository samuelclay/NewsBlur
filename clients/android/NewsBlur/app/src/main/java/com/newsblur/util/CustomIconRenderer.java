package com.newsblur.util;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffColorFilter;
import android.graphics.Rect;
import android.text.TextPaint;
import android.util.Base64;
import android.util.Log;
import android.util.LruCache;

import androidx.annotation.Nullable;

import com.newsblur.domain.CustomIcon;

import java.io.IOException;
import java.io.InputStream;

/**
 * Utility class for rendering custom icons (emoji, preset, or uploaded images).
 * Follows the same pattern as iOS CustomIconRenderer.
 */
public class CustomIconRenderer {

    private static final String TAG = "CustomIconRenderer";

    // Cache for rendered icons to avoid repeated rendering
    private static final LruCache<String, Bitmap> iconCache = new LruCache<String, Bitmap>(100) {
        @Override
        protected int sizeOf(String key, Bitmap bitmap) {
            return bitmap.getByteCount() / 1024;
        }
    };

    /**
     * Render a custom icon to a Bitmap.
     *
     * @param context Android context for loading assets
     * @param icon The custom icon data
     * @param sizePx The desired size in pixels
     * @return Bitmap of the rendered icon, or null if rendering fails
     */
    @Nullable
    public static Bitmap renderIcon(Context context, CustomIcon icon, int sizePx) {
        if (icon == null || !icon.isValid()) {
            return null;
        }

        // Check cache first
        String cacheKey = getCacheKey(icon, sizePx);
        Bitmap cached = iconCache.get(cacheKey);
        if (cached != null && !cached.isRecycled()) {
            return cached;
        }

        Bitmap result = null;

        try {
            if (icon.isEmoji()) {
                result = renderEmoji(icon.iconData, sizePx);
            } else if (icon.isUpload()) {
                result = renderBase64(icon.iconData, sizePx);
            } else if (icon.isPreset()) {
                Integer color = parseColor(icon.iconColor);
                result = renderPreset(context, icon.iconData, icon.getIconSetOrDefault(), sizePx, color);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error rendering icon: " + e.getMessage());
        }

        if (result != null) {
            iconCache.put(cacheKey, result);
        }

        return result;
    }

    /**
     * Render an emoji character to a Bitmap.
     */
    @Nullable
    public static Bitmap renderEmoji(String emoji, int sizePx) {
        if (emoji == null || emoji.isEmpty()) {
            return null;
        }

        Bitmap bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);

        TextPaint paint = new TextPaint(Paint.ANTI_ALIAS_FLAG);
        // Use 85% of size for font, matching iOS implementation
        paint.setTextSize(sizePx * 0.85f);
        paint.setTextAlign(Paint.Align.CENTER);

        // Measure the emoji
        Rect bounds = new Rect();
        paint.getTextBounds(emoji, 0, emoji.length(), bounds);

        // Center the emoji in the bitmap
        float x = sizePx / 2f;
        float y = (sizePx + bounds.height()) / 2f;

        canvas.drawText(emoji, x, y, paint);

        return bitmap;
    }

    /**
     * Decode a base64-encoded image to a Bitmap.
     */
    @Nullable
    public static Bitmap renderBase64(String base64String, int sizePx) {
        if (base64String == null || base64String.isEmpty()) {
            return null;
        }

        try {
            // Remove data URL prefix if present (e.g., "data:image/png;base64,")
            String cleanBase64 = base64String;
            int commaIndex = base64String.indexOf(',');
            if (commaIndex != -1) {
                cleanBase64 = base64String.substring(commaIndex + 1);
            }

            byte[] decodedBytes = Base64.decode(cleanBase64, Base64.DEFAULT);
            Bitmap original = BitmapFactory.decodeByteArray(decodedBytes, 0, decodedBytes.length);

            if (original == null) {
                return null;
            }

            // Scale to desired size if needed
            if (original.getWidth() != sizePx || original.getHeight() != sizePx) {
                Bitmap scaled = Bitmap.createScaledBitmap(original, sizePx, sizePx, true);
                if (scaled != original) {
                    original.recycle();
                }
                return scaled;
            }

            return original;
        } catch (Exception e) {
            Log.e(TAG, "Error decoding base64 image: " + e.getMessage());
            return null;
        }
    }

    /**
     * Load a preset icon from bundled assets and optionally apply a tint color.
     */
    @Nullable
    public static Bitmap renderPreset(Context context, String iconName, String iconSet, int sizePx, @Nullable Integer color) {
        if (iconName == null || iconName.isEmpty()) {
            return null;
        }

        try {
            // Load PNG from assets/icons/{iconSet}/{iconName}.webp
            String assetPath = "icons/" + iconSet + "/" + iconName + ".webp";
            try (InputStream is = context.getAssets().open(assetPath)) {
                Bitmap original = BitmapFactory.decodeStream(is);

                if (original == null) {
                    Log.w(TAG, "Failed to load preset icon: " + assetPath);
                    return null;
                }

                // Scale to desired size
                Bitmap scaled = original;
                if (original.getWidth() != sizePx || original.getHeight() != sizePx) {
                    scaled = Bitmap.createScaledBitmap(original, sizePx, sizePx, true);
                    if (scaled != original) {
                        original.recycle();
                    }
                }

                // Apply color tint if specified
                if (color != null) {
                    Bitmap tinted = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888);
                    Canvas canvas = new Canvas(tinted);
                    Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
                    paint.setColorFilter(new PorterDuffColorFilter(color, PorterDuff.Mode.SRC_IN));
                    canvas.drawBitmap(scaled, 0, 0, paint);
                    scaled.recycle();
                    return tinted;
                }

                return scaled;
            }
        } catch (IOException e) {
            Log.w(TAG, "Preset icon not found: " + iconName + " in " + iconSet);
            return null;
        } catch (Exception e) {
            Log.e(TAG, "Error loading preset icon: " + e.getMessage());
            return null;
        }
    }

    /**
     * Parse a hex color string to an integer color value.
     */
    @Nullable
    public static Integer parseColor(String hexColor) {
        if (hexColor == null || hexColor.isEmpty()) {
            return null;
        }

        try {
            // Ensure the color starts with #
            String colorStr = hexColor;
            if (!colorStr.startsWith("#")) {
                colorStr = "#" + colorStr;
            }
            return Color.parseColor(colorStr);
        } catch (IllegalArgumentException e) {
            Log.w(TAG, "Invalid color format: " + hexColor);
            return null;
        }
    }

    /**
     * Clear the icon cache.
     */
    public static void clearCache() {
        iconCache.evictAll();
    }

    private static String getCacheKey(CustomIcon icon, int sizePx) {
        return icon.iconType + ":" + icon.iconData + ":" + icon.iconColor + ":" + icon.iconSet + ":" + sizePx;
    }
}
