package com.newsblur.view;

import android.content.Context;
import android.util.AttributeSet;
import android.view.View;
import android.webkit.WebView;
import android.widget.ScrollView;

public class NonfocusScrollview extends ScrollView {

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
}
