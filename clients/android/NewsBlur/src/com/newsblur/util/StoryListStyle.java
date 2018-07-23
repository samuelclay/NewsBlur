package com.newsblur.util;

public enum StoryListStyle {

    LIST("list"),
    GRID_F("grid_f"),
    GRID_M("grid_m"),
    GRID_C("grid_c");
    
    private String parameterValue;

    StoryListStyle(String parameterValue) {
        this.parameterValue = parameterValue;
    }
    
    public String getParameterValue() {
        return parameterValue;
    }

    public static StoryListStyle safeValueOf(String s) {
        try {
            return Enum.valueOf(StoryListStyle.class, s);
        } catch (IllegalArgumentException ie) {
            return LIST;
        }
    }
}
