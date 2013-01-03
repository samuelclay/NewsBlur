package com.newsblur.domain;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import android.text.TextUtils;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

public class ValueMultimap implements Serializable {
	
	private static final long serialVersionUID = 3102965432185825759L;
	
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
	
	public Set<String> getKeys() {
		return multimap.keySet();
	}
	
	public String getParameterString() {
		
		final List<String> parameters = new ArrayList<String>();
		
		for (String key : multimap.keySet()) {
			for (String value : multimap.get(key)) {
				final StringBuilder builder = new StringBuilder();
				builder.append(key);
				builder.append("=");
				builder.append(value);
				parameters.add(builder.toString());
			}
		}
		
		return TextUtils.join("&", parameters);
	}
	
	public String getJsonString() {
		ArrayList<String> parameters = new ArrayList<String>();
		Gson gson = new GsonBuilder().disableHtmlEscaping().create();
		for (String key : multimap.keySet()) {
			StringBuilder builder = new StringBuilder();
			builder.append("\"" + key + "\"");
			builder.append(": ");
			builder.append(gson.toJson(multimap.get(key)));
			parameters.add(builder.toString());
		}
		final StringBuilder builder = new StringBuilder();
		builder.append("{");
		builder.append(TextUtils.join(",", parameters));
		builder.append("}");
		return builder.toString();
	}

}
