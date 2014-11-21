package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;
import android.content.CursorLoader;
import android.content.Loader;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;

public class FolderReading extends Reading {

    private String folderName;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        folderName = getIntent().getStringExtra(Reading.EXTRA_FOLDERNAME);
        setTitle(folderName);       

        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), getContentResolver(), defaultFeedView, null);

        getLoaderManager().initLoader(0, null, this);
    }

}
