package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class LongReadsItemsList extends ItemsList {

    @Override
    protected void onCreate(Bundle bundle) {
        super.onCreate(bundle);

        UIUtils.setupToolbar(this, R.drawable.ic_trending_long_reads, getResources().getString(R.string.long_reads_title), false);
    }

    @Override
    String getSaveSearchFeedId() {
        return "trending:long_reads";
    }
}
