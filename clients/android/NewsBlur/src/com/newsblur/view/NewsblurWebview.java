package com.newsblur.view;

import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Message;
import android.util.AttributeSet;
import android.util.Log;
import android.webkit.WebSettings;
import android.webkit.WebView;

import com.newsblur.util.AppConstants;

public class NewsblurWebview extends WebView {

	private Handler handler;

	public NewsblurWebview(Context context, AttributeSet attrs) {
		super(context, attrs);

		setVerticalScrollBarEnabled(false);
		setHorizontalScrollBarEnabled(false);
		getSettings().setJavaScriptEnabled(true);
		getSettings().setLoadWithOverviewMode(true);
		getSettings().setCacheMode(WebSettings.LOAD_CACHE_ELSE_NETWORK);
		getSettings().setDomStorageEnabled(true);
		getSettings().setSupportZoom(true);
		getSettings().setAppCacheMaxSize(1024*1024*8);
		getSettings().setAppCachePath("/data/data/com.newsblur/cache");
		getSettings().setAllowFileAccess(true);
		getSettings().setAppCacheEnabled(true);
        this.setScrollBarStyle(SCROLLBARS_INSIDE_OVERLAY);
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

	public void onPause() {
        // TODO: is there anything more we can do to get media content to stop playing on pause?
        super.onPause();
    }

    public void onResume() {
        // TODO: restore media content if it was disabled above
        super.onResume();
    }

    public void setTextSize(float textSize) {
        Log.d("Reading", "Setting textsize to " + (AppConstants.FONT_SIZE_LOWER_BOUND + textSize));
        String script = "javascript:document.body.style.fontSize='" + (AppConstants.FONT_SIZE_LOWER_BOUND + textSize) + "em';";
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            evaluateJavascript(script, null);
        } else {
            loadUrl(script);
        }
	}
}
