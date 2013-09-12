package com.newsblur.activity;

import android.os.Bundle;
import android.text.TextUtils;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import com.newsblur.R;
import com.newsblur.network.APIConstants;

public class AddTwitter extends NbFragmentActivity {

	public static final int TWITTER_AUTHED = 0x20;
	private WebView webview;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		setContentView(R.layout.activity_webcontainer);
		
		webview = (WebView) findViewById(R.id.webcontainer);
		webview.getSettings().setJavaScriptEnabled(true);
		
		webview.setWebViewClient(new WebViewClient() {
		    public boolean shouldOverrideUrlLoading(WebView view, String url){
		    	if (TextUtils.equals(url, APIConstants.NEWSBLUR_URL + "/")) {
		    		AddTwitter.this.setResult(TWITTER_AUTHED);
		    		AddTwitter.this.finish();
		    		return true;
		    	}
		        view.loadUrl(url);
		        return false;
		   }
		});
		
		webview.loadUrl(APIConstants.URL_CONNECT_TWITTER);
	}
	
}
