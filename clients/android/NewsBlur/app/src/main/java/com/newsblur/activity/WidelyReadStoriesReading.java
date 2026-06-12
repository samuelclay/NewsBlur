package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class WidelyReadStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        UIUtils.setupToolbar(this, R.drawable.ic_trending_well_read, getResources().getString(R.string.widely_read_stories_title), false);
    }
}
