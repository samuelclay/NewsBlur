package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.util.FeedSet;

import java.util.Comparator;

public class SavedSearch {

    @SerializedName("query")
    public String query;

    @SerializedName("feed_id")
    public String feedId;

    @SerializedName("feed_address")
    public String feedAddress;

    public String feedTitle;
    public String faviconUrl;

    public ContentValues getValues(BlurDatabaseHelper dbHelper) {
        ContentValues values = new ContentValues();
        String feedTitle = "\"<b>" + query + "</b>\" in <b>" + getFeedTitle(dbHelper) + "</b>";
        values.put(DatabaseConstants.SAVED_SEARCH_FEED_TITLE, feedTitle);
        values.put(DatabaseConstants.SAVED_SEARCH_FAVICON, getFaviconUrl(dbHelper));
        values.put(DatabaseConstants.SAVED_SEARCH_ADDRESS, feedAddress);
        values.put(DatabaseConstants.SAVED_SEARCH_QUERY, query);
        values.put(DatabaseConstants.SAVED_SEARCH_FEED_ID, feedId);
        return values;
    }

    public static SavedSearch fromCursor(Cursor cursor) {
        if (cursor.isBeforeFirst()) {
            cursor.moveToFirst();
        }
        SavedSearch savedSearch = new SavedSearch();
        savedSearch.feedTitle = cursor.getString(cursor.getColumnIndex(DatabaseConstants.SAVED_SEARCH_FEED_TITLE));
        savedSearch.faviconUrl = cursor.getString(cursor.getColumnIndex(DatabaseConstants.SAVED_SEARCH_FAVICON));
        savedSearch.feedAddress = cursor.getString(cursor.getColumnIndex(DatabaseConstants.SAVED_SEARCH_ADDRESS));
        savedSearch.query = cursor.getString(cursor.getColumnIndex(DatabaseConstants.SAVED_SEARCH_QUERY));
        savedSearch.feedId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.SAVED_SEARCH_FEED_ID));
        return savedSearch;
    }

    private String getFeedTitle(BlurDatabaseHelper dbHelper) {
        String feedTitle = null;

        if (feedId.equals("river:")) {
            feedTitle = "All Site Stories";
        } else if (feedId.equals("river:infrequent")) {
            feedTitle = "Infrequent Site Stories";
        } else if (feedId.startsWith("river:")) {
            String folderName = feedId.replace("river:", "");
            FeedSet fs = dbHelper.feedSetFromFolderName(folderName);
            feedTitle = fs.getFolderName();
        } else if (feedId.equals("read")) {
            feedTitle = "Read Stories";
        } else if (feedId.startsWith("starred")) {
            feedTitle = "Saved Stories";
            String tag = feedId.replace("starred:", "");
            StarredCount starredFeed = dbHelper.getStarredFeedByTag(tag);
            if (starredFeed != null) {
                String tagSlug = tag.replace(" ", "-");
                if (starredFeed.tag.equals(tag) || starredFeed.tag.equals(tagSlug)) {
                    feedTitle = feedTitle + " - " + starredFeed.tag;
                }
            }
        } else if (feedId.startsWith("feed:")) {
            Feed feed = dbHelper.getFeed(feedId.replace("feed:", ""));
            if (feed == null) return null;
            feedTitle = feed.title;
        } else if (feedId.startsWith("social:")) {
            Feed feed = dbHelper.getFeed(feedId.replace("social:", ""));
            if (feed == null) return null;
            feedTitle = feed.title;
        }

        return feedTitle;
    }

    private String getFaviconUrl(BlurDatabaseHelper dbHelper) {
        String url = null;
        if (feedId.equals("river:") || feedId.equals("river:infrequent")) {
            url = "https://newsblur.com/media/img/icons/circular/ak-icon-allstories.png";
        } else if (feedId.startsWith("river:")) {
            url = "https://newsblur.com/media/img/icons/circular/g_icn_folder.png";
        } else if (feedId.equals("read")) {
            url = "https://newsblur.com/media/img/icons/circular/g_icn_unread.png";
        } else if (feedId.equals("starred")) {
            url = "https://newsblur.com/media/img/icons/circular/clock.png";
        } else if (feedId.startsWith("starred:")) {
            url = "https://newsblur.com/media/img/reader/tag.png";
        } else if (feedId.startsWith("feed:")) {
            Feed feed = dbHelper.getFeed(feedId.replace("feed:", ""));
            if (feed != null) {
                url = feed.faviconUrl;
            }
        } else if (feedId.startsWith("social:")) {
            Feed feed = dbHelper.getFeed(feedId.replace("social:", ""));
            if (feed != null) {
                url = feed.faviconUrl;
            }
        }
        if (url == null) {
            url = "https://newsblur.com/media/img/icons/circular/g_icn_search_black.png";
        }
        return url;
    }

    public final static Comparator<SavedSearch> SavedSearchComparatorByTitle = new Comparator<SavedSearch>() {
        @Override
        public int compare(SavedSearch ss1, SavedSearch ss2) {
            return String.CASE_INSENSITIVE_ORDER.compare(ss1.feedTitle, ss2.feedTitle);
        }
    };
}
