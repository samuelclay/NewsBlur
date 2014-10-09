package com.newsblur.activity;

import android.app.Application;

import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ImageLoader;

public class NewsBlurApplication extends Application {

	private ImageLoader imageLoader;
    private BlurDatabaseHelper dbHelper;
	
	@Override
	public void onCreate() {
		super.onCreate();
		imageLoader = new ImageLoader(this);
        dbHelper = new BlurDatabaseHelper(this);
        FeedUtils.offerDB(dbHelper);
	}

	public ImageLoader getImageLoader() {
		return imageLoader;
	}
	
}
