package com.newsblur.activity;

import android.app.Application;

import com.newsblur.util.ImageLoader;

public class NewsBlurApplication extends Application {

	ImageLoader imageLoader;
	
	@Override
	public void onCreate() {
		super.onCreate();
		imageLoader = new ImageLoader(this);
	}

	public ImageLoader getImageLoader() {
		return imageLoader;
	}
	
}
