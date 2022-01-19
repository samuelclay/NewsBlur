package com.newsblur.util;

/**
 * Created by mark on 04/04/2017.
 */

public class Font {

    public static Font CHRONICLE = new Font(Type.OTF, "chronicle_ssm_book.otf", "'SelectedFont'");
    public static Font DEFAULT = new Font(Type.OTF, "whitney_ssm_book_bas.otf", "'SelectedFont'");
    public static Font GOTHAM_NARROW = new Font(Type.OTF, "gotham_narrow_book.otf", "'SelectedFont'");
    public static Font NOTO_SANS = new Font(Type.WEB, "https://fonts.googleapis.com/css?family=Noto+Sans", "'Noto Sans', sans-serif");
    public static Font NOTO_SERIF = new Font(Type.WEB, "https://fonts.googleapis.com/css?family=Noto+Serif", "'Noto Serif', serif");
    public static Font OPEN_SANS_CONDENSED = new Font(Type.WEB, "https://fonts.googleapis.com/css?family=Open+Sans+Condensed:300", "'Open Sans Condensed', sans-serif");
    public static Font ANONYMOUS_PRO = new Font(Type.WEB, "https://fonts.googleapis.com/css?family=Anonymous+Pro", "'Anonymous Pro', sans-serif");
    public static Font ROBOTO = new Font(Type.ANDROID_DEFAULT, null, null);

    private enum Type {
        OTF,
        WEB,
        ANDROID_DEFAULT
    }

    private final Type type;
    private final String resource;
    private final String fontFamily;

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
            case "NOTO_SANS":
                return NOTO_SANS;
            case "NOTO_SERIF":
                return NOTO_SERIF;
            case "OPEN_SANS_CONDENSED":
                return OPEN_SANS_CONDENSED;
            case "ANONYMOUS_PRO":
                return ANONYMOUS_PRO;
            case "ROBOTO":
                return ROBOTO;
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
            builder.append("@font-face { font-family: 'SelectedFont'; src: url(\"file:///android_res/font/");
            builder.append(resource);
            builder.append("\") }\n");
        }
        builder.append(String.format("body { font-size: %sem;", currentSize));
        if (type != Type.ANDROID_DEFAULT) {
            builder.append("font-family: ");
            builder.append(fontFamily);
            builder.append(";");
        }
        builder.append("} </style>");
        return builder.toString();
    }
}
