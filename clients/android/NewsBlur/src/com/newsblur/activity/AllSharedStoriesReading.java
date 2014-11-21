package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;
import android.content.CursorLoader;
import android.content.Loader;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryOrder;

public class AllSharedStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        setTitle(getResources().getString(R.string.all_shared_stories));

        // No sourceUserId since this is all shared stories. The sourceUsedId for each story will be used.
        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), getContentResolver(), defaultFeedView, null);

        getLoaderManager().initLoader(0, null, this);
    }

}
