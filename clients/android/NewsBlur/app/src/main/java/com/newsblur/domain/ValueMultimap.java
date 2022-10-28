package com.newsblur.domain;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import android.text.TextUtils;

import com.newsblur.util.NetworkUtils;

import okhttp3.FormBody;
import okhttp3.RequestBody;

/**
 * A String-to-String multimap that serializes to JSON or HTTP request params.
 */
@SuppressWarnings("serial")
public class ValueMultimap implements Serializable {
	
	private Map<String, List<String>> multimap;
	
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
	
	public String getParameterString() {
		List<String> parameters = new ArrayList<String>();
		for (String key : multimap.keySet()) {
			for (String value : multimap.get(key)) {
				final StringBuilder builder = new StringBuilder();
				builder.append(key);
				builder.append("=");
                builder.append(NetworkUtils.encodeURL(value));
				parameters.add(builder.toString());
			}
		}
		return TextUtils.join("&", parameters);
	}
	
	public RequestBody asFormEncodedRequestBody() {
		FormBody.Builder formEncodingBuilder = new FormBody.Builder();
		for (String key : multimap.keySet()) {
			for (String value : multimap.get(key)) {
				formEncodingBuilder.add(key, value);
			}
		}
		return formEncodingBuilder.build();
	}
}
