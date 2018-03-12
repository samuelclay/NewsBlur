package com.newsblur.util;

import java.io.File;
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
import android.view.View;
import android.widget.ImageView;

import com.newsblur.R;
import com.newsblur.network.APIConstants;

public class ImageLoader {

	private final MemoryCache memoryCache;
	private final FileCache fileCache;
	private final ExecutorService executorService;
    private final int emptyRID;
    private final int minImgHeight;
    private final boolean hideMissing;

    // some image loads can happen after the imageview in question is already reused for some other image. keep
    // track of what image each view wants so that when it comes time to load them, they aren't stale
	private final Map<ImageView, String> imageViewMappings = Collections.synchronizedMap(new WeakHashMap<ImageView, String>());

	private ImageLoader(FileCache fileCache, int emptyRID, int minImgHeight, boolean hideMissing, long memoryCacheSize) {
        this.memoryCache = new MemoryCache(memoryCacheSize);
		this.fileCache = fileCache;
		executorService = Executors.newFixedThreadPool(AppConstants.IMAGE_LOADER_THREAD_COUNT);
        this.emptyRID = emptyRID;
        this.minImgHeight = minImgHeight;
        this.hideMissing = hideMissing;
	}

    public static ImageLoader asIconLoader(Context context) {
        return new ImageLoader(FileCache.asIconCache(context), R.drawable.world, 2, false, (Runtime.getRuntime().maxMemory()/20));
    }

    public static ImageLoader asThumbnailLoader(Context context) {
        return new ImageLoader(FileCache.asThumbnailCache(context), android.R.color.transparent, 32, true, (Runtime.getRuntime().maxMemory()/6));
    }
	
    public PhotoToLoad displayImage(String url, ImageView imageView, float roundRadius, boolean cropSquare) {
        return displayImage(url, imageView, roundRadius, cropSquare, Integer.MAX_VALUE, false);
    }

	public PhotoToLoad displayImage(String url, ImageView imageView, float roundRadius, boolean cropSquare, int maxDimPX, boolean allowDelay) {
        if (url == null) {
			imageView.setImageResource(emptyRID);
            return null;
        }

        if (url.startsWith("/")) {
            url = APIConstants.buildUrl(url);
        }

		imageViewMappings.put(imageView, url);
        PhotoToLoad photoToLoad = new PhotoToLoad(url, imageView, roundRadius, cropSquare, maxDimPX, allowDelay);

        executorService.submit(new PhotosLoader(photoToLoad));
        return photoToLoad;
	}

	public class PhotoToLoad {
		public String url;
		public ImageView imageView;
        public float roundRadius;
        public boolean cropSquare;
        public int maxDimPX;
        public boolean allowDelay;
        public boolean cancel;
		public PhotoToLoad(final String url, final ImageView imageView, float roundRadius, boolean cropSquare, int maxDimPX, boolean allowDelay) {
			PhotoToLoad.this.url = url; 
			PhotoToLoad.this.imageView = imageView;
            PhotoToLoad.this.roundRadius = roundRadius;
            PhotoToLoad.this.cropSquare = cropSquare;
            PhotoToLoad.this.maxDimPX = maxDimPX;
            PhotoToLoad.this.allowDelay = allowDelay;
            PhotoToLoad.this.cancel = false;
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
            if (photoToLoad.cancel) return;

            // try from memory
            Bitmap bitmap = memoryCache.get(photoToLoad.url);

            if (bitmap != null) {
                setViewImage(bitmap, photoToLoad);
                return;
            }

            // this not only sets a theoretical cap on how frequently we will churn against memory, storage, CPU,
            // and the UI handler, it also ensures that if the loader gets very behind (as happens during fast
            // scrolling, the caller has a few cycles to raise the cancellation flag, saving many resources.
            if (photoToLoad.allowDelay) {
                try {
                    Thread.sleep(50);
                } catch (InterruptedException ie) {
                    return;
                }
            }

            if (photoToLoad.cancel) return;

            // ensure this imageview even still wants this image
            if (!isUrlMapped(photoToLoad.imageView, photoToLoad.url)) return;

            // callers frequently might botch this due to lazy view measuring
            if (photoToLoad.maxDimPX < 1) {
                photoToLoad.maxDimPX = Integer.MAX_VALUE;
            }
            
            // try from disk
            File f = fileCache.getCachedFile(photoToLoad.url);
            // the only reliable way to check a cached file is to try decoding it. the util method will
            // return null if it fails
            bitmap = UIUtils.decodeImage(f, photoToLoad.maxDimPX, photoToLoad.cropSquare, photoToLoad.roundRadius);
            // try for network
            if (bitmap == null) {
                if (photoToLoad.cancel) return;
                fileCache.cacheFile(photoToLoad.url);
                f = fileCache.getCachedFile(photoToLoad.url);
                bitmap = UIUtils.decodeImage(f, photoToLoad.maxDimPX, photoToLoad.cropSquare, photoToLoad.roundRadius);
            }

            if (bitmap != null) {
                memoryCache.put(photoToLoad.url, bitmap);			
            }
            if (photoToLoad.cancel) return;
            setViewImage(bitmap, photoToLoad);
		}
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
            if (photoToLoad.cancel) return;

            // ensure this imageview even still wants this image
            if (!isUrlMapped(photoToLoad.imageView, photoToLoad.url)) return;

            if ((bitmap == null) || (bitmap.getHeight() < minImgHeight)) {
                if (hideMissing) {
                    photoToLoad.imageView.setVisibility(View.GONE);
                } else {
                    photoToLoad.imageView.setImageResource(emptyRID);
                }
            } else {
                photoToLoad.imageView.setVisibility(View.VISIBLE);
                photoToLoad.imageView.setImageBitmap(bitmap);
			}
		}
	}

    /**
     * Directly access a previously cached image's bitmap.  This method is *not* for use
     * in foreground UI methods; it was designed for low-priority background use for
     * creating notifications.
     */
    public static Bitmap getCachedImageSynchro(FileCache fileCache, String url) {
        if (url.startsWith("/")) {
            url = APIConstants.buildUrl(url);
        }
        File f = fileCache.getCachedFile(url);
        if (!f.exists()) return null;
        try {
            return BitmapFactory.decodeFile(f.getAbsolutePath());
        } catch (Exception e) {
            return null;
        }
    }

    public boolean isUrlMapped(ImageView view, String url) {
        String latestMappedUrl = imageViewMappings.get(view);
        if (latestMappedUrl == null || !latestMappedUrl.equals(url)) return false;
        return true;
    }

}
