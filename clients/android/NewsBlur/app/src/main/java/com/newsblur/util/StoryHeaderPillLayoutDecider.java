package com.newsblur.util;

public final class StoryHeaderPillLayoutDecider {

    private StoryHeaderPillLayoutDecider() {}

    public static Decision decide(
            int availableWidth,
            int optionsWidth,
            int markReadWidth,
            int discoverFullWidth,
            int discoverCompactWidth,
            int searchFullWidth,
            int searchCompactWidth,
            int discoverMargin,
            int searchMargin,
            int markReadMargin,
            boolean discoverVisible,
            boolean searchVisible
    ) {
        int baseWidth = optionsWidth + markReadWidth + discoverMargin + searchMargin + markReadMargin;

        if (baseWidth + discoverFullWidth + searchFullWidth <= availableWidth) {
            return new Decision(discoverVisible, searchVisible);
        }
        if (baseWidth + discoverCompactWidth + searchFullWidth <= availableWidth) {
            return new Decision(false, searchVisible);
        }
        if (baseWidth + discoverFullWidth + searchCompactWidth <= availableWidth) {
            return new Decision(discoverVisible, false);
        }
        return new Decision(false, false);
    }

    public static final class Decision {
        private final boolean showDiscoverText;
        private final boolean showSearchText;

        public Decision(boolean showDiscoverText, boolean showSearchText) {
            this.showDiscoverText = showDiscoverText;
            this.showSearchText = showSearchText;
        }

        public boolean showDiscoverText() {
            return showDiscoverText;
        }

        public boolean showSearchText() {
            return showSearchText;
        }
    }
}
