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
        return decide(availableWidth, optionsWidth, optionsWidth, markReadWidth, discoverFullWidth,
                discoverCompactWidth, searchFullWidth, searchCompactWidth, discoverMargin,
                searchMargin, markReadMargin, discoverVisible, searchVisible);
    }

    public static Decision decide(
            int availableWidth,
            int optionsWidth,
            int compactOptionsWidth,
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
            return new Decision(discoverVisible, searchVisible, true, optionsWidth);
        }
        if (baseWidth + discoverCompactWidth + searchFullWidth <= availableWidth) {
            return new Decision(false, searchVisible, true, optionsWidth);
        }
        if (baseWidth + discoverFullWidth + searchCompactWidth <= availableWidth) {
            return new Decision(discoverVisible, false, true, optionsWidth);
        }
        if (baseWidth + discoverCompactWidth + searchCompactWidth <= availableWidth) {
            return new Decision(false, false, true, optionsWidth);
        }

        // ItemsList.java can abbreviate "Unread · Newest" before its neighboring buttons lose their width.
        int availableOptionsWidth = Math.max(0, availableWidth - markReadWidth - discoverMargin
                - searchMargin - markReadMargin - discoverCompactWidth - searchCompactWidth);
        return new Decision(false, false, false, Math.min(compactOptionsWidth, availableOptionsWidth));
    }

    public static final class Decision {
        private final boolean showDiscoverText;
        private final boolean showSearchText;
        private final boolean showFullOptionsTitle;
        private final int optionsWidth;

        private Decision(boolean showDiscoverText, boolean showSearchText, boolean showFullOptionsTitle, int optionsWidth) {
            this.showDiscoverText = showDiscoverText;
            this.showSearchText = showSearchText;
            this.showFullOptionsTitle = showFullOptionsTitle;
            this.optionsWidth = optionsWidth;
        }

        public boolean showDiscoverText() {
            return showDiscoverText;
        }

        public boolean showSearchText() {
            return showSearchText;
        }

        public boolean showFullOptionsTitle() {
            return showFullOptionsTitle;
        }

        public int optionsWidth() {
            return optionsWidth;
        }
    }
}
