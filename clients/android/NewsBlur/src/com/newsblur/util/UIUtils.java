package com.newsblur.util;

import static android.graphics.Bitmap.Config.ARGB_8888;
import static android.graphics.Color.WHITE;
import static android.graphics.PorterDuff.Mode.DST_IN;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.PorterDuffXfermode;
import android.graphics.RectF;
import android.os.Build;
import android.view.View;
import android.widget.Toast;

public class UIUtils {
	
	/*
	 * Based on the RoundedCorners code from Square / Eric Burke's "Android UI" talk 
	 * and the GitHub Android code.
	 * https://github.com/github/android
	 */
	
	public static Bitmap roundCorners(Bitmap source, final float radius) {
        int width = source.getWidth();
        int height = source.getHeight();

        Paint paint = new Paint();
        paint.setAntiAlias(true);
        paint.setColor(WHITE);

        Bitmap clipped = Bitmap.createBitmap(width, height, ARGB_8888);
        Canvas canvas = new Canvas(clipped);
        canvas.drawRoundRect(new RectF(0, 0, width, height), radius, radius, paint);
        paint.setXfermode(new PorterDuffXfermode(DST_IN));
        
        Bitmap rounded = Bitmap.createBitmap(width, height, ARGB_8888);
        canvas = new Canvas(rounded);
        canvas.drawBitmap(source, 0, 0, null);
        canvas.drawBitmap(clipped, 0, 0, paint);

        clipped.recycle();

        return rounded;
    }
	
	
	public static Bitmap roundBitmapWithFrame(Bitmap source, Context context) {
        int width = source.getWidth();
        int height = source.getHeight();

        Paint paint = new Paint();
        paint.setAntiAlias(true);
        paint.setColor(WHITE);

        Bitmap clipped = Bitmap.createBitmap(width, height, ARGB_8888);
        Canvas canvas = new Canvas(clipped);
        canvas.drawCircle(width / 2, height / 2, width / 2, paint);
        paint.setXfermode(new PorterDuffXfermode(DST_IN));
        
        Bitmap rounded = Bitmap.createBitmap(width, height, ARGB_8888);
        canvas = new Canvas(rounded);
        canvas.drawBitmap(source, 0, 0, null);
        canvas.drawBitmap(clipped, 0, 0, paint);
        
        clipped.recycle();

        return rounded;
    }
	
	/*
	 * Convert from device-independent-pixels to pixels for use in custom view drawing, as
	 * used throughout Android. 
	 * See: http://bit.ly/MfsAUZ (Romain Guy's comment)  
	 */
	public static int convertDPsToPixels(Context context, final int dps) {
		final float scale = context.getResources().getDisplayMetrics().density;
		return (int) (dps * scale + 0.5f);
	}

    public static float px2dp(Context context, int px) {
        return ((float) px) / context.getResources().getDisplayMetrics().density;
    }

    /**
     * Sets the alpha of a view in a manner that is safe to use before API version 11.
     * If alpha isn't supported, just make the view invisible if the alpha is so low
     * that it may as well be.
     */
    public static void setViewAlpha(View v, float alpha) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
            v.setAlpha(alpha);
        }
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
}
