package com.newsblur.util;

import android.content.Context;
import android.util.Log;

import com.newsblur.di.ImageOkHttpClient;

import java.io.File;
import java.net.URL;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import okhttp3.OkHttpClient;

public class FileCache {

    private static final String FILE_CACHE_STORY_IMAGES_DIR = "olimages";
    private static final String FILE_CACHE_ICONS_DIR = "icons";
    private static final String FILE_CACHE_THUMBNAILS_DIR = "thumbs";
    private static final long MIN_FREE_SPACE_BYTES = 250L * 1024L * 1024L;
    private static final Pattern POSTFIX_PATTERN = Pattern.compile("(\\.[a-zA-Z0-9]+)[^.]*$");

    private final int minValidCacheBytes;
    @ImageOkHttpClient
    private final OkHttpClient imageOkHttpClient;

    private final File cacheDir;
    private FileCache chain;

    private FileCache(Context context, @ImageOkHttpClient OkHttpClient imageOkHttpClient, String subdir, int minValidCacheBytes) {
        this.imageOkHttpClient = imageOkHttpClient;
        this.minValidCacheBytes = minValidCacheBytes;
        cacheDir = new File(context.getCacheDir(), subdir);
        if (!cacheDir.exists()) {
            cacheDir.mkdirs();
        }
    }

    public static FileCache asStoryImageCache(Context context, @ImageOkHttpClient OkHttpClient imageOkHttpClient) {
        return new FileCache(context, imageOkHttpClient, FILE_CACHE_STORY_IMAGES_DIR, 512);
    }

    public static FileCache asIconCache(Context context, @ImageOkHttpClient OkHttpClient imageOkHttpClient) {
        return new FileCache(context, imageOkHttpClient, FILE_CACHE_ICONS_DIR, 128);
    }

    public static FileCache asThumbnailCache(Context context, @ImageOkHttpClient OkHttpClient imageOkHttpClient) {
        return new FileCache(context, imageOkHttpClient, FILE_CACHE_THUMBNAILS_DIR, 256);
    }

    /**
     * Configure a chained cache so that if the provided cache already has a file, it will be used
     * rather than being cached twice.
     */
    public void addChain(FileCache chain) {
        this.chain = chain;
    }

    public void cacheFile(String url) {
        try {
            // if the chained cache already has this file, don't bother downloading again
            if (chain != null) {
                File f = chain.getCachedFile(url);
                if ((f != null) && (f.exists())) return;
            }

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
            long size = NetworkUtils.loadURL(imageOkHttpClient, new URL(url), f);
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
            // if the chained cache already has this file, use that one
            if (chain != null) {
                File f = chain.getCachedFile(url);
                if ((f != null) && (f.exists())) return f;
            }

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
        if (!m.find()) {
            return null;
        }
        String fileName = Integer.toString(Math.abs(url.hashCode())) + m.group(1);
        return fileName;
    }

    public void cleanupOld(long maxFileAgeMillis) {
        try {
            int cleaned = 0;
            File[] files = cacheDir.listFiles();
            if (files == null) return;
            com.newsblur.util.Log.i(this, String.format("have %d files", files.length));
            for (File f : files) {
                long timestamp = f.lastModified();
                if (System.currentTimeMillis() > (timestamp + maxFileAgeMillis)) {
                    f.delete();
                    cleaned++;
                }
            }
            com.newsblur.util.Log.i(this, String.format("cleaned up %d files", cleaned));
        } catch (Exception e) {
            com.newsblur.util.Log.e(this, "exception cleaning up cache", e);
        }
    }

    /**
     * Clean up files in this cache that are both unused and past the specified age.
     */
    public void cleanupUnusedAndOld(Set<String> currentUrls, long maxFileAgeMillis) {
        // if there appear to be zero images in the system, a DB rebuild probably just
        // occured, so don't trust that data for cleanup
        if (currentUrls.size() == 0) return;

        Set<String> currentFiles = new HashSet<String>(currentUrls.size());
        for (String url : currentUrls) currentFiles.add(getFileName(url));
        try {
            int cleaned = 0;
            File[] files = cacheDir.listFiles();
            if (files == null) return;
            com.newsblur.util.Log.i(this, String.format("have %d files", files.length));
            for (File f : files) {
                long timestamp = f.lastModified();
                if ((System.currentTimeMillis() > (timestamp + maxFileAgeMillis)) &&
                        (!currentFiles.contains(f.getName()))) {
                    f.delete();
                    cleaned++;
                }
            }
            com.newsblur.util.Log.i(this, String.format("cleaned up %d files", cleaned));
        } catch (Exception e) {
            com.newsblur.util.Log.e(this, "exception cleaning up cache", e);
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
                if ((!f.isDirectory()) && (oldCachePattern.matcher(f.getName()).matches())) {
                    f.delete();
                }
            }
        } catch (Exception e) {
            android.util.Log.e(FileCache.class.getName(), "exception cleaning up legacy cache", e);
        }
    }
}
