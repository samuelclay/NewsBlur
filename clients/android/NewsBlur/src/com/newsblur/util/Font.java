package com.newsblur.util;

/**
 * Created by mark on 04/04/2017.
 */

public class Font {

    public static Font CHRONICLE = new Font("ChronicleSSm-Book.otf");
    public static Font DEFAULT = new Font(null);
    public static Font GOTHAM_NARROW = new Font("GothamNarrow-Book.otf");
    public static Font WHITNEY = new Font("WhitneySSm-Book-Bas.otf");

    private String bookFile;

    private Font(String bookFile) {
        this.bookFile = bookFile;
    }

    public boolean isUserSelected() {
        return bookFile != null;
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

    public String getFontFace() {
        if (isUserSelected()) {
            StringBuilder builder = new StringBuilder();
            builder.append("@font-face { font-family: 'SelectedFont'; src: url(\"file:///android_asset/fonts/");
            builder.append(bookFile);
            builder.append("\") }\n");
            return builder.toString();
        } else {
            return "";
        }
    }
}
