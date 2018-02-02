package com.newsblur.activity;

import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;

import com.newsblur.R;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.UIUtils;

public class SocialFeedItemsList extends ItemsList {

	public static final String EXTRA_SOCIAL_FEED = "social_feed";

	private SocialFeed socialFeed;

	@Override
	protected void onCreate(Bundle bundle) {
	    socialFeed = (SocialFeed) getIntent().getSerializableExtra(EXTRA_SOCIAL_FEED);
		super.onCreate(bundle);
				
        UIUtils.setCustomActionBar(this, socialFeed.photoUrl, socialFeed.feedTitle);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.itemslist, menu);
		return true;
	}
	
}
