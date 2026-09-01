package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class WidelyReadStoriesItemsList extends ItemsList {

    @Override
    protected void onCreate(Bundle bundle) {
        super.onCreate(bundle);

        UIUtils.setupToolbar(this, R.drawable.ic_trending_well_read, getResources().getString(R.string.widely_read_stories_title), false);
    }

    @Override
    String getSaveSearchFeedId() {
        return "trending:well_read";
    }
}
