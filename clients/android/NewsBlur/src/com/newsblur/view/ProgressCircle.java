package com.newsblur.view;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Paint.Style;
import android.graphics.Rect;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.util.Log;
import android.widget.ProgressBar;

/**
 * A determinate, circular progress indicator.
 *
 * NB: You *must* set the style attribute of the indicator to "@android:style/Widget.ProgressBar.Horizontal",
 *     even though this is circular.  The parent class disables determinate behaviour otherwise.
 */
public class ProgressCircle extends ProgressBar {

    public ProgressCircle(Context context) {
        super(context);
    }

    public ProgressCircle(Context context, AttributeSet attrs) {
        super(context, attrs);
        this.setIndeterminate(false);
    }

    protected void onDraw(Canvas canvas) {
        
        float angle = (360f * this.getProgress()) / this.getMax();
        Log.d(this.getClass().getName(), "prog: " + this.getProgress());
        Log.d(this.getClass().getName(), "max: " + this.getMax());
        Log.d(this.getClass().getName(), "angle: " + angle);
        Paint p = new Paint();
        p.setColor( Color.GREEN );
        p.setStyle( Style.FILL );
        p.setAntiAlias(true);
        Rect r = new Rect();
        this.getDrawingRect(r);
        canvas.drawArc(new RectF(r), -90f, (-90f+angle), true, p);

    }

}
