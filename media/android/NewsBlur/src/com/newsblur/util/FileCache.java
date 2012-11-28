package com.newsblur.util;

import java.io.File;

import android.content.Context;

public class FileCache {

	private File cacheDir;

	public FileCache(Context context) {
		if (android.os.Environment.getExternalStorageState().equals(android.os.Environment.MEDIA_MOUNTED)) {
			cacheDir = new File(android.os.Environment.getExternalStorageDirectory(), "NewsblurCache");
		} else {
			cacheDir = context.getCacheDir();
		}
		if (!cacheDir.exists()) {
			cacheDir.mkdirs();
		}
	}

	public File getFile(String url){
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
}
