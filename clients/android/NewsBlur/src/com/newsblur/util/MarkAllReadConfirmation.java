package com.newsblur.util;

/**
 * Enum to represent mark all read confirmation preference.
 * @author mark
 */
public enum MarkAllReadConfirmation {

    FEED_AND_FOLDER("feed_and_folder"),
    FOLDER_ONLY("folder_only"),
    NONE("none");

    private String parameterValue;

    MarkAllReadConfirmation(String parameterValue) {
        this.parameterValue = parameterValue;
    }

    public boolean foldersRequireConfirmation() {
        return this != NONE;
    }

    public boolean feedsRequireConfirmation() {
        return this == FEED_AND_FOLDER;
    }
}
