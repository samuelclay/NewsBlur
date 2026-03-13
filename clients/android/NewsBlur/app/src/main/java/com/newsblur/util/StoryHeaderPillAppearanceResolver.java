package com.newsblur.util;

public final class StoryHeaderPillAppearanceResolver {

    private StoryHeaderPillAppearanceResolver() {}

    public static Appearance resolve(
            boolean showText,
            int expandedPaddingStart,
            int expandedPaddingTop,
            int expandedPaddingEnd,
            int expandedPaddingBottom,
            int expandedIconPadding,
            int compactHorizontalPadding
    ) {
        if (showText) {
            return new Appearance(
                    expandedPaddingStart,
                    expandedPaddingTop,
                    expandedPaddingEnd,
                    expandedPaddingBottom,
                    expandedIconPadding
            );
        }

        return new Appearance(
                compactHorizontalPadding,
                expandedPaddingTop,
                compactHorizontalPadding,
                expandedPaddingBottom,
                0
        );
    }

    public static final class Appearance {
        private final int paddingStart;
        private final int paddingTop;
        private final int paddingEnd;
        private final int paddingBottom;
        private final int iconPadding;

        public Appearance(int paddingStart, int paddingTop, int paddingEnd, int paddingBottom, int iconPadding) {
            this.paddingStart = paddingStart;
            this.paddingTop = paddingTop;
            this.paddingEnd = paddingEnd;
            this.paddingBottom = paddingBottom;
            this.iconPadding = iconPadding;
        }

        public int paddingStart() {
            return paddingStart;
        }

        public int paddingTop() {
            return paddingTop;
        }

        public int paddingEnd() {
            return paddingEnd;
        }

        public int paddingBottom() {
            return paddingBottom;
        }

        public int iconPadding() {
            return iconPadding;
        }
    }
}
