package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class ReadStoriesItemsList extends ItemsList {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        UIUtils.setupToolbar(this, R.drawable.ic_indicator_unread, getResources().getString(R.string.read_stories_title), false);
	}

	@Override
	String getSaveSearchFeedId() {
		return "read";
	}
}
