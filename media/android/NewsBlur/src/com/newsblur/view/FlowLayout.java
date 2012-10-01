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
 * A viewGroup that arranges child views in a similar way to text, with them laid
 * out one line at a time and "wrapping" to the next line as needed. It handles ImageView children
 * as special cases. It's a modified version of the code referenced below.
 *  
 * @author Ryan Bateman / Henrik Gustafsson
 * @see http://stackoverflow.com/questions/549451/line-breaking-widget-layout-for-android
 *
 */
public class FlowLayout extends ViewGroup {

    private int line_height;
    private int defaultImageLength = 0;
    
    private final int FLOW_RIGHT = 0;
    private final int FLOW_LEFT = 1;
    
    // By default, flow left to right
    private int flowDirection = FLOW_RIGHT;
	private String TAG = "FlowLayout";
    
    public static class LayoutParams extends ViewGroup.LayoutParams {

        public final int horizontal_spacing;
        public final int vertical_spacing;

        /**
         * @param horizontal_spacing Pixels between items, horizontally
         * @param vertical_spacing Pixels between items, vertically
         */
        public LayoutParams(int horizontal_spacing, int vertical_spacing) {
            super(0, 0);
            this.horizontal_spacing = horizontal_spacing;
            this.vertical_spacing = vertical_spacing;
        }
    }

    public FlowLayout(Context context) {
        super(context);
        defaultImageLength = UIUtils.convertDPsToPixels(context, 25);
    }

    public FlowLayout(Context context, AttributeSet attrs) {
        super(context, attrs);
        
        TypedArray styledAttributes = context.obtainStyledAttributes(attrs, R.styleable.FlowLayout);
        String flowAttribute = styledAttributes.getString(R.styleable.FlowLayout_flow);
        int defaultImageSizeAttribute = styledAttributes.getInt(R.styleable.FlowLayout_defaultImageSize, 25);
        defaultImageLength = UIUtils.convertDPsToPixels(context, defaultImageSizeAttribute);
        
        if (!TextUtils.isEmpty(flowAttribute) && TextUtils.equals(flowAttribute, "left")) { 
        	flowDirection = FLOW_LEFT;	
        }
        
        
        styledAttributes.recycle();
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        assert (MeasureSpec.getMode(widthMeasureSpec) != MeasureSpec.UNSPECIFIED);

        final int width = MeasureSpec.getSize(widthMeasureSpec) - getPaddingLeft() - getPaddingRight();
        int height = MeasureSpec.getSize(heightMeasureSpec) - getPaddingTop() - getPaddingBottom();
        final int count = getChildCount();
        int line_height = 0;

        int xpos;
        int ypos= getPaddingTop();
        
        xpos = (flowDirection == FLOW_RIGHT) ? getPaddingLeft() : getWidth();

        int childHeightMeasureSpec;
        if (MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.AT_MOST) {
            childHeightMeasureSpec = MeasureSpec.makeMeasureSpec(height, MeasureSpec.AT_MOST);
        } else {
            childHeightMeasureSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED);
        }

        for (int i = 0; i < count; i++) {
            final View child = getChildAt(i);
            if (child.getVisibility() != GONE) {
                final LayoutParams lp = (LayoutParams) child.getLayoutParams();
                int childw;
                
                if (child instanceof ImageView) { 
                	child.measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.AT_MOST), defaultImageLength);
                	childw = defaultImageLength;
                	line_height = Math.max(line_height, defaultImageLength + lp.vertical_spacing);
                	Log.d("FlowLayout", "Measured line height:" + line_height);
                } else {
                	child.measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.AT_MOST), childHeightMeasureSpec);
                	childw = child.getMeasuredWidth();
                	line_height = Math.max(line_height, child.getMeasuredHeight() + lp.vertical_spacing);
                }

                if (flowDirection == FLOW_RIGHT && xpos + childw > width) {
                	xpos = getPaddingLeft();
                    ypos += line_height;
                } else if (flowDirection == FLOW_LEFT && xpos - childw < 0) {
                	xpos = getWidth();
                    ypos += line_height;
                }
                
                if (flowDirection == FLOW_RIGHT) {
                	xpos += childw + lp.horizontal_spacing;
                } else {
                	xpos -= childw + lp.horizontal_spacing;
                }
            }
        }
        this.line_height = line_height;

        if (MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.UNSPECIFIED) {
            height = ypos + line_height;
        } else if (MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.AT_MOST) {
            if (ypos + line_height < height) {
                height = ypos + line_height;
            }
        }
        
        setMeasuredDimension(width, height);
    }

    @Override
    protected ViewGroup.LayoutParams generateDefaultLayoutParams() {
    	int defaultPadding = UIUtils.convertDPsToPixels(getContext(), 3);
        return new LayoutParams(defaultPadding, defaultPadding);
    }

    @Override
    protected boolean checkLayoutParams(ViewGroup.LayoutParams p) {
        if (p instanceof LayoutParams) {
            return true;
        }
        return false;
    }

    @Override
    protected void onLayout(boolean changed, int l, int t, int r, int b) {
    	
        final int count = getChildCount();
        final int width = r - l;
        
        int xpos = (flowDirection == FLOW_RIGHT) ? getPaddingLeft() : getWidth();
        int ypos = getPaddingTop();

        for (int i = 0; i < count; i++) {
            final View child = getChildAt(i);
            if (child.getVisibility() != GONE) {
            	int childw;
            	int childh;
            	if (child instanceof ImageView) {
            		childw = defaultImageLength;
            		childh = defaultImageLength;
            	} else {
            		childw = child.getMeasuredWidth();
                    childh = child.getMeasuredHeight();	
            	}
                final LayoutParams lp = (LayoutParams) child.getLayoutParams();
                if (flowDirection == FLOW_RIGHT && xpos + childw > width) {
                	xpos = getPaddingLeft();
                    ypos += line_height;
                } else if (flowDirection == FLOW_LEFT && xpos - childw < 0) {
                	xpos = getWidth();
                	ypos += line_height;
                }
                
                if (flowDirection == FLOW_RIGHT) {
                	child.layout(xpos, ypos, xpos + childw, ypos + childh);
                	xpos += childw + lp.horizontal_spacing;
                } else {
                	child.layout(xpos - childw, ypos, xpos, ypos + childh);
                	xpos -= childw + lp.horizontal_spacing;
                }
            }
        }
    }
}
