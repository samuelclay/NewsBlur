package com.newsblur.util;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Log;
import android.widget.ImageView;

import com.newsblur.R;

public class ImageLoader {

	private final MemoryCache memoryCache = new MemoryCache();
	private final FileCache fileCache;
	private final ExecutorService executorService;
	private final Map<ImageView, String> imageViews = Collections.synchronizedMap(new WeakHashMap<ImageView, String>());
	private String TAG = "ImageLoader";
	private Context context;

	public ImageLoader(Context context) {
		fileCache = new FileCache(context);
		this.context = context;
		executorService = Executors.newFixedThreadPool(5);
	}
	
	public void displayImage(String url, ImageView imageView) {
		imageViews.put(imageView, url);
		Bitmap bitmap = memoryCache.get(url);
		if (bitmap == null) {
			bitmap = memoryCache.get(url);
		}
		if (bitmap != null) {
			bitmap = UIUtils.roundCorners(bitmap, 5);
			imageView.setImageBitmap(bitmap);
		} else {
			queuePhoto(url, imageView);
			imageView.setImageResource(R.drawable.logo);
		}
	}
	
	// Display an image assuming it's in cache
	public void displayImageByUid(String uid, ImageView imageView) {
		Bitmap bitmap = memoryCache.get(uid);
		if (bitmap != null) {
			bitmap = UIUtils.roundCorners(bitmap, 5);
			imageView.setImageBitmap(bitmap);
		} else {
			File f = fileCache.getFile(uid);
			bitmap = BitmapFactory.decodeFile(f.getAbsolutePath());
			if (bitmap != null) {
				memoryCache.put(uid, bitmap);
				bitmap = UIUtils.roundCorners(bitmap, 5);
				imageView.setImageBitmap(bitmap);
			} else {
				imageView.setImageResource(R.drawable.logo);
			}
		}
	}

	private void queuePhoto(String url, ImageView imageView) {
		PhotoToLoad p = new PhotoToLoad(url, imageView);
		executorService.submit(new PhotosLoader(p));
	}
	
	public boolean hasImage(String uid) {
		if (memoryCache.get(uid) == null) {
			return (fileCache.getFile(uid) != null);
		}
		return true;
	}

	private Bitmap getBitmap(String url) {
		File f = fileCache.getFile(url);
		Bitmap bitmap = BitmapFactory.decodeFile(f.getAbsolutePath());
		
		if (bitmap != null) {
			Log.d(TAG, "Retrieving bitmap From file cache");
			memoryCache.put(url, bitmap);			
			bitmap = UIUtils.roundCorners(bitmap, 5);
			return bitmap;
		}

		try {
			final URL imageUrl = new URL(url);
			final HttpURLConnection conn = (HttpURLConnection)imageUrl.openConnection();
			conn.setConnectTimeout(10000);
			conn.setReadTimeout(30000);
			conn.setInstanceFollowRedirects(true);
			final InputStream inputStream = conn.getInputStream();
			final OutputStream outputStream = new FileOutputStream(f);
			byte[] b = new byte[1024];  
			int read;  
			while ((read = inputStream.read(b)) != -1) {  
				outputStream.write(b, 0, read);  
			}
			bitmap = BitmapFactory.decodeStream(new FileInputStream(f));
			memoryCache.put(url, bitmap);
			outputStream.close();
			bitmap = UIUtils.roundCorners(bitmap, 5);
			return bitmap;
		} catch (IOException ex) {
			Log.e(TAG, "Error loading image from network", ex.fillInStackTrace());
			ex.printStackTrace();
			return null;
		}
	}

	private class PhotoToLoad {
		public String url;
		public ImageView imageView;
		public PhotoToLoad(final String u, final ImageView i) {
			url = u; 
			imageView = i;
		}
	}

	private class PhotosLoader implements Runnable {
		PhotoToLoad photoToLoad;

		public PhotosLoader(PhotoToLoad photoToLoad) {
			this.photoToLoad = photoToLoad;
		}

		@Override
		public void run() {
			if (imageViewReused(photoToLoad)) {
				return;
			}
			
			Bitmap bmp = getBitmap(photoToLoad.url);
			memoryCache.put(photoToLoad.url, bmp);
			if (imageViewReused(photoToLoad)) {
				return;
			}
			
			BitmapDisplayer bitmapDisplayer = new BitmapDisplayer(bmp, photoToLoad);
			Activity a = (Activity) photoToLoad.imageView.getContext();
			a.runOnUiThread(bitmapDisplayer);
		}
	}

	private boolean imageViewReused(PhotoToLoad photoToLoad){
		final String tag = imageViews.get(photoToLoad.imageView);
		return (tag == null || !tag.equals(photoToLoad.url));
	}

	private class BitmapDisplayer implements Runnable {
		Bitmap bitmap;
		PhotoToLoad photoToLoad;

		public BitmapDisplayer(Bitmap b, PhotoToLoad p) {
			bitmap = b;
			photoToLoad = p;
		}
		public void run() {
			if (imageViewReused(photoToLoad)) {
				return;
			} else if (bitmap != null) {
				photoToLoad.imageView.setImageBitmap(bitmap);
			} else {
				photoToLoad.imageView.setImageResource(R.drawable.logo);
			}
		}
	}
	
	public void clearCache() {
		memoryCache.clear();
		fileCache.clear();
	}

}
