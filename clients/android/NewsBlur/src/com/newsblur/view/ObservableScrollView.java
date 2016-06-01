package com.newsblur.view;

import java.util.HashSet;
import java.util.Set;

import android.content.Context;
import android.util.AttributeSet;
import android.widget.ScrollView;

public class ObservableScrollView extends ScrollView {

    private Set<ScrollChangeListener> changeListeners = new HashSet<ScrollChangeListener>();

	public ObservableScrollView(Context context) {
		super(context);
	}
	
	public ObservableScrollView(Context context, AttributeSet attrs) {
		super(context, attrs);
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
