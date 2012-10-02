package com.newsblur.activity;

import android.os.Bundle;
import android.text.TextUtils;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.newsblur.R;

public class ImportFeeds extends SherlockFragmentActivity {
	
	private WebView webContainer;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		setContentView(R.layout.activity_webcontainer);
		
		webContainer = (WebView) findViewById(R.id.webcontainer);
		webContainer.getSettings().setJavaScriptEnabled(true);
		
		webContainer.setWebViewClient(new WebViewClient() {
		    public boolean shouldOverrideUrlLoading(WebView view, String url){
		    	if (TextUtils.equals(url, "http://www.newsblur.com/")) {
		    		ImportFeeds.this.setResult(RESULT_OK);
		    		ImportFeeds.this.finish();
		    		return true;
		    	}
		        view.loadUrl(url);
		        return false;
		   }
		});
		
		webContainer.loadUrl("http://www.newsblur.com/import/authorize/");
		
	}

}
