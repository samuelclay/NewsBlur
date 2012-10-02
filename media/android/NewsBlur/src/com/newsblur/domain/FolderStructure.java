package com.newsblur.domain;

import java.util.List;
import java.util.Map;

public class FolderStructure {
	// Gson seemingly only deserialises into custom objects rather than being able to deserialise a given element using a specific deserializer.
	public Map<String, List<Long>> folders;
	
	public FolderStructure(Map<String, List<Long>> folders) {
		this.folders = folders;
	}
	
	
	
}
