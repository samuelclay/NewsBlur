package com.newsblur.util;

/**
 * Enum to represent story order within feeds/folders/globally
 * @author mark
 */
public enum StoryOrder {
    OLDEST("oldest"),
    NEWEST("newest");
    
    private String parameterValue;

    StoryOrder(String parameterValue) {
        this.parameterValue = parameterValue;
    }
    
    public String getParameterValue() {
        return parameterValue;
    }
}
