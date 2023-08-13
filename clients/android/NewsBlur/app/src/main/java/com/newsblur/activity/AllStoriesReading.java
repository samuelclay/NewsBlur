package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class AllStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        UIUtils.setupToolbar(this, R.drawable.ic_all_stories, getResources().getString(R.string.all_stories_title), false);
    }

}
