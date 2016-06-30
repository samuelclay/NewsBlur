package com.newsblur.view;

import java.util.HashSet;
import java.util.Set;

import android.content.Context;
import android.util.AttributeSet;
import android.view.View;
import android.webkit.WebView;
import android.widget.LinearLayout;
import android.widget.ScrollView;

/**
 * Custom scrollview to handle the many quirks of the scroller in which we place
 * the WebView that shows stories.
 */
public class ReadingScrollView extends ScrollView {

    // the fragments/activity that show stories need to know their scroll state. give
    // them a way to subscribe to scroll changes
    public interface ScrollChangeListener {
        public void scrollChanged(int hPos, int vPos, int currentWidth, int currentHeight);
    }

    private Set<ScrollChangeListener> changeListeners = new HashSet<ScrollChangeListener>();

	public ReadingScrollView(Context context) {
		super(context);
	}
	
	public ReadingScrollView(Context context, AttributeSet attrs) {
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

    // a bug/feature in the default WebView implementation will grab focus when the
    // story HTML finishes loading. this has the side effect of scrolling down to the
    // start of the story, past our title/tag/metadata header. setting the
    // descendantFocusability attribute on the scrollview does not reliably stop it.
    // this does have the side effect of breaking key navigation in the WebView, but
    // keeps keynav working on all other parts of the reading view
    @Override
    public void requestChildFocus(View child, View focused) { 
        // the ordering of child=wrapper and focused=webview seems backwards, but
        // that is the focus request that causes the scroll, even if unintuitive
        if ((focused instanceof WebView) && (child instanceof LinearLayout) ) {return;}
        super.requestChildFocus(child, focused);
    }
}
