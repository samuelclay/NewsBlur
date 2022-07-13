package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class SavedStoriesItemsList extends ItemsList {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        String title = getResources().getString(R.string.saved_stories_title);
        if (fs.getSingleSavedTag() != null) {
            title = title + " - " + fs.getSingleSavedTag();
        }
        UIUtils.setupToolbar(this, R.drawable.ic_saved, title, false);
	}

    @Override
    String getSaveSearchFeedId() {
	    String feedId = "starred";
	    String savedTag = fs.getSingleSavedTag();
        if (savedTag != null) {
            feedId += ":" + savedTag;
        }
        return feedId;
    }
}
