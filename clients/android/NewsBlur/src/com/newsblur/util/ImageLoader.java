package com.newsblur.util;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
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
import com.newsblur.network.APIConstants;

public class ImageLoader {

	private final MemoryCache memoryCache = new MemoryCache();
	private final FileCache fileCache;
	private final ExecutorService executorService;
	private final Map<ImageView, String> imageViews = Collections.synchronizedMap(new WeakHashMap<ImageView, String>());

	public ImageLoader(Context context) {
		fileCache = new FileCache(context);
		executorService = Executors.newFixedThreadPool(5);
	}
	
	public void displayImage(String url, ImageView imageView) {
		displayImage(url, imageView, true);
	}

    public Bitmap tryGetImage(String url) {
		Bitmap bitmap = memoryCache.get(url);
		if ((bitmap == null) && (url != null)) {
			File f = fileCache.getFile(url);
			bitmap = decodeBitmap(f);
		}
        return bitmap;
    }
	
	public void displayImage(String url, ImageView imageView, boolean doRound) {
		imageViews.put(imageView, url);
		Bitmap bitmap = tryGetImage(url);
		if (bitmap != null) {
			if (doRound) { 
				bitmap = UIUtils.roundCorners(bitmap, 5);
            }
			imageView.setImageBitmap(bitmap);
		} else {
			queuePhoto(url, imageView);
			imageView.setImageResource(R.drawable.world);
		}
	}
	

	public void displayImage(String url, ImageView imageView, float roundRadius) {
		imageViews.put(imageView, url);
		Bitmap bitmap = tryGetImage(url);
		if (bitmap != null) {
            if (roundRadius > 0) {
			    bitmap = UIUtils.roundCorners(bitmap, roundRadius);
            }
			imageView.setImageBitmap(bitmap);
		} else {
			queuePhoto(url, imageView);
			imageView.setImageResource(R.drawable.world);
		}
	}
	
	private void queuePhoto(String url, ImageView imageView) {
		PhotoToLoad p = new PhotoToLoad(url, imageView);
		executorService.submit(new PhotosLoader(p));
	}
	
	private Bitmap getBitmap(String url) {
        if (url == null) return null;
        File f = fileCache.getFile(url);
        Bitmap bitmap = decodeBitmap(f);
		
		if (bitmap != null) {
			memoryCache.put(url, bitmap);			
			bitmap = UIUtils.roundCorners(bitmap, 5);
			return bitmap;
		}

		FileInputStream fis = null;
        try {
			if (url.startsWith("/")) {
				url = APIConstants.NEWSBLUR_URL + url;
			}
			long bytesRead = NetworkUtils.loadURL(new URL(url), f);
			if (bytesRead == 0) return null;

			fis = new FileInputStream(f);
			bitmap = BitmapFactory.decodeStream(fis);
			memoryCache.put(url, bitmap);
            if (bitmap == null) return null;
			bitmap = UIUtils.roundCorners(bitmap, 5);
			return bitmap;
		} catch (Exception e) {
			Log.e(this.getClass().getName(), "Error loading image from network: " + url, e);
			return null;
		} finally {
			if (fis != null) {
				try {
					fis.close();
				} catch (IOException e) {
					// ignore
				}
			}
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
				photoToLoad.imageView.setImageResource(R.drawable.world);
			}
		}
	}

    private Bitmap decodeBitmap(File f) {
        // is is perfectly normal for files not to exist on cache misses or low
        // device memory. this class will handle nulls with a queued action or
        // placeholder image.
        if (!f.exists()) return null;
        try {
            return BitmapFactory.decodeFile(f.getAbsolutePath());
        } catch (Exception e) {
            return null;
        }
    }

}
