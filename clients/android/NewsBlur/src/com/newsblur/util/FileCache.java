package com.newsblur.util;

import java.io.File;

import android.content.Context;

public class FileCache {

    private static final long MAX_FILE_AGE_MILLIS = 30L * 24L * 60L * 60L * 1000L;

	private File cacheDir;

	public FileCache(Context context) {
        cacheDir = context.getCacheDir();
		if (!cacheDir.exists()) {
			cacheDir.mkdirs();
		}
	}

	public File getFile(String url){
        if (url == null ) return null;
		final String filename = String.valueOf(url.hashCode());
		final File f = new File(cacheDir, filename);
		return f;
	}

    /**
     * Clean up any very old cached icons in the current cache dir.  This should be
     * done periodically so that new favicons are picked up and ones from removed
     * feeds don't clog up the system.
     */
    public void cleanup() {
        try {
            File[] files = cacheDir.listFiles();
            if (files == null) return;
            for (File f : files) {
                long timestamp = f.lastModified();
                if (System.currentTimeMillis() > (timestamp + MAX_FILE_AGE_MILLIS)) {
                    f.delete();
                }
            }
        } catch (Exception e) {
            android.util.Log.e(FileCache.class.getName(), "exception cleaning up icon cache", e);
        }
    }

    /**
     * Looks for and cleans up any remains of the old, mis-located legacy cache directory.
     */
    public static void cleanUpOldCache(Context context) {
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
}
