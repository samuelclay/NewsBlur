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
import android.os.Process;
import android.util.Log;
import android.widget.ImageView;

import com.newsblur.R;
import com.newsblur.network.APIConstants;

public class ImageLoader {

	private final MemoryCache memoryCache;
	private final FileCache fileCache;
	private final ExecutorService executorService;
    private final int emptyRID;
    private final int minImgHeight;

    // some image loads can happen after the imageview in question is already reused for some other image. keep
    // track of what image each view wants so that when it comes time to load them, they aren't stale
	private final Map<ImageView, String> imageViewMappings = Collections.synchronizedMap(new WeakHashMap<ImageView, String>());

	private ImageLoader(FileCache fileCache, int emptyRID, int minImgHeight, long memoryCacheSize) {
        this.memoryCache = new MemoryCache(memoryCacheSize);
		this.fileCache = fileCache;
		executorService = Executors.newFixedThreadPool(3);
        this.emptyRID = emptyRID;
        this.minImgHeight = minImgHeight;
	}

    public static ImageLoader asIconLoader(Context context) {
        return new ImageLoader(FileCache.asIconCache(context), R.drawable.world, 2, (Runtime.getRuntime().maxMemory()/20));
    }

    public static ImageLoader asThumbnailLoader(Context context) {
        return new ImageLoader(FileCache.asThumbnailCache(context), android.R.color.transparent, 32, (Runtime.getRuntime().maxMemory()/5));
    }
	
	public void displayImage(String url, ImageView imageView, float roundRadius, boolean cropSquare) {
        if (url == null) {
			imageView.setImageResource(emptyRID);
            return;
        }

        if (url.startsWith("/")) {
            url = APIConstants.NEWSBLUR_URL + url;
        }

		imageViewMappings.put(imageView, url);
        PhotoToLoad photoToLoad = new PhotoToLoad(url, imageView, roundRadius, cropSquare);

        // try from memory
		Bitmap bitmap = memoryCache.get(url);

		if (bitmap != null) {
            setViewImage(bitmap, photoToLoad);
		} else {
            // if not loaded, fetch and set in background
            executorService.submit(new PhotosLoader(photoToLoad));
			imageView.setImageResource(emptyRID);
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
            Process.setThreadPriority(Process.THREAD_PRIORITY_DEFAULT + Process.THREAD_PRIORITY_LESS_FAVORABLE);
            
            File f = fileCache.getCachedFile(photoToLoad.url);
            Bitmap bitmap = decodeBitmap(f);
            if (bitmap == null) {
                fileCache.cacheFile(photoToLoad.url);
                f = fileCache.getCachedFile(photoToLoad.url);
                bitmap = decodeBitmap(f);
            }

            if (bitmap != null) {
                memoryCache.put(photoToLoad.url, bitmap);			
                setViewImage(bitmap, photoToLoad);
            }
		}
	}

    private void setViewImage(Bitmap bitmap, PhotoToLoad photoToLoad) {
        if (bitmap == null) return;
        if (bitmap.getHeight() < minImgHeight) return;
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
            // ensure this imageview even still wants this image
            String latestMappedUrl = imageViewMappings.get(photoToLoad.imageView);
            if (latestMappedUrl == null || !latestMappedUrl.equals(photoToLoad.url)) return;
			if (bitmap != null) {
                bitmap = UIUtils.clipAndRound(bitmap, photoToLoad.roundRadius, photoToLoad.cropSquare);
				photoToLoad.imageView.setImageBitmap(bitmap);
			} else {
				photoToLoad.imageView.setImageResource(emptyRID);
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
