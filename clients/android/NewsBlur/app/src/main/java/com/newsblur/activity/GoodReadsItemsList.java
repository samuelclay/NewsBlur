package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class GoodReadsItemsList extends ItemsList {

    @Override
    protected void onCreate(Bundle bundle) {
        super.onCreate(bundle);

        UIUtils.setupToolbar(this, R.drawable.ic_good_reads, getResources().getString(R.string.good_reads_title), false);
    }

    @Override
    String getSaveSearchFeedId() {
        return "trending:good_reads";
    }
}
