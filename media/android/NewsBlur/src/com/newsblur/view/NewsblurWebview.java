package com.newsblur.view;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Message;
import android.util.AttributeSet;
import android.webkit.WebSettings;
import android.webkit.WebView;

import com.newsblur.util.PrefConstants;

public class NewsblurWebview extends WebView {

	private SharedPreferences preferences;
	private Handler handler;
	private float currentSize;

	public NewsblurWebview(Context context, AttributeSet attrs) {
		super(context, attrs);
		
		preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		
		getSettings().setJavaScriptEnabled(true);
		getSettings().setLoadWithOverviewMode(true);
		getSettings().setCacheMode(WebSettings.LOAD_CACHE_ELSE_NETWORK);
		getSettings().setDomStorageEnabled(true);
		getSettings().setSupportZoom(true);
		getSettings().setAppCacheMaxSize(1024*1024*8);
		getSettings().setAppCachePath("/data/data/com.newsblur/cache");
		getSettings().setAllowFileAccess(true);
		getSettings().setAppCacheEnabled(true);
		setVerticalScrollBarEnabled(false);
		setHorizontalScrollBarEnabled(false);
	}
	
	
	
	public void increaseSize() {
		
		if (currentSize < 2.0) {
			currentSize += 0.1f;
			preferences.edit().putFloat(PrefConstants.PREFERENCE_TEXT_SIZE, currentSize).commit();
			setTextSize(currentSize);
		}
	}
	
	public class JavaScriptInterface {
		NewsblurWebview view;
		
		public JavaScriptInterface(NewsblurWebview bookmarkWebView) {
			view = bookmarkWebView;
		}

	    public void scroll(final int i ) {
	    	Message msg = new Message();
	    	msg.obj = Integer.valueOf(i);
	    	msg.what = 0;
	    	handler.dispatchMessage(msg);
	    }
	}
	

	public void setHandler(Handler h) {
		this.handler = h;
		loadUrl("javascript:window.onload=webview.scroll(document.body.scrollHeight)");
	}

	public void setTextSize(float textSize) {
		loadUrl("javascript:document.body.style.fontSize='" + (0.8f + textSize) + "em';");
	}
	
	public void decreaseSize() {
		float currentSize = preferences.getFloat(PrefConstants.PREFERENCE_TEXT_SIZE, 1.0f);
		if (currentSize > 0.8) {
			currentSize -= 0.1f;
		}
	}
	
	
}
