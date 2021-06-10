package com.newsblur.util;

import java.util.Collections;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Map.Entry;

import android.graphics.Bitmap;

public class MemoryCache {

	private Map<String, Bitmap> cache = Collections.synchronizedMap(new LinkedHashMap<String, Bitmap>(32, 1.5f, true));
	private long size = 0; //current allocated size
	private long limit; //max memory in bytes

	public MemoryCache(long limitBytes) {
        this.limit = limitBytes;
	}

	public Bitmap get(String url, boolean hasRoundCorners){
		try {
			String id = getPhotoCacheId(url, hasRoundCorners);
			if (cache == null || !cache.containsKey(id)) {
				return null;
			} else {
				return cache.get(id);
			}
		} catch (NullPointerException ex){
			return null;
		}
	}

	public void put(String url, Bitmap bitmap, boolean hasRoundCorners) {
        synchronized (this) {
			String id = getPhotoCacheId(url, hasRoundCorners);
			if (cache.containsKey(id)) {
                size -= getSizeInBytes(cache.get(id));
            }
            cache.put(id, bitmap);
            size += getSizeInBytes(bitmap);
            checkSize();
        }
	}

	public String getPhotoCacheId(String url, boolean hasRoundCorners) {
		return hasRoundCorners ? url + "-rounded" : url;
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

	private long getSizeInBytes(Bitmap bitmap) {
		if (bitmap == null) {
			return 0;
		} else {
			return (bitmap.getAllocationByteCount());
		}
	}
}
