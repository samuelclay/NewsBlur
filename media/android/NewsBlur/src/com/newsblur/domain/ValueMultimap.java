package com.newsblur.domain;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import android.text.TextUtils;
import android.util.Log;

public class ValueMultimap {
	
	private Map<String, List<String>> multimap;
	private String TAG = "ValueMultimap";
	
	public ValueMultimap() {
		multimap = new HashMap<String, List<String>>();
	}
	
	public void put(String key, String value) {
		List<String> mappedValues;
		if ((mappedValues = multimap.get(key)) == null) {
			mappedValues = new ArrayList<String>();
		}
		mappedValues.add(value);
		multimap.put(key, mappedValues);
	}
	
	public List<String> getValues(String key) {
		return multimap.get(key);
	}
	
	public String getParameterString() {
		
		final List<String> parameters = new ArrayList<String>();
		
		for (String key : multimap.keySet()) {
			for (String value : multimap.get(key)) {
				final StringBuilder builder = new StringBuilder();
				builder.append(key);
				builder.append("=");
				try {
					builder.append(URLEncoder.encode(value, "UTF-8"));
				} catch (UnsupportedEncodingException e) {
					Log.d(TAG, "Unable to URLEncode a parameter in a POST");
					builder.append(value);
				}
				parameters.add(builder.toString());
			}
		}
		
		return TextUtils.join("&", parameters);
	}

}
