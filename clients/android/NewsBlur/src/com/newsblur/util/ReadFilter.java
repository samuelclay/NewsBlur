package com.newsblur.util;

/**
 * Enum to represent read_filter when fetching feeds
 */
public enum ReadFilter {
    ALL("all"),
    UNREAD("unread"), // in the app, this often means "unread and read since switching activities"
    PURE_UNREAD("unread");
    
    private String parameterValue;

    ReadFilter(String parameterValue) {
        this.parameterValue = parameterValue;
    }
    
    public String getParameterValue() {
        return parameterValue;
    }
}
