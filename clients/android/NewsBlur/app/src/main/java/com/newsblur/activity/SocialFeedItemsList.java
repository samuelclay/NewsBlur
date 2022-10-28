package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.di.IconLoader;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.UIUtils;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class SocialFeedItemsList extends ItemsList {

	@Inject
	@IconLoader
	ImageLoader iconLoader;

	public static final String EXTRA_SOCIAL_FEED = "social_feed";

	private SocialFeed socialFeed;

	@Override
	protected void onCreate(Bundle bundle) {
	    socialFeed = (SocialFeed) getIntent().getSerializableExtra(EXTRA_SOCIAL_FEED);
		super.onCreate(bundle);
				
        UIUtils.setupToolbar(this, socialFeed.photoUrl, socialFeed.feedTitle, iconLoader, false);
	}

	@Override
	String getSaveSearchFeedId() {
		return "social:" + socialFeed.userId;
	}
}
