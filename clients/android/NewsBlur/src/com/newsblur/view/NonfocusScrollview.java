package com.newsblur.view;

import java.util.HashSet;
import java.util.Set;

import android.content.Context;
import android.util.AttributeSet;
import android.util.Log;
import android.view.View;
import android.webkit.WebView;
import android.widget.ScrollView;

public class NonfocusScrollview extends ScrollView {

    private Set<ScrollChangeListener> changeListeners = new HashSet<ScrollChangeListener>();

	public NonfocusScrollview(Context context) {
		super(context);
	}
	
	public NonfocusScrollview(Context context, AttributeSet attrs) {
		super(context, attrs);
	}

	@Override 
	public void requestChildFocus(View child, View focused) { 
		if (focused instanceof WebView ) {
			return;
		}
		super.requestChildFocus(child, focused);
	}

    @Override
    protected void onScrollChanged(int l, int t, int oldl, int oldt) {
        int w = this.getChildAt(0).getMeasuredWidth();
        int h = this.getChildAt(0).getMeasuredHeight();
        for (ScrollChangeListener listener : this.changeListeners) {
            listener.scrollChanged(l, t, w, h);
        }
        super.onScrollChanged(l, t, oldl, oldt);
    }

    public void registerScrollChangeListener(ScrollChangeListener listener) {
        this.changeListeners.add(listener);
    }

    public interface ScrollChangeListener {
        public void scrollChanged(int hPos, int vPos, int currentWidth, int currentHeight);
    }
}
