package com.newsblur.util;

public enum DefaultBrowser {
    SYSTEM_DEFAULT,
    IN_APP_BROWSER,
    CHROME,
    FIREFOX,
    OPERA_MINI;

    public static DefaultBrowser getDefaultBrowser(String preferenceValue) {
        switch (preferenceValue) {
            case "IN_APP_BROWSER":
                return IN_APP_BROWSER;
            case "CHROME":
                return CHROME;
            case "FIREFOX":
                return FIREFOX;
            case "OPERA_MINI":
                return OPERA_MINI;
            case "SYSTEM_DEFAULT":
            default:
                return SYSTEM_DEFAULT;
        }
    }
}
