package com.newsblur.util;

import java.util.Collections;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Map.Entry;

import android.graphics.Bitmap;
import android.util.Log;

public class MemoryCache {

	private static final String TAG = "MemoryCache";
	private Map<String, Bitmap> cache = Collections.synchronizedMap(new LinkedHashMap<String, Bitmap>(10, 1.5f, true));
	private long size = 0; //current allocated size
	private long limit = 1000000; //max memory in bytes

	public MemoryCache(){
		setLimit(Runtime.getRuntime().maxMemory()/4);
	}

	public void setLimit(final long new_limit){
		limit = new_limit;
		Log.i(TAG, "MemoryCache will use up to " + limit/1024./1024.+" MB");
	}

	public Bitmap get(final String id){
		try {
			if (cache == null || !cache.containsKey(id)) {
				return null;
			} else {
				return cache.get(id);
			}
		} catch (NullPointerException ex){
			return null;
		}
	}

	public void put(String id, Bitmap bitmap) {

		if (cache.containsKey(id)) {
			size -= getSizeInBytes(cache.get(id));
		}
		cache.put(id, bitmap);
		size += getSizeInBytes(bitmap);
		checkSize();
	}

	private void checkSize() {
		if (size > limit) {
			final Iterator<Entry<String, Bitmap>> iter = cache.entrySet().iterator();  
			while (iter.hasNext()) {
				final Entry<String, Bitmap> entry = iter.next();
				size -= getSizeInBytes(entry.getValue());
				iter.remove();
				if (size <= limit) {
					break;
				}
			}
		}
	}

	public void clear() {
		cache.clear();
	}

	public long getSizeInBytes(Bitmap bitmap) {
		if (bitmap == null) {
			return 0;
		} else {
			return (bitmap.getRowBytes() * bitmap.getHeight());
		}
	}
}
