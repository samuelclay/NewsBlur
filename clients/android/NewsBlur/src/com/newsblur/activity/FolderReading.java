package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.database.MixedFeedsReadingAdapter;

public class FolderReading extends Reading {

    private String folderName;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        folderName = getIntent().getStringExtra(Reading.EXTRA_FOLDERNAME);
        setTitle(folderName);       

        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), defaultFeedView, null);

        getLoaderManager().initLoader(0, null, this);
    }

}
