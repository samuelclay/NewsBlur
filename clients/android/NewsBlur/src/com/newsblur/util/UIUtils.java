package com.newsblur.util;

import static android.graphics.Bitmap.Config.ARGB_8888;
import static android.graphics.Color.WHITE;
import static android.graphics.PorterDuff.Mode.DST_IN;

import android.app.Activity;
import android.app.ActionBar;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapShader;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PorterDuffXfermode;
import android.graphics.RectF;
import android.graphics.Shader;
import android.os.Build;
import android.os.Handler;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup.LayoutParams;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.*;

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
            result = Bitmap.createBitmap(result, x, y, newSize, newSize);
        }
        if ((radius > 0f) && (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)) {
            int width = result.getWidth();
            int height = result.getHeight();
            Bitmap canvasMap = Bitmap.createBitmap(width, height, ARGB_8888);
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
    public static void safeToast(Context c, int rid, int duration) {
        if (c != null) {
            Toast.makeText(c, rid, duration).show();
        }
    }

    public static void safeToast(Context c, String text, int duration) {
        if ((c != null) && (text != null)) {
            Toast.makeText(c, text, duration).show();
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
        android.os.Debug.MemoryInfo[] mi = activityManager.getProcessMemoryInfo(pids);
        memInfo = memInfo + (mi[0].getTotalPss() / 1024) + "MB used)";
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

}
