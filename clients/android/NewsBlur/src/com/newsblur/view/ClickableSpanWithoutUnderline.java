package com.newsblur.view;

import android.text.TextPaint;
import android.text.style.ClickableSpan;

/**
 * Created by mark on 28/05/15.
 */
public abstract class ClickableSpanWithoutUnderline extends ClickableSpan {

    @Override
    public void updateDrawState(TextPaint ds) {
        super.updateDrawState(ds);
        ds.setUnderlineText(false);
    }

}
