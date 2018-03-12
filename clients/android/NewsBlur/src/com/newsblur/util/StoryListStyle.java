package com.newsblur.util;

public enum StoryListStyle {

    LIST("list"),
    GRID("grid");
    
    private String parameterValue;

    StoryListStyle(String parameterValue) {
        this.parameterValue = parameterValue;
    }
    
    public String getParameterValue() {
        return parameterValue;
    }
}
