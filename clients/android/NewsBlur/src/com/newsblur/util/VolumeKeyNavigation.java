package com.newsblur.util;

/**
 * Enum to represent preference value for using the volume key for next/prev story.
 * Created by mark on 28/01/15.
 */
public enum VolumeKeyNavigation {
    OFF("off"),
    UP_NEXT("up_next"),
    DOWN_NEXT("down_next");

    private String parameterValue;

    VolumeKeyNavigation(String parameterValue) {
        this.parameterValue = parameterValue;
    }
}
