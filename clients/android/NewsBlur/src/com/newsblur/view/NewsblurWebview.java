package com.newsblur.view;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.util.AttributeSet;
import android.util.Log;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import com.newsblur.activity.Reading;
import com.newsblur.fragment.ReadingItemFragment;

public class NewsblurWebview extends WebView {

    private NewsblurWebChromeClient webChromeClient;
    private boolean isCustomViewShowing;

    public ReadingItemFragment fragment;
    // we need the less-abstract activity class in order to manipulate the overlay widgets
    public Reading activity;

	public NewsblurWebview(final Context context, AttributeSet attrs) {
		super(context, attrs);

		setVerticalScrollBarEnabled(false);
		setHorizontalScrollBarEnabled(false);
		getSettings().setJavaScriptEnabled(true);
		getSettings().setLoadWithOverviewMode(true);
		getSettings().setCacheMode(WebSettings.LOAD_CACHE_ELSE_NETWORK);
		getSettings().setDomStorageEnabled(true);
		getSettings().setSupportZoom(true);
		getSettings().setAppCachePath(context.getCacheDir().getAbsolutePath());
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
                try {
                    Intent i = new Intent(Intent.ACTION_VIEW);
                    i.setData(uri);
                    context.startActivity(i);
                } catch (Exception e) {
                    Log.wtf(this.getClass().getName(), "device cannot open URLs");
                }
                return true;
            }
        });

        // do the minimum handling of view swapping so that fullscreen HTML5 works, for videos.
        webChromeClient = new NewsblurWebChromeClient();
        setWebChromeClient(webChromeClient);
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

    /**
     * If HTML5 views (like fullscreen video) are to work, we need a container in which to put them.
     * If the activity using this webview creates a hidden layout under/over this webview, we can
     * use it to show things.
     */
    public void setCustomViewLayout(ViewGroup customViewLayout) {
        this.webChromeClient.customViewLayout = customViewLayout;
    }

    /**
     * In order to replace the view using this webview to show HTML5 content, we need to know which
     * view to replace it with.
     */
    public void setWebviewWrapperLayout(View webviewWrapperLayout) {
        this.webChromeClient.webviewWrapperLayout = webviewWrapperLayout;
    }

    // this WCC implements the bare minimum callbacks to get HTML5 fullscreen video working
    class NewsblurWebChromeClient extends WebChromeClient {
        public View customView;
        public ViewGroup customViewLayout;
        public View webviewWrapperLayout;
        public WebChromeClient.CustomViewCallback customViewCallback;
        @Override
        public void onShowCustomView(View view, WebChromeClient.CustomViewCallback callback) {
            if (customViewLayout == null) {
                Log.w(getClass().getName(), "can't show HTML5 custom view, no container set");
                return;
            }
            if (webviewWrapperLayout == null) {
                Log.w(getClass().getName(), "can't show HTML5 custom view, no wrapper set");
                return;
            }
            // some devices like to try and stick other things in here. we know we used a FrameLayout
            // in fragment_readingitem.xml, so require it to prevent weirdness.
            if (! (view instanceof FrameLayout)) {
                Log.w(getClass().getName(), "custom view wasn't a FrameLayout");
               // return;
            }
            if (customView != null) {
                // only allow one custom view at a time
                callback.onCustomViewHidden();
                return;
            }
            isCustomViewShowing = true;
            customView = view;
            webviewWrapperLayout.setVisibility(View.GONE);
            customViewLayout.setVisibility(View.VISIBLE);
            customViewLayout.addView(view, new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            if (activity != null) activity.disableOverlays();
            customViewCallback = callback;
        }
        @Override
        public void onHideCustomView() {
            if (customViewLayout == null) return;
            if (customView == null) return;
            customViewLayout.setVisibility(View.GONE);
            customView.setVisibility(View.GONE);
            customViewLayout.removeView(customView);
            webviewWrapperLayout.setVisibility(View.VISIBLE);
            if (activity != null) activity.enableOverlays();
            // the callback is mandatory on pre-L devices, but crashes some post-L devices. fun.
            if ((customViewCallback != null) && (! customViewCallback.getClass().getName().contains(".chromium."))) {
                customViewCallback.onCustomViewHidden();
            }
            customView = null;
            isCustomViewShowing = false;
        }
        @Override
        public void onProgressChanged(WebView view, int newProgress) {
            if (newProgress == 100) fragment.onWebLoadFinished();
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        // if we are showing HTML5 custom content, the back key should exit that first
        // before exiting the entire activity.
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (isCustomViewShowing) {
                webChromeClient.onHideCustomView();
                return true;
            }
        }
        return super.onKeyDown(keyCode, event);
    }
            
}
