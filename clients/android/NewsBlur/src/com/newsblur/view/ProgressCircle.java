package com.newsblur.view;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.util.Log;
import android.widget.ProgressBar;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

/**
 * A determinate, circular progress indicator.
 *
 * NB: You *must* set the style attribute of the indicator to "@android:style/Widget.ProgressBar.Horizontal",
 *     even though this is circular.  The parent class disables determinate behaviour otherwise.
 */
public class ProgressCircle extends ProgressBar {

    /** The thickness of the circular ring, in DP. */
    public static final int STROKE_THICKNESS = 5;

    private int colorRemaining;
    private int colorCompleted;

    public ProgressCircle(Context context) {
        super(context);
        colorRemaining = UIUtils.getColor(context, R.color.progress_circle_remaining);
        colorCompleted = UIUtils.getColor(context, R.color.progress_circle_complete);
    }

    public ProgressCircle(Context context, AttributeSet attrs) {
        super(context, attrs);
        this.setIndeterminate(false);
        colorRemaining = UIUtils.getColor(context, R.color.progress_circle_remaining);
        colorCompleted = UIUtils.getColor(context, R.color.progress_circle_complete);
    }

    protected void onDraw(Canvas canvas) {
        // the outline of the view w.r.t the screen
        Rect r = new Rect();
        this.getDrawingRect(r);

        // a bitmap on which we will render so that clearing can be done
        Bitmap bm = Bitmap.createBitmap(r.width(), r.height(), Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(bm);

        // the outline of the view w.r.t the bitmap
        Rect cr = new Rect();
        cr.top = 0;
        cr.left = 0;
        cr.bottom = r.width();
        cr.right = r.height();

        float angle = (360f * this.getProgress()) / this.getMax();

        Paint p = new Paint();
        p.setStyle( Paint.Style.FILL );
        p.setAntiAlias(true);
        // draw the "remaining" part of the arc as a background
        p.setColor(colorRemaining);
        c.drawArc(new RectF(cr), -90f, 360f, true, p);
        // draw the "completed" part of the arc over that
        p.setColor(colorCompleted);
        c.drawArc(new RectF(cr), -90f, angle, true, p);
        // clear the centre to form a ring 
        p.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.CLEAR));
        p.setAlpha(0xFF);
        RectF innerR = new RectF(cr);
        innerR.top += STROKE_THICKNESS;
        innerR.left += STROKE_THICKNESS;
        innerR.bottom -= STROKE_THICKNESS;
        innerR.right -= STROKE_THICKNESS;
        c.drawArc(innerR, -90f, 360f, true, p);

        // apply the bitmap onto this view
        canvas.drawBitmap(bm, r.left, r.top, null);
    }

}
