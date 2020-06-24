package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class AllStoriesItemsList extends ItemsList {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        UIUtils.setCustomActionBar(this, R.drawable.ak_icon_allstories, getResources().getString(R.string.all_stories_title));
	}

	@Override
	protected void onNewIntent(Intent intent) {
		super.onNewIntent(intent);
		setIntent(intent);
		if (getIntent().getBooleanExtra(EXTRA_WIDGET_STORY, false)) {
			String hash = (String) getIntent().getSerializableExtra(EXTRA_STORY_HASH);
			UIUtils.startReadingActivity(fs, hash, this);
		}
	}
}
