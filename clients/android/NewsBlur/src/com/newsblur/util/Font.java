package com.newsblur.util;

/**
 * Created by mark on 04/04/2017.
 */

public class Font {

    public static Font CHRONICLE = new Font("ChronicleSSm-Book.otf");
    public static Font DEFAULT = new Font(null);
    public static Font GOTHAM_NARROW = new Font("GothamNarrow-Book.otf");
    public static Font WHITNEY = new Font("WhitneySSm-Book-Bas.otf");

    private String bookOtfFile;

    private Font(String bookOtfFile) {
        this.bookOtfFile = bookOtfFile;
    }

    public String getBookOtfFile() {
        return bookOtfFile;
    }

    public boolean isDefaultFont() {
        return bookOtfFile == null;
    }

    public static Font getFont(String preferenceValue) {
        switch (preferenceValue) {
            case "CHRONICLE":
                return CHRONICLE;
            case "GOTHAM_NARROW":
                return GOTHAM_NARROW;
            case "WHITNEY":
                return WHITNEY;
            default:
                return DEFAULT;
        }
    }
}
