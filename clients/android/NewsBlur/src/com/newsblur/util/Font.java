package com.newsblur.util;

/**
 * Created by mark on 04/04/2017.
 */

public class Font {

    public static Font CHRONICLE = new Font(Type.OTF, "ChronicleSSm-Book.otf", "'SelectedFont'");
    public static Font DEFAULT = new Font(Type.DEFAULT, null, null);
    public static Font GOTHAM_NARROW = new Font(Type.OTF, "GothamNarrow-Book.otf", "'SelectedFont'");
    public static Font WHITNEY = new Font(Type.OTF, "WhitneySSm-Book-Bas.otf", "'SelectedFont'");
    public static Font NOTO_SANS = new Font(Type.WEB, "https://fonts.googleapis.com/css?family=Noto+Sans", "'Noto Sans', sans-serif");
    public static Font NOTO_SERIF = new Font(Type.WEB, "https://fonts.googleapis.com/css?family=Noto+Serif", "'Noto Serif', serif");
    public static Font OPEN_SANS_CONDENSED = new Font(Type.WEB, "https://fonts.googleapis.com/css?family=Open+Sans+Condensed:300", "'Open Sans Condensed', sans-serif");
    public static Font ANONYMOUS_PRO = new Font(Type.WEB, "https://fonts.googleapis.com/css?family=Anonymous+Pro", "'Anonymous Pro', sans-serif");

    private enum Type {
        OTF,
        WEB,
        DEFAULT
    }

    private Type type;
    private String resource;
    private String fontFamily;

    private Font(Type type, String resource, String fontFamily) {
        this.type = type;
        this.resource = resource;
        this.fontFamily = fontFamily;
    }

    public static Font getFont(String preferenceValue) {
        switch (preferenceValue) {
            case "CHRONICLE":
                return CHRONICLE;
            case "GOTHAM_NARROW":
                return GOTHAM_NARROW;
            case "WHITNEY":
                return WHITNEY;
            case "NOTO_SANS":
                return NOTO_SANS;
            case "NOTO_SERIF":
                return NOTO_SERIF;
            case "OPEN_SANS_CONDENSED":
                return OPEN_SANS_CONDENSED;
            case "ANONYMOUS_PRO":
                return ANONYMOUS_PRO;
            default:
                return DEFAULT;
        }
    }

    public String forWebView(float currentSize) {
        StringBuilder builder = new StringBuilder();
        if (type == Type.WEB) {
            builder.append("<link href=\"");
            builder.append(resource);
            builder.append("\" rel=\"stylesheet\">");
        }
        builder.append("<style style=\"text/css\">");
        if (type == Type.OTF) {
            builder.append("@font-face { font-family: 'SelectedFont'; src: url(\"file:///android_asset/fonts/");
            builder.append(resource);
            builder.append("\") }\n");
        }
        builder.append(String.format("body { font-size: %sem;", Float.toString(currentSize)));
        if (type != Type.DEFAULT) {
            builder.append("font-family: ");
            builder.append(fontFamily);
            builder.append(";");
        }
        builder.append("} </style>");
        return builder.toString();
    }
}
