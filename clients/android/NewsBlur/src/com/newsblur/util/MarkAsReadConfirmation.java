package com.newsblur.util;

/**
 * Enum to represent mark as read confirmation preference.
 * @author mark
 */
public enum MarkAsReadConfirmation {

    FEED_AND_FOLDER("feed_and_folder"),
    FOLDER_ONLY("folder_only"),
    NONE("none");

    private String parameterValue;

    MarkAsReadConfirmation(String parameterValue) {
        this.parameterValue = parameterValue;
    }

    public boolean foldersRequireConfirmation() {
        return this != NONE;
    }
}
