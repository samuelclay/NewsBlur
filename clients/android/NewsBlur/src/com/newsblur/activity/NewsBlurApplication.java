package com.newsblur.activity;

import android.app.Application;

import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ImageLoader;

public class NewsBlurApplication extends Application {

    // these need to be app-level singletons, but they can't be safely initiated until
    // the app is fully started.  create them here and then vend them via FeedUtils like
    // most other utility functions.
	private ImageLoader imageLoader;
    private BlurDatabaseHelper dbHelper;
	
	@Override
	public void onCreate() {
		super.onCreate();
		imageLoader = new ImageLoader(this);
        dbHelper = new BlurDatabaseHelper(this);
        FeedUtils.offerDB(dbHelper);
        FeedUtils.offerImageLoader(imageLoader);
	}

}
