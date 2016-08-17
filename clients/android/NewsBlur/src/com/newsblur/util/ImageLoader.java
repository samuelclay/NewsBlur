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
		executorService = Executors.newFixedThreadPool(2);
	}
	
	public void displayImage(String url, ImageView imageView, float roundRadius, boolean cropSquare) {
        if (url == null) {
			imageView.setImageResource(R.drawable.world);
            return;
        }

		imageViews.put(imageView, url);
        PhotoToLoad photoToLoad = new PhotoToLoad(url, imageView, roundRadius, cropSquare);

        // try from memory
		Bitmap bitmap = memoryCache.get(url);
        // try from file
		if (bitmap == null) {
			File f = fileCache.getFile(url);
			bitmap = decodeBitmap(f);
		}

		if (bitmap != null) {
            // if already loaded, set immediately
            setViewImage(bitmap, photoToLoad);
		} else {
            // if not loaded, fetch and set in background
            executorService.submit(new PhotosLoader(photoToLoad));
			imageView.setImageResource(R.drawable.world);
		}
	}
	
	private class PhotoToLoad {
		public String url;
		public ImageView imageView;
        public float roundRadius;
        public boolean cropSquare;
		public PhotoToLoad(final String u, final ImageView i, float rr, boolean cs) {
			url = u; 
			imageView = i;
            roundRadius = rr;
            cropSquare = cs;
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
			
			Bitmap bmp = null;
            String url = photoToLoad.url;

            File f = fileCache.getFile(url);
            Bitmap bitmap = decodeBitmap(f);
            
            if (bitmap != null) {
                memoryCache.put(url, bitmap);			
                bmp = bitmap;
            } else {
                FileInputStream fis = null;
                try {
                    if (url.startsWith("/")) {
                        url = APIConstants.NEWSBLUR_URL + url;
                    }
                    long bytesRead = NetworkUtils.loadURL(new URL(url), f);
                    if (bytesRead == 0) bmp = null;

                    fis = new FileInputStream(f);
                    bitmap = BitmapFactory.decodeStream(fis);
                    memoryCache.put(url, bitmap);
                    if (bitmap == null) bmp = null;
                    bmp = bitmap;
                } catch (Exception e) {
                    Log.e(this.getClass().getName(), "Error loading image from network: " + url, e);
                    bmp = null;
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

			memoryCache.put(photoToLoad.url, bmp);
			if (imageViewReused(photoToLoad)) {
				return;
			}
			
            setViewImage(bmp, photoToLoad);
		}
	}

	private boolean imageViewReused(PhotoToLoad photoToLoad){
		final String tag = imageViews.get(photoToLoad.imageView);
		return (tag == null || !tag.equals(photoToLoad.url));
	}

    private void setViewImage(Bitmap bitmap, PhotoToLoad photoToLoad) {
        BitmapDisplayer bitmapDisplayer = new BitmapDisplayer(bitmap, photoToLoad);
        Activity a = (Activity) photoToLoad.imageView.getContext();
        a.runOnUiThread(bitmapDisplayer);
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
                bitmap = UIUtils.clipAndRound(bitmap, photoToLoad.roundRadius, photoToLoad.cropSquare);
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
