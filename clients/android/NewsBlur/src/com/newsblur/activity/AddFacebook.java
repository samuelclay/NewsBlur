package com.newsblur.activity;

import android.os.Bundle;
import android.text.TextUtils;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import com.newsblur.R;
import com.newsblur.network.APIConstants;

public class AddFacebook extends NbActivity {

	public static final int FACEBOOK_AUTHED = 0x21;
	private WebView webview;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		setContentView(R.layout.activity_webcontainer);
		
		webview = (WebView) findViewById(R.id.webcontainer);
		webview.getSettings().setJavaScriptEnabled(true);
		
		webview.setWebViewClient(new WebViewClient() {
		    public boolean shouldOverrideUrlLoading(WebView view, String url){
		    	if (TextUtils.equals(url, APIConstants.buildUrl("/"))) {
		    		AddFacebook.this.setResult(FACEBOOK_AUTHED);
		    		AddFacebook.this.finish();
		    		return true;
		    	}
		        view.loadUrl(url);
		        return false;
		   }
		});
		
		webview.loadUrl(APIConstants.buildUrl(APIConstants.PATH_CONNECT_FACEBOOK));
	}
	
}
