package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class AllSharedStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        UIUtils.setupToolbar(this, R.drawable.ic_all_shares, getResources().getString(R.string.all_shared_stories_title), false);
    }

}
