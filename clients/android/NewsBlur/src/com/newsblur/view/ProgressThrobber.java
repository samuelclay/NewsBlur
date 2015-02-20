package com.newsblur.view;

import android.animation.ObjectAnimator;
import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.util.AttributeSet;
import android.util.Log;
import android.view.View;

import com.newsblur.R;

/**
 * A indeterminate loading indicator that pulses between two colours.
 */
public class ProgressThrobber extends View {

    ObjectAnimator animator;
    int color = Color.BLUE;
    float saturation = 1f;

    public ProgressThrobber(Context context) {
        super(context);
        setupAnimator();
    }

    public ProgressThrobber(Context context, AttributeSet attrs) {
        super(context, attrs);
        setupAnimator();
    }

    public void setColor(int color) {
        this.color = color;
    }

    private void setupAnimator() {
        animator = ObjectAnimator.ofFloat(this, "saturation", 0f, 1f);
        animator.setRepeatCount(ValueAnimator.INFINITE);
        animator.setRepeatMode(ValueAnimator.REVERSE);
        animator.setDuration(1500L);
        animator.start();
    }

    public void setSaturation(float sat) {
        this.saturation = sat;
        this.invalidate();
    }

    protected void onDraw(Canvas canvas) {
        float[] hsv = new float[3];
        Color.colorToHSV(color, hsv);
        hsv[1] = saturation;
        canvas.drawColor(Color.HSVToColor(hsv));
    }

    @Override
    public void setVisibility(int visibility) {
        super.setVisibility(visibility);
        if (visibility == View.VISIBLE) {
            animator.start();
        } else {
            animator.end();
        }
    }
    
}
