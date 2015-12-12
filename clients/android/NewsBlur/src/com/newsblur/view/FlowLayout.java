package com.newsblur.view;

import android.content.Context;
import android.content.res.TypedArray;
import android.text.TextUtils;
import android.util.AttributeSet;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

/**
 * A ViewGroup that arranges child views in a similar way to text, with them laid
 * out one line at a time and "wrapping" to the next line as needed. Handles ImageView
 * children as special case that should all be squares of the same size, for forming
 * icon grids. Many iterations ago inspired by the code referenced below.
 *  
 * @see http://stackoverflow.com/questions/549451/line-breaking-widget-layout-for-android
 */
public class FlowLayout extends ViewGroup {

    private final static int FLOW_RIGHT = 0;
    private final static int FLOW_LEFT = 1;
    private final static int DEFAULT_IMAGEVIEW_SIZE_DP = 25;
    private final static int DEFAULT_CHILD_SPACING_DP = 3;

    private final int flowDirection;
    private final int imageViewSizePx;
    private final int childSpacingPx;

    public FlowLayout(Context context) {
        super(context);
        flowDirection = FLOW_RIGHT;
        imageViewSizePx = UIUtils.dp2px(context, DEFAULT_IMAGEVIEW_SIZE_DP);
        childSpacingPx = UIUtils.dp2px(context, DEFAULT_CHILD_SPACING_DP);
    }

    public FlowLayout(Context context, AttributeSet attrs) {
        super(context, attrs);
        
        TypedArray styledAttributes = context.obtainStyledAttributes(attrs, R.styleable.FlowLayout);
        String flowAttribute = styledAttributes.getString(R.styleable.FlowLayout_flow);
        if (!TextUtils.isEmpty(flowAttribute) && TextUtils.equals(flowAttribute, "left")) { 
            flowDirection = FLOW_LEFT;  
        } else {
            flowDirection = FLOW_RIGHT;
        }
        int imageViewSizeAttributeDp = styledAttributes.getInt(R.styleable.FlowLayout_imageViewSize, DEFAULT_IMAGEVIEW_SIZE_DP);
        imageViewSizePx = UIUtils.dp2px(context, imageViewSizeAttributeDp);
        childSpacingPx = UIUtils.dp2px(context, DEFAULT_CHILD_SPACING_DP);
        styledAttributes.recycle();
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        final int count = getChildCount();

        int width = 0;
        if ( (MeasureSpec.getMode(widthMeasureSpec) == MeasureSpec.EXACTLY) ||
             (MeasureSpec.getMode(widthMeasureSpec) == MeasureSpec.AT_MOST) ) {
            width = MeasureSpec.getSize(widthMeasureSpec);
        } else {
            throw new IllegalStateException("FlowLayout must have an expected width");
        }

        int height = 0;
        if (MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.EXACTLY) {
            height = MeasureSpec.getSize(heightMeasureSpec);
            // even though we don't need to calculate height, we still need to tell all of our
            // childern how to measure
            int childHeightMeasureSpec = MeasureSpec.makeMeasureSpec(height - getPaddingTop() - getPaddingBottom(), MeasureSpec.AT_MOST);
            for (int i = 0; i < count; i++) {
                View child = getChildAt(i);
                if (child.getVisibility() != GONE) {
                    if (!(child instanceof ImageView)) { 
                        child.measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.AT_MOST), childHeightMeasureSpec);
                    }
                }
            }
        } else {
            int line_height = 0;
            int xpos = (flowDirection == FLOW_RIGHT) ? getPaddingLeft() : (width-getPaddingRight());
            int ypos = getPaddingTop();
            int childHeightMeasureSpec;
            if (MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.AT_MOST) {
                childHeightMeasureSpec = MeasureSpec.makeMeasureSpec(MeasureSpec.getSize(heightMeasureSpec) - getPaddingTop() - getPaddingBottom(), MeasureSpec.AT_MOST);
            } else {
                childHeightMeasureSpec = MeasureSpec.makeMeasureSpec(MeasureSpec.UNSPECIFIED, MeasureSpec.UNSPECIFIED);
            }
            for (int i = 0; i < count; i++) {
                View child = getChildAt(i);
                if (child.getVisibility() != GONE) {
                    int childw;
                    int childh;
                    if (child instanceof ImageView) { 
                        childw = imageViewSizePx;
                        childh = imageViewSizePx;
                    } else {
                        child.measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.AT_MOST), childHeightMeasureSpec);
                        childw = child.getMeasuredWidth();
                        childh = child.getMeasuredHeight();
                    }
                    line_height = Math.max(line_height, childh);
                    if (flowDirection == FLOW_RIGHT && xpos + childw > (width-getPaddingRight())) {
                        xpos = getPaddingLeft();
                        ypos += line_height + childSpacingPx;
                        line_height = 0;
                    } else if (flowDirection == FLOW_LEFT && xpos - childw < getPaddingLeft()) {
                        xpos = width-getPaddingRight();
                        ypos += line_height + childSpacingPx;
                        line_height = 0;
                    }
                    if (flowDirection == FLOW_RIGHT) {
                        xpos += childw + childSpacingPx;
                    } else {
                        xpos -= childw + childSpacingPx;
                    }
                }
            }
            height = ypos + line_height;

            if (MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.AT_MOST) {
                int maxHeight = MeasureSpec.getSize(heightMeasureSpec);
                if (height > maxHeight) height = maxHeight;
            }
        }

        setMeasuredDimension(width, height);
    }

    @Override
    protected void onLayout(boolean changed, int l, int t, int r, int b) {
        final int count = getChildCount();
        final int width = r - l;
        int line_height = 0;
        int xpos = (flowDirection == FLOW_RIGHT) ? getPaddingLeft() : (width-getPaddingRight());
        int ypos = getPaddingTop();
        for (int i = 0; i < count; i++) {
            final View child = getChildAt(i);
            if (child.getVisibility() != GONE) {
                int childw;
                int childh;
                if (child instanceof ImageView) {
                    childw = imageViewSizePx;
                    childh = imageViewSizePx;
                } else {
                    childw = child.getMeasuredWidth();
                    childh = child.getMeasuredHeight(); 
                }
                line_height = Math.max(line_height, childh);
                if (flowDirection == FLOW_RIGHT && xpos + childw > (width-getPaddingLeft())) {
                    xpos = getPaddingLeft();
                    ypos += line_height + childSpacingPx;
                    line_height = 0;
                } else if (flowDirection == FLOW_LEFT && xpos - childw < getPaddingRight()) {
                    xpos = width-getPaddingRight();
                    ypos += line_height + childSpacingPx;
                    line_height = 0;
                }
                
                if (flowDirection == FLOW_RIGHT) {
                    child.layout(xpos, ypos, xpos + childw, ypos + childh);
                    xpos += childw + childSpacingPx;
                } else {
                    child.layout(xpos - childw, ypos, xpos, ypos + childh);
                    xpos -= childw + childSpacingPx;
                }
            }
        }
    }
}
