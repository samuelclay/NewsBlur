package com.newsblur.util;

import java.io.File;
import java.util.Map;

import static android.graphics.Bitmap.Config.ARGB_8888;

import android.app.Activity;
import android.app.ActionBar;
import android.content.Context;
import android.content.Intent;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.BitmapShader;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Shader;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.os.Handler;
import android.util.Log;
import android.util.TypedValue;
import android.text.Html;
import android.text.Spanned;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.ContextMenu;
import android.view.MenuInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup.LayoutParams;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.*;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;

public class UIUtils {

    private UIUtils() {} // util class - no instances
	
    @SuppressWarnings("deprecation")
	public static Bitmap clipAndRound(Bitmap source, float radius, boolean clipSquare) {
        Bitmap result = source;
        if (clipSquare) {
            int width = result.getWidth();
            int height = result.getHeight();
            int newSize = Math.min(width, height);
            int x = (width-newSize) / 2;
            int y = (height-newSize) / 2;
            try {
                result = Bitmap.createBitmap(result, x, y, newSize, newSize);
            } catch (Throwable t) {
                // even on reasonably modern systems, it is common for the bitmap processor to reject
                // requests if it thinks memory is even remotely constrained.
                android.util.Log.e(UIUtils.class.getName(), "couldn't process icon or thumbnail", t);
                return null;
            }
        }
        if ((radius > 0f) && (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)) {
            int width = result.getWidth();
            int height = result.getHeight();
            Bitmap canvasMap = null;
            try {
                canvasMap = Bitmap.createBitmap(width, height, ARGB_8888);
            } catch (Throwable t) {
                // even on reasonably modern systems, it is common for the bitmap processor to reject
                // requests if it thinks memory is even remotely constrained.
                android.util.Log.e(UIUtils.class.getName(), "couldn't process icon or thumbnail", t);
                return null;
            }
            Canvas canvas = new Canvas(canvasMap);
            BitmapShader shader = new BitmapShader(result, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP);
            Paint paint = new Paint();
            paint.setAntiAlias(true);
            paint.setShader(shader);
            canvas.drawRoundRect(0, 0, width, height, radius, radius, paint);
            result = canvasMap;
        }
        return result;
    }

    @SuppressWarnings("deprecation")
    public static Bitmap decodeImage(File f, int maxDim, boolean cropSquare, float roundRadius) {
        try {
            // not only can cache misses occur, users can delete files, the system can clean up
            // files, storage can be unmounted, etc.  fail fast.
            if (f == null) return null;
            if (!f.exists()) return null;

            // the key to efficiently handling images from unknown sources is to downsample
            // to a sensible size ASAP.  feeds can and will give us 50 megapixel files
            // to cram into a grid of hundreds of thumbnails.

            // first decode just enough of the image to determine the source file's size without
            // actually placing it in memory, so we can calculate a downsampling rate. 
            BitmapFactory.Options sizeSniffOpts = new BitmapFactory.Options();
            sizeSniffOpts.inJustDecodeBounds = true;
            BitmapFactory.decodeFile(f.getAbsolutePath(), sizeSniffOpts);
            int sourceWidth = sizeSniffOpts.outWidth;
            int sourceHeight = sizeSniffOpts.outHeight;

            // the system bitmap decoder can fast-downsample only by powers of two. find the
            // biggest divisor possible that doesn't reduce the source below our target dims
            int downsample = 1;
            while ( ((sourceWidth/(downsample*2)) >= maxDim) || ((sourceHeight/(downsample*2)) >= maxDim) ) downsample*=2;

            // decode the file with the now-determined downsample rate
            BitmapFactory.Options decodeOpts = new BitmapFactory.Options();
            decodeOpts.inSampleSize = downsample;
            decodeOpts.inJustDecodeBounds = false;
            //decodeOpts.inPreferredConfig = Bitmap.Config.RGB_565;
            //decodeOpts.inDither = true;
            Bitmap bitmap = BitmapFactory.decodeFile(f.getAbsolutePath(), decodeOpts);

            if (bitmap == null) return null;

            // crop the image square if flagged
            if (cropSquare) {
                // image size will be a squared off version of the now-downsampled original
                int targetSize = Math.min(bitmap.getWidth(), bitmap.getHeight());
                // to clip square, calculate x and y offsets
                int offsetX = (bitmap.getWidth() - targetSize) / 2;
                int offsetY = (bitmap.getHeight() - targetSize) / 2;
                // crop the bitmap. the returned object will likely be the same
                bitmap = Bitmap.createBitmap(bitmap, offsetX, offsetY, targetSize, targetSize);
            }

            // round the corners of the image if the caller would like
            if ((roundRadius > 0f) && (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)) {
                Bitmap canvasMap = null;
                canvasMap = Bitmap.createBitmap(bitmap.getWidth(), bitmap.getHeight(), ARGB_8888);
                Canvas canvas = new Canvas(canvasMap);
                BitmapShader shader = new BitmapShader(bitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP);
                Paint paint = new Paint();
                paint.setAntiAlias(true);
                paint.setShader(shader);
                canvas.drawRoundRect(0, 0, bitmap.getWidth(), bitmap.getHeight(), roundRadius, roundRadius, paint);
                bitmap = canvasMap;
            }

            return bitmap;
        } catch (Throwable t) {
            // due to low memory, corrupt files, or bad source files, image processing can fail
            // in countless ways even on happy systems.  these failures are virtually impossible
            // to classify as fatal, so fail-fast.
            android.util.Log.e(UIUtils.class.getName(), "couldn't process image", t);
            return null;
        }
    }
	
	/*
	 * Convert from device-independent-pixels to pixels for use in custom view drawing, as
	 * used throughout Android. 
	 * See: http://bit.ly/MfsAUZ (Romain Guy's comment)  
	 */
	public static int dp2px(Context context, int dp) {
		float scale = context.getResources().getDisplayMetrics().density;
		return (int) (dp * scale + 0.5f);
	}

	public static float dp2px(Context context, float dp) {
		float scale = context.getResources().getDisplayMetrics().density;
		return dp * scale;
	}

    public static float px2dp(Context context, int px) {
        return ((float) px) / context.getResources().getDisplayMetrics().density;
    }

    /**
     * Sets the alpha of a view, totally hiding the view if the alpha is so low
     * as to be invisible, but also obeying intended visibility.
     */
    public static void setViewAlpha(View v, float alpha, boolean visible) {
        v.setAlpha(alpha);
        if ((alpha < 0.001f) || !visible) {
            v.setVisibility(View.GONE);
        } else {
            v.setVisibility(View.VISIBLE);
        }
    }

    /**
     * Set up our customised ActionBar view that features the specified icon and title, sized
     * away from system standard to meet the NewsBlur visual style.
     */
    public static void setCustomActionBar(Activity activity, String imageUrl, String title) { 
        ImageView iconView = setupCustomActionbar(activity, title);
        FeedUtils.iconLoader.displayImage(imageUrl, iconView, 0, false);
    }

    public static void setCustomActionBar(Activity activity, int imageId, String title) { 
        ImageView iconView = setupCustomActionbar(activity, title);
        iconView.setImageResource(imageId);
    }

    private static ImageView setupCustomActionbar(final Activity activity, String title) {
        // we completely replace the existing title and 'home' icon with a custom view
        activity.getActionBar().setDisplayShowCustomEnabled(true);
        activity.getActionBar().setDisplayShowTitleEnabled(false);
        activity.getActionBar().setDisplayShowHomeEnabled(false);
        View v = LayoutInflater.from(activity).inflate(R.layout.actionbar_custom_icon, null);
        TextView titleView = ((TextView) v.findViewById(R.id.actionbar_text));
        titleView.setText(title);
        ImageView iconView = ((ImageView) v.findViewById(R.id.actionbar_icon));
        // using a custom view breaks the system-standard ability to tap the icon or title to return
        // to the previous activity. Re-implement that here.
        titleView.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                activity.finish();
            }
        });
        iconView.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                activity.finish();
            }
        });
        activity.getActionBar().setCustomView(v, new ActionBar.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.MATCH_PARENT));
        return iconView;
    }

    /**
     * Shows a toast in a circumstance where the context might be null.  This can very
     * rarely happen when toasts are done from async tasks and the context is finished
     * before the task completes, resulting in a crash.  This prevents the crash at the 
     * cost of the toast not being shown.
     */
    public static void safeToast(final Activity c, final int rid, final int duration) {
        if (c != null) {
            c.runOnUiThread(new Runnable() { public void run() {
                Toast.makeText(c, rid, duration).show();
            }});
        }
    }

    public static void safeToast(final Activity c, final String text, final int duration) {
        if ((c != null) && (text != null)) {
            c.runOnUiThread(new Runnable() { public void run() {
                Toast.makeText(c, text, duration).show();
            }});
        }
    }

    /**
     * Restart an activity. See http://stackoverflow.com/a/11651252/70795
     * We post this on the Handler to allow onResume to finish before the activity restarts
     * and avoid an exception.
     */
    public static void restartActivity(final Activity activity) {
        new Handler().post(new Runnable() {

            @Override
            public void run() {
                Intent intent = activity.getIntent();
                intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_NO_ANIMATION);
                activity.overridePendingTransition(0, 0);
                activity.finish();

                activity.overridePendingTransition(0, 0);
                activity.startActivity(intent);
            }
        });
    }

    public static void startReadingActivity(FeedSet fs, String startingHash, Context context) {
        Class activityClass;
		if (fs.isAllSaved()) {
            activityClass = SavedStoriesReading.class;
        } else if (fs.getSingleSavedTag() != null) {
            activityClass = SavedStoriesReading.class;
        } else if (fs.isGlobalShared()) {
            activityClass = GlobalSharedStoriesReading.class;
        } else if (fs.isAllSocial()) {
            activityClass = AllSharedStoriesReading.class;
        } else if (fs.isAllNormal()) {
            activityClass = AllStoriesReading.class;
        } else if (fs.isFolder()) {
            activityClass = FolderReading.class;
        } else if (fs.getSingleFeed() != null) {
            activityClass = FeedReading.class;
        } else if (fs.getSingleSocialFeed() != null) {
            activityClass = SocialFeedReading.class;
        } else if (fs.isAllRead()) {
            activityClass = ReadStoriesReading.class;
        } else if (fs.isInfrequent()) {
            activityClass = InfrequentReading.class;
        } else {
            Log.e(UIUtils.class.getName(), "can't launch reading activity for unknown feedset type");
            return;
        }
        Intent i = new Intent(context, activityClass);
        i.putExtra(Reading.EXTRA_FEEDSET, fs);
        i.putExtra(Reading.EXTRA_STORY_HASH, startingHash);
        context.startActivity(i);
    }

    public static String getMemoryUsageDebug(Context context) {
        String memInfo = " (";
        android.app.ActivityManager activityManager = (android.app.ActivityManager) context.getSystemService(android.app.Activity.ACTIVITY_SERVICE);
        int[] pids = new int[]{android.os.Process.myPid()};
        android.os.Debug.MemoryInfo[] miProc = activityManager.getProcessMemoryInfo(pids);
        android.app.ActivityManager.MemoryInfo miGen = new android.app.ActivityManager.MemoryInfo();
        activityManager.getMemoryInfo(miGen);
        memInfo = memInfo + (miProc[0].getTotalPss() / 1024) + "MB used, " + (miGen.availMem / (1024*1024)) + "MB free)";
        return memInfo;
    }

    @SuppressWarnings("deprecation")
    public static int getColor(Context activity, int rid) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return activity.getResources().getColor(rid, activity.getTheme());
        } else {
            return activity.getResources().getColor(rid);
        }
    }

    /**
     * Get a color defined by our particular way of using styles that are indirectly defined by themes.
     *
     * @param styleId the style that defines the attr, such as com.newsblur.R.attr.defaultText
     * @param rId the resource attribute that defines the color desired, such as android.R.attr.textColor
     */
    public static int getThemedColor(Context context, int styleId, int rId) {
        int[] attrs = {styleId};
        TypedArray val = context.getTheme().obtainStyledAttributes(attrs);
        if (val.peekValue(0).type != TypedValue.TYPE_REFERENCE) {
            com.newsblur.util.Log.w(UIUtils.class.getName(), "styleId didn't resolve to a style");
            val.recycle();
            return Color.MAGENTA;
        }
        int effectiveStyleId = val.getResourceId(0, -1);
        val.recycle();
        if (effectiveStyleId == -1) {
            com.newsblur.util.Log.w(UIUtils.class.getName(), "styleId didn't resolve to a known style");
            return Color.MAGENTA;
        }
        int[] attrs2 = {rId};
        TypedArray val2 = context.getTheme().obtainStyledAttributes(effectiveStyleId, attrs2);
        if ( (val2.peekValue(0).type < TypedValue.TYPE_FIRST_COLOR_INT) || (val2.peekValue(0).type > TypedValue.TYPE_LAST_COLOR_INT)) {
            com.newsblur.util.Log.w(UIUtils.class.getName(), "rId didn't resolve to a color within given style");
            val2.recycle();
            return Color.MAGENTA;
        }
        int result = val2.getColor(0, Color.MAGENTA);
        val2.recycle();
        return result;
    }

    /**
     * Get a resource defined by our particular way of using styles that are indirectly defined by themes.
     *
     * @param styleId the style that defines the attr, such as com.newsblur.R.attr.defaultText
     * @param rId the resource attribute that defines the resource desired, such as android.R.attr.background
     */
    public static int getThemedResource(Context context, int styleId, int rId) {
        int[] attrs = {styleId};
        TypedArray val = context.getTheme().obtainStyledAttributes(attrs);
        if (val.peekValue(0).type != TypedValue.TYPE_REFERENCE) {
            com.newsblur.util.Log.w(UIUtils.class.getName(), "styleId didn't resolve to a style");
            val.recycle();
            return 0;
        }
        int effectiveStyleId = val.getResourceId(0, -1);
        val.recycle();
        if (effectiveStyleId == -1) {
            com.newsblur.util.Log.w(UIUtils.class.getName(), "styleId didn't resolve to a known style");
            return 0;
        }
        int[] attrs2 = {rId};
        TypedArray val2 = context.getTheme().obtainStyledAttributes(effectiveStyleId, attrs2);
        int result = 0;
        try {
            result = val2.getResourceId(0, 0);
        } catch (UnsupportedOperationException uoe) {
            com.newsblur.util.Log.w(UIUtils.class.getName(), "rId didn't resolve to a drawable within given style");
        }
        val2.recycle();
        return result;
    }

    @SuppressWarnings("deprecation")
    public static Drawable getDrawable(Context activity, int rid) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return activity.getResources().getDrawable(rid, activity.getTheme());
        } else {
            return activity.getResources().getDrawable(rid);
        }
    }

    /**
     * Sets the background resource of a view, working around a platform bug that causes the declared
     * padding to get reset.
     */
    public static void setViewBackground(View v, Drawable background) {
        // due to a framework bug, the below modification of background resource also resets the declared
        // padding on the view.  save a copy of said padding so it can be re-applied after the change.
        int oldPadL = v.getPaddingLeft();
        int oldPadT = v.getPaddingTop();
        int oldPadR = v.getPaddingRight();
        int oldPadB = v.getPaddingBottom();

        v.setBackground(background);

        v.setPadding(oldPadL, oldPadT, oldPadR, oldPadB);
    }

    // API 24 introduced a more customizable impl of fromHtml but also *immediately* deprecated the
    // default version in the same release, so it is necessary to wrap this is plat-specific helper
    @SuppressWarnings("deprecation")
    public static Spanned fromHtml(String html) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            return Html.fromHtml(html, Html.FROM_HTML_MODE_LEGACY);
        } else {
            return Html.fromHtml(html);
        }
    }
    
    private static final String POSIT_HILITE_FORMAT = "<span style=\"color: #33AA33\">%s</span>";
    private static final String NEGAT_HILITE_FORMAT = "<span style=\"color: #AA3333\">%s</span>";

    /**
     * Alter a story title string to highlight intel training hits as positive or negative based
     * upon the associated classifier, using markup that can quickly be parsed by fromHtml.
     */
    public static String colourTitleFromClassifier(String title, Classifier c) {
        String result = title;
        for (Map.Entry<String, Integer> rule : c.title.entrySet()) {
            if (rule.getValue() == Classifier.LIKE) {
                result = result.replace(rule.getKey(), String.format(POSIT_HILITE_FORMAT, rule.getKey()));
            }
            if (rule.getValue() == Classifier.DISLIKE) {
                result = result.replace(rule.getKey(), String.format(NEGAT_HILITE_FORMAT, rule.getKey()));
            }
        }
        return result;
    }

    /**
     * Takes an inflated R.layout.include_intel_row and activates the like/dislike buttons based
     * upon the provided classifier sub-type map while also setting up handlers to alter said
     * map if the buttons are pressed.
     */
    public static void setupIntelDialogRow(final View row, final Map<String,Integer> classifier, final String key) {
        colourIntelDialogRow(row, classifier, key);
        row.findViewById(R.id.intel_row_like).setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                classifier.put(key, Classifier.LIKE);
                colourIntelDialogRow(row, classifier, key);
            }
        });
        row.findViewById(R.id.intel_row_dislike).setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                classifier.put(key, Classifier.DISLIKE);
                colourIntelDialogRow(row, classifier, key);
            }
        });
        row.findViewById(R.id.intel_row_clear).setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                classifier.put(key, Classifier.CLEAR_LIKE);
                colourIntelDialogRow(row, classifier, key);
            }
        });
    }

    private static void colourIntelDialogRow(View row, Map<String,Integer> classifier, String key) {
        if (Integer.valueOf(Classifier.LIKE).equals(classifier.get(key))) {
            row.findViewById(R.id.intel_row_like).setBackgroundResource(R.drawable.ic_like_active);
            row.findViewById(R.id.intel_row_dislike).setBackgroundResource(R.drawable.ic_dislike_gray55);
            row.findViewById(R.id.intel_row_clear).setBackgroundResource(R.drawable.ic_clear_gray55);
        } else 
        if (Integer.valueOf(Classifier.DISLIKE).equals(classifier.get(key))) {
            row.findViewById(R.id.intel_row_like).setBackgroundResource(R.drawable.ic_like_gray55);
            row.findViewById(R.id.intel_row_dislike).setBackgroundResource(R.drawable.ic_dislike_active);
            row.findViewById(R.id.intel_row_clear).setBackgroundResource(R.drawable.ic_clear_gray55);
        } else {
            row.findViewById(R.id.intel_row_like).setBackgroundResource(R.drawable.ic_like_gray55);
            row.findViewById(R.id.intel_row_dislike).setBackgroundResource(R.drawable.ic_dislike_gray55);
            row.findViewById(R.id.intel_row_clear).setBackgroundResource(R.drawable.ic_clear_gray55);
        }
    }

    public static void inflateStoryContextMenu(ContextMenu menu, MenuInflater inflater, Context context, FeedSet fs, Story story) {
        if (PrefsUtils.getStoryOrder(context, fs) == StoryOrder.NEWEST) {
            inflater.inflate(R.menu.context_story_newest, menu);
        } else {
            inflater.inflate(R.menu.context_story_oldest, menu);
        }

        if (story.starred) {
            menu.removeItem(R.id.menu_save_story);
        } else {
            menu.removeItem(R.id.menu_unsave_story);
        }

        if ( fs.isGlobalShared() ||
             fs.isFilterSaved() ||
             fs.isAllSaved() ) {
            menu.removeItem(R.id.menu_mark_story_as_read);
            menu.removeItem(R.id.menu_mark_story_as_unread);
        } else {
            if (story.read) {
                menu.removeItem(R.id.menu_mark_story_as_read);
            } else {
                menu.removeItem(R.id.menu_mark_story_as_unread);
            }
        }

        if ( fs.isAllRead() ||
             fs.isInfrequent() ||
             fs.isAllSocial() ||
             fs.isGlobalShared() ||
             fs.isAllSaved() ) {
            menu.removeItem(R.id.menu_mark_newer_stories_as_read);
            menu.removeItem(R.id.menu_mark_older_stories_as_read);
        }
        if (fs.isFilterSaved()) {
            menu.removeItem(R.id.menu_intel);
        }
    }

    public static int decodeColourValue(String val, int defaultVal) {
        int result = defaultVal;
        if (val == null) return result;
        if (TextUtils.equals(val, "null")) return result;
        try {
            result = Color.parseColor("#" + val);
        } catch (NumberFormatException nfe) {
            com.newsblur.util.Log.e(UIUtils.class.getName(), "feed supplied bad color info: " + nfe.getMessage());
        }
        return result;
    }

}
