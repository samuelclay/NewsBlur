package com.newsblur.activity;

import android.content.Intent;

import com.newsblur.util.UIUtils;

/**
 * All Site Stories. The toolbar and saved search id come from StoryListKind.kt; this list also
 * opens a story tapped in the home screen widget.
 */
public class AllStoriesItemsList extends ItemsList {

	@Override
	protected void onNewIntent(Intent intent) {
		super.onNewIntent(intent);
		setIntent(intent);
		if (getIntent().getBooleanExtra(EXTRA_WIDGET_STORY, false)) {
			String hash = (String) getIntent().getSerializableExtra(EXTRA_STORY_HASH);
			UIUtils.startReadingActivity(this, fs, hash, readingActivityLaunch);
		}
	}
}
