package com.newsblur.util;

/**
 * Created by mark on 09/01/2014.
 */
public enum DefaultFeedView {
    STORY("story"),
    TEXT("text");

    private String parameterValue;

    DefaultFeedView(String parameterValue) {
        this.parameterValue = parameterValue;
    }

}
