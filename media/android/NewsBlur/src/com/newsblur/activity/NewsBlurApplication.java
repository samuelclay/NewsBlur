package com.newsblur.activity;

import android.app.Application;

import com.newsblur.util.ImageLoader;

public class NewsBlurApplication extends Application {

	ImageLoader imageLoader;
	
	public NewsBlurApplication() {
		super();
		imageLoader = new ImageLoader(this);
	}
	
	public ImageLoader getImageLoader() {
		return imageLoader;
	}
	
}
