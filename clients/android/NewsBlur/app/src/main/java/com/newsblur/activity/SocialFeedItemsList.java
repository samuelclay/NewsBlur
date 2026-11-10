package com.newsblur.activity;

import dagger.hilt.android.AndroidEntryPoint;

/**
 * One user's shared stories. The toolbar and saved search id come from StoryListKind.kt, which
 * reads the social feed from EXTRA_SOCIAL_FEED.
 */
@AndroidEntryPoint
public class SocialFeedItemsList extends ItemsList {

	public static final String EXTRA_SOCIAL_FEED = "social_feed";
}
