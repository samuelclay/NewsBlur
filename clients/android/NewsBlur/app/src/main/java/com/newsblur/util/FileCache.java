package com.newsblur.util;

import static com.newsblur.util.AppConstants.READING_IMAGES_PATH;

import android.content.Context;
import android.util.Log;

import com.newsblur.di.ImageOkHttpClient;

import java.io.File;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import okhttp3.OkHttpClient;

public class FileCache {

    public static final String FILE_CACHE_STORY_IMAGES_DIR = "olimages";
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

    public String getWebViewImageCache(String url) {
        try {
            String fileName = getFileName(url);
            if (fileName == null) {
                return null;
            }
            File f = new File(cacheDir, fileName);
            if (f.exists()) {
                return READING_IMAGES_PATH + fileName;
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
        if (!m.find()) return null;

        String ext = m.group(1);
        return md5Hex(url) + ext;
    }

    private static String md5Hex(String s) {
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] d = md.digest(s.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(d.length * 2);
            for (byte b : d) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            return Integer.toHexString(s.hashCode());
        }
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
        if (currentUrls.isEmpty()) return;

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

    public File getCacheDir() {
        return cacheDir;
    }
}
