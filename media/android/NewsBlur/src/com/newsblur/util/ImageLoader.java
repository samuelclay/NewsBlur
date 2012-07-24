package com.newsblur.util;

import java.io.File;
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

	public ImageLoader(Context context) {
		fileCache = new FileCache(context);
		executorService = Executors.newFixedThreadPool(5);
	}
	
	public void displayImage(String url, String uid, ImageView imageView) {
		imageViews.put(imageView, uid);
		Bitmap bitmap = memoryCache.get(uid);
		if (bitmap != null) {
			imageView.setImageBitmap(bitmap);
		} else {
			queuePhoto(url, uid, imageView);
			imageView.setImageResource(R.drawable.logo);
		}
	}
	
	// Display an image assuming it's in cache
	public void displayImage(String uid, ImageView imageView) {
		Bitmap bitmap = memoryCache.get(uid);
		if (bitmap != null) {
			imageView.setImageBitmap(bitmap);
		} else {
			File f= fileCache.getFile(uid);
			bitmap = BitmapFactory.decodeFile(f.getAbsolutePath());
			memoryCache.put(uid, bitmap);
			imageView.setImageBitmap(bitmap);
		}
	}

	private void queuePhoto(String url, String uid, ImageView imageView) {
		PhotoToLoad p = new PhotoToLoad(url, uid, imageView);
		executorService.submit(new PhotosLoader(p));
	}
	
	public boolean checkForImage(String uid) {
		return (fileCache.getFile(uid) != null || memoryCache.get(uid) != null);
	}

	private Bitmap getBitmap(String url, String uid) {
		
		File f = fileCache.getFile(uid);
		Bitmap bitmap = BitmapFactory.decodeFile(f.getAbsolutePath());
		
		if (bitmap != null) {
			bitmap = UIUtils.roundCorners(bitmap, 10f);
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
			outputStream.close();
			bitmap = BitmapFactory.decodeFile(f.getAbsolutePath());
			bitmap = UIUtils.roundCorners(bitmap, 10f);
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
		public String uid;
		public PhotoToLoad(final String u, final String id, final ImageView i) {
			url = u; 
			uid = id;
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
			
			Bitmap bmp = getBitmap(photoToLoad.url, photoToLoad.uid);
			memoryCache.put(photoToLoad.uid, bmp);
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
		return (tag == null || !tag.equals(photoToLoad.uid));
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

	public void cacheImage(String photoUrl, String userId) {
		getBitmap(photoUrl, userId);
	}

}
