package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.util.UIUtils;

public class FolderReading extends Reading {

    private String folderName;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        folderName = getIntent().getStringExtra(Reading.EXTRA_FOLDERNAME);
        UIUtils.setCustomActionBar(this, R.drawable.g_icn_folder_rss, folderName);

        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), defaultFeedView, null);

        getLoaderManager().initLoader(0, null, this);
    }

}
