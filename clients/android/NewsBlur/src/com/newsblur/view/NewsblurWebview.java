package com.newsblur.view;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Message;
import android.util.AttributeSet;
import android.util.Log;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import com.newsblur.util.AppConstants;

public class NewsblurWebview extends WebView {

	public NewsblurWebview(final Context context, AttributeSet attrs) {
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

        // as of v43.0.2357.121 of the system WebView, links no longer open in the user's chosen
        // browser, but open in-app.  Override the default behaviour so it works as expected on
        // all devices.
        setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                Uri uri = Uri.parse(url);
                Intent i = new Intent(Intent.ACTION_VIEW);
                i.setData(uri);
                context.startActivity(i);
                return true;
            }
        });
	}

    public void setTextSize(float textSize) {
        Log.d("Reading", "Setting textsize to " + textSize);
        String script = "javascript:document.body.style.fontSize='" + textSize + "em';";
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            evaluateJavascript(script, null);
        } else {
            loadUrl(script);
        }
	}

    /**
     * http://stackoverflow.com/questions/5994066/webview-ontouch-handling-when-the-user-does-not-click-a-link
     */
    public boolean wasLinkClicked() {
        WebView.HitTestResult result = getHitTestResult();
        return (result != null && result.getExtra() != null);
    }
}
