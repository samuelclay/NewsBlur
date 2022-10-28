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
import android.widget.RemoteViews;

import com.newsblur.R;
import com.newsblur.network.APIConstants;

import dagger.hilt.android.internal.managers.FragmentComponentManager;

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
        this.emptyRID = emptyRID;
        this.minImgHeight = minImgHeight;
        this.hideMissing = hideMissing;

        int threadCount = Runtime.getRuntime().availableProcessors() - 2;
        if (threadCount < 1) threadCount = 1;
		executorService = Executors.newFixedThreadPool(threadCount);
	}

    public static ImageLoader asIconLoader(Context context) {
        return new ImageLoader(FileCache.asIconCache(context), R.drawable.ic_world, UIUtils.dp2px(context, 4), false, (Runtime.getRuntime().maxMemory()/20));
    }

    public static ImageLoader asThumbnailLoader(Context context, FileCache chainCache) {
        FileCache cache = FileCache.asThumbnailCache(context);
        cache.addChain(chainCache);
        return new ImageLoader(cache, android.R.color.transparent, UIUtils.dp2px(context, 32), false, (Runtime.getRuntime().maxMemory()/8));
    }
	
    public PhotoToLoad displayImage(String url, ImageView imageView) {
        return displayImage(url, imageView, imageView.getHeight(), false);
    }

    /**
     * Synchronously check a URL/View pair to ensure the view isn't showing a stale mapping.  Useful for
     * legacy listviews that aren't smart enough to un-map a child before re-using it.
     */ 
    public void preCheck(String url, ImageView imageView) {
        String latestMappedUrl = imageViewMappings.get(imageView);
        if ( (latestMappedUrl != null) && (!latestMappedUrl.equals(url)) ) {
            imageView.setImageResource(emptyRID);
        }
    }

    /**
     * Synchronous background call coming from app widget on home screen
     */
    public void displayWidgetImage(String url, int imageViewId, int maxDimPX, RemoteViews remoteViews) {
        if (url == null) {
            remoteViews.setViewVisibility(imageViewId, View.GONE);
            return;
        }

        url = buildUrlIfNeeded(url);

        // try from memory
        Bitmap bitmap = memoryCache.get(url);
        if (bitmap != null) {
            remoteViews.setImageViewBitmap(imageViewId, bitmap);
            remoteViews.setViewVisibility(imageViewId, View.VISIBLE);
            return;
        }

        // try from disk
        bitmap = getImageFromDisk(url, maxDimPX);
        if (bitmap == null) {
            // try for network
            bitmap = getImageFromNetwork(url, maxDimPX);
        }

        if (bitmap != null) {
            memoryCache.put(url, bitmap);
            remoteViews.setImageViewBitmap(imageViewId, bitmap);
            remoteViews.setViewVisibility(imageViewId, View.VISIBLE);
        } else {
            remoteViews.setViewVisibility(imageViewId, View.GONE);
        }
    }

	public PhotoToLoad displayImage(String url, ImageView imageView, int maxDimPX, boolean allowDelay) {
        if (url == null) {
			imageView.setImageResource(emptyRID);
            return null;
        }

        url = buildUrlIfNeeded(url);

		imageViewMappings.put(imageView, url);
        PhotoToLoad photoToLoad = new PhotoToLoad(url, imageView, maxDimPX, allowDelay);

        executorService.submit(new PhotosLoader(photoToLoad));
        return photoToLoad;
	}

	public static class PhotoToLoad {
		public String url;
		public ImageView imageView;
        public int maxDimPX;
        public boolean allowDelay;
        public boolean cancel;
		public PhotoToLoad(final String url, final ImageView imageView, int maxDimPX, boolean allowDelay) {
			PhotoToLoad.this.url = url; 
			PhotoToLoad.this.imageView = imageView;
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
                    Thread.sleep(20);
                } catch (InterruptedException ie) {
                    return;
                }
            }

            if (photoToLoad.cancel) return;

            // ensure this imageview even still wants this image
            if (!isUrlMapped(photoToLoad.imageView, photoToLoad.url)) return;

            // callers frequently might botch this due to lazy view measuring
            // limit max dimensions to 800px
            if (photoToLoad.maxDimPX < 1) {
                photoToLoad.maxDimPX = 800;
            }
            
            // try from disk
            bitmap = getImageFromDisk(photoToLoad.url, photoToLoad.maxDimPX);
            if (bitmap == null) {
                // try for network
                if (photoToLoad.cancel) return;
                bitmap = getImageFromNetwork(photoToLoad.url, photoToLoad.maxDimPX);
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
        FragmentComponentManager.findActivity(photoToLoad.imageView.getContext());
        Activity a = (Activity) FragmentComponentManager.findActivity(photoToLoad.imageView.getContext());
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

    private String buildUrlIfNeeded(String url) {
        if (url.startsWith("/")) {
            url = APIConstants.buildUrl(url);
        }
        return url;
    }

    private Bitmap getImageFromDisk(String url, int maxDimPX) {
        // the only reliable way to check a cached file is to try decoding it. the util method will
        // return null if it fails
        File f = fileCache.getCachedFile(url);
        return UIUtils.decodeImage(f, maxDimPX);
    }

    private Bitmap getImageFromNetwork(String url, int maxDimPX) {
        fileCache.cacheFile(url);
        File f = fileCache.getCachedFile(url);
        return UIUtils.decodeImage(f, maxDimPX);
    }
}