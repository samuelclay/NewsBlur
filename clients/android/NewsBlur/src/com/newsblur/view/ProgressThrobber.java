package com.newsblur.view;

import android.animation.*;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.util.AttributeSet;
import android.view.animation.*;
import android.view.View;

/**
 * A indeterminate loading indicator that pulses between colours.  Inspired by the
 * 4.X-series impl of MaterialProgressDrawable (but platform-stable, public access,
 * and without the support lib deps) and the NewsBlur.com pulsing load indicator.
 */
public class ProgressThrobber extends View {

    private TimeInterpolator acdcInterp = new AccelerateDecelerateInterpolator();
    private TimeInterpolator lineInterp = new LinearInterpolator();

    private AnimatorSet animator;
    private boolean enabled = true;
    private int[] colors = {Color.CYAN, Color.BLUE, Color.GREEN, Color.LTGRAY};
    private float h;
    private float s;
    private float v;

    public ProgressThrobber(Context context) {
        super(context);
        setupAnimator();
    }

    public ProgressThrobber(Context context, AttributeSet attrs) {
        super(context, attrs);
        setupAnimator();
    }

    public void setColors(int... colors) {
        this.colors = colors;
        setupAnimator();
    }

    /**
     * define a sense of "enabled" to capture whether animations are on or off. if off,
     * the system will scale durations by zero, but with infinite repeats, this doesn't
     * disable so much as create Disco Party Time Mode. If the caller says we should
     * disable animations, just don't throb at all.
     */
    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
        setupAnimator();
    }

    private void setupAnimator() {
        float[] Hs = new float[colors.length];
        float[] Ss = new float[colors.length];
        float[] Vs = new float[colors.length];
        for (int i=0; i<colors.length; i++) {
            int c = colors[i];
            float[] hsv = new float[3];
            Color.colorToHSV(c, hsv);
            Hs[i] = hsv[0];
            Ss[i] = hsv[1];
            Vs[i] = hsv[2];
        }
        ObjectAnimator animatorH = ObjectAnimator.ofFloat(this, "h", Hs);
        animatorH.setRepeatCount(enabled ? ValueAnimator.INFINITE : 0);
        animatorH.setRepeatMode(ValueAnimator.REVERSE);
        animatorH.setInterpolator(acdcInterp);
        ObjectAnimator animatorS = ObjectAnimator.ofFloat(this, "s", Ss);
        animatorS.setRepeatCount(enabled ? ValueAnimator.INFINITE : 0);
        animatorS.setRepeatMode(ValueAnimator.REVERSE);
        animatorS.setInterpolator(lineInterp);
        ObjectAnimator animatorV = ObjectAnimator.ofFloat(this, "v", Vs);
        animatorV.setRepeatCount(enabled ? ValueAnimator.INFINITE : 0);
        animatorV.setRepeatMode(ValueAnimator.REVERSE);
        animatorV.setInterpolator(lineInterp);
        
        animator = new AnimatorSet();
        animator.playTogether(animatorH, animatorS, animatorV);
        animator.setDuration(400L * colors.length);
    }

    public void setH(float h) {
        this.h = h;
    }
    public void setS(float s) {
        this.s = s;
    }
    public void setV(float v) {
        this.v = v;
        this.invalidate();
    }

    protected void onDraw(Canvas canvas) {
        float[] hsv = {h,s,v};
        canvas.drawColor(Color.HSVToColor(hsv));
    }

    @Override
    public synchronized void setVisibility(int visibility) {
        super.setVisibility(visibility);
        if (visibility == View.VISIBLE) {
            if ((animator.getDuration() > 0) && (! animator.isRunning())) {
                animator.start();
            }
        } else {
            animator.end();
        }
    }
    
}
