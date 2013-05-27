package com.newsblur.util;

/**
 * Enum to represent read_filter when fetching feeds
 * @author mark
 */
public enum ReadFilter {
    ALL("all"),
    UNREAD("unread");
    
    private String parameterValue;

    ReadFilter(String parameterValue) {
        this.parameterValue = parameterValue;
    }
    
    public String getParameterValue() {
        return parameterValue;
    }
}
