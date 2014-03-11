package com.newsblur.util;

import java.io.File;

import android.content.Context;
import android.util.Log;

public class FileCache {

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

	public void clear() {
		final File[] files = cacheDir.listFiles();
		if (files != null) {
			for (final File f : files) {
				f.delete();
			}
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
            Log.e(FileCache.class.getName(), "exception cleaning up legacy cache", e);
        }
    }
}
