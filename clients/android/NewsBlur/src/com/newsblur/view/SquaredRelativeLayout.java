package com.newsblur.view;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.widget.RelativeLayout;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class SquaredRelativeLayout extends RelativeLayout {

    private  int addedHeightPx;

    public SquaredRelativeLayout(Context context) {
        super(context);
        addedHeightPx = 0;
    }

    public SquaredRelativeLayout(Context context, AttributeSet attrs) {
        super(context, attrs);
        bindAttrs(context, attrs);
    }

    public SquaredRelativeLayout(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        bindAttrs(context, attrs);
    }

    private void bindAttrs(Context context, AttributeSet attrs) {
        TypedArray styledAttributes = context.obtainStyledAttributes(attrs, R.styleable.SquaredRelativeLayout);
        int addedHeightAttributeDp = styledAttributes.getInt(R.styleable.SquaredRelativeLayout_addedHeight, 0);
        addedHeightPx = UIUtils.dp2px(context, addedHeightAttributeDp);
        styledAttributes.recycle();
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        if (heightMeasureSpec > widthMeasureSpec) {
            super.onMeasure(widthMeasureSpec, widthMeasureSpec + addedHeightPx);
        } else {
            super.onMeasure(heightMeasureSpec, heightMeasureSpec + addedHeightPx);
        }
    }
}
