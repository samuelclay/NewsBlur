package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class GlobalSharedStoriesItemsList extends ItemsList {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        UIUtils.setupToolbar(this, R.drawable.ic_global_shares, getResources().getString(R.string.global_shared_stories_title), false);
	}

	@Override
	String getSaveSearchFeedId() {
		// doesn't have save search option
		return null;
	}
}
