package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;

public class StoryTextResponse extends NewsBlurResponse {
	
	@SerializedName("original_text")
	public String originalText;
	
}
