package com.newsblur.util;

import java.net.URL;
import java.io.File;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import android.content.Context;
import android.util.Log;

public class FileCache {

    private static final long MIN_FREE_SPACE_BYTES = 250L * 1024L * 1024L;
    private static final Pattern POSTFIX_PATTERN = Pattern.compile("(\\.[a-zA-Z0-9]+)[^\\.]*$");

    private final long maxFileAgeMillis;
    private final int minValidCacheBytes;

	private final File cacheDir;

	private FileCache(Context context, String subdir, long maxFileAgeMillis, int minValidCacheBytes) {
        this.maxFileAgeMillis = maxFileAgeMillis;
        this.minValidCacheBytes = minValidCacheBytes;
        cacheDir = new File(context.getCacheDir(), subdir);
		if (!cacheDir.exists()) {
			cacheDir.mkdirs();
		}
	}

    public static FileCache asStoryImageCache(Context context) {
        FileCache fc = new FileCache(context, "olimages", 30L * 24L * 60L * 60L * 1000L, 512);
        return fc;
    }

    public static FileCache asIconCache(Context context) {
        FileCache fc = new FileCache(context, "icons", 45L * 24L * 60L * 60L * 1000L, 128);
        return fc;
    }

    public static FileCache asThumbnailCache(Context context) {
        FileCache fc = new FileCache(context, "thumbs", 15L * 24L * 60L * 60L * 1000L, 256);
        return fc;
    }

    public void cacheFile(String url) {
        try {
            // don't be evil and download if the user is low on storage
            if (cacheDir.getFreeSpace() < MIN_FREE_SPACE_BYTES) {
                Log.w(this.getClass().getName(), "device low on storage, not caching");
                return;
            }
            
            String fileName = getFileName(url);
            if (fileName == null) {
                return;
            }

            File f = new File(cacheDir, fileName);
            if (f.exists()) return;
            long size = NetworkUtils.loadURL(new URL(url), f);
            // images that are super-small tend to be errors or invisible. don't waste file handles on them
            if (size < minValidCacheBytes) {
                f.delete();
            }
        } catch (Exception e) {
            // a huge number of things could go wrong fetching and storing an image. don't spam logs with them
        }
    }

    public File getCachedFile(String url) {
        try {
            String fileName = getFileName(url);
            if (fileName == null) {
                return null;
            }
            return new File(cacheDir, fileName);
        } catch (Exception e) {
            Log.e(this.getClass().getName(), "cache error", e);
            return null;
        }
    }

    public String getCachedLocation(String url) {
        try {
            String fileName = getFileName(url);
            if (fileName == null) {
                return null;
            }
            File f = new File(cacheDir, fileName);
            if (f.exists()) {
                return f.getAbsolutePath();
            } else { 
                return null;
            }
        } catch (Exception e) {
            Log.e(this.getClass().getName(), "cache error", e);
            return null;
        }
    }

    private String getFileName(String url) {
        Matcher m = POSTFIX_PATTERN.matcher(url);
        if (! m.find()) {
            return null;
        }
        String fileName = Integer.toString(Math.abs(url.hashCode())) + m.group(1);
        return fileName;
    }

    public void cleanupOld() {
        try {
            File[] files = cacheDir.listFiles();
            if (files == null) return;
            for (File f : files) {
                long timestamp = f.lastModified();
                if (System.currentTimeMillis() > (timestamp + maxFileAgeMillis)) {
                    f.delete();
                }
            }
        } catch (Exception e) {
            android.util.Log.e(FileCache.class.getName(), "exception cleaning up cache", e);
        }
    }

    public void cleanupUnusedOrOld(Set<String> currentUrls) {
        // if there appear to be zero images in the system, a DB rebuild probably just
        // occured, so don't trust that data for cleanup
        if (currentUrls.size() == 0) return;

        Set<String> currentFiles = new HashSet<String>(currentUrls.size());
        for (String url : currentUrls) currentFiles.add(getFileName(url));
        try {
            File[] files = cacheDir.listFiles();
            if (files == null) return;
            for (File f : files) {
                long timestamp = f.lastModified();
                if ((System.currentTimeMillis() > (timestamp + maxFileAgeMillis)) ||
                    (!currentFiles.contains(f.getName()))) {
                    f.delete();
                }
            }
        } catch (Exception e) {
            android.util.Log.e(FileCache.class.getName(), "exception cleaning up cache", e);
        }
    }

    /**
     * Looks for and cleans up any remains of the old, mis-located legacy cache directory.
     */
    public static void cleanUpOldCache1(Context context) {
        try {
            File dir = new File(android.os.Environment.getExternalStorageDirectory(), "NewsblurCache");
            if (!dir.exists()) return;
            File[] files = dir.listFiles();
            if (files == null) return;
            for (File f : files) {
                f.delete();
            }
            dir.delete();
        } catch (Exception e) {
            android.util.Log.e(FileCache.class.getName(), "exception cleaning up legacy cache", e);
        }
    }

    /**
     * Looks for and cleans up any remains of the old caching system that used poor filenames.
     */
    public static void cleanUpOldCache2(Context context) {
        try {
            File dir = context.getCacheDir();
            File[] files = dir.listFiles();
            if (files == null) return;
            Pattern oldCachePattern = Pattern.compile("^[0-9-]+$");
            for (File f : files) {
                if ( (!f.isDirectory()) && (oldCachePattern.matcher(f.getName()).matches())) {
                    f.delete();
                }
            }
        } catch (Exception e) {
            android.util.Log.e(FileCache.class.getName(), "exception cleaning up legacy cache", e);
        }
    }
}
