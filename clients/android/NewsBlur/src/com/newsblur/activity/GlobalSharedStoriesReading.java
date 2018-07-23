package com.newsblur.activity;

import android.os.Bundle;
import android.view.Menu;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class GlobalSharedStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        UIUtils.setCustomActionBar(this, R.drawable.ak_icon_global, getResources().getString(R.string.global_shared_stories_title));
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        super.onCreateOptionsMenu(menu);
        menu.removeItem(R.id.menu_reading_markunread);
        return true;
    }
}
