package com.newsblur.util;

import android.text.TextUtils;

import java.io.Serializable;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.network.APIConstants;

/**
 * A subset of one, several, or all NewsBlur feeds or social feeds.  Used to encapsulate the
 * complexity of the fact that social feeds are special and requesting a river of feeds is not
 * the same as requesting one or more individual feeds.
 */
@SuppressWarnings("serial")
public class FeedSet implements Serializable {

    private static final long serialVersionUID = 0L;

    private Set<String> feeds;
    /** Mapping of social feed IDs to usernames. */
    private Map<String,String> socialFeeds;
    private Set<String> savedTags;
    private boolean isAllRead;
    private boolean isGlobalShared;

    private String folderName;
    private String searchQuery;
    private boolean isFilterSaved = false;

    private FeedSet() {
        // must use factory methods
    }

    /**
     * Convenience constructor for a single feed.
     */
    public static FeedSet singleFeed(String feedId) {
        FeedSet fs = new FeedSet();
        fs.feeds = new HashSet<String>(1);
        fs.feeds.add(feedId);
        fs.feeds = Collections.unmodifiableSet(fs.feeds);
        return fs;
    }

    /**
     * Convenience constructor for a single social feed.
     */
    public static FeedSet singleSocialFeed(String userId, String username) {
        FeedSet fs = new FeedSet();
        fs.socialFeeds = new HashMap<String,String>(1);
        fs.socialFeeds.put(userId, username);
        return fs;
    }

    /**
     * Convenience constructor for multiple social feeds with IDs but no usernames. Useful
     * for local operations only.
     */
    public static FeedSet multipleSocialFeeds(Set<String> userIds) {
        FeedSet fs = new FeedSet();
        fs.socialFeeds = new HashMap<String,String>(userIds.size());
        for (String id : userIds) {
            fs.socialFeeds.put(id, "");
        }
        return fs;
    }

    /** 
     * Convenience constructor for all (non-social) feeds.
     */
    public static FeedSet allFeeds() {
        FeedSet fs = new FeedSet();
        fs.feeds = Collections.EMPTY_SET;
        return fs;
    }

    /**
     * Convenience constructor for read stories meta-feed.
     */
    public static FeedSet allRead() {
        FeedSet fs = new FeedSet();
        fs.isAllRead = true;
        return fs;
    }

    /**
     * Convenience constructor for saved stories feed.
     */
    public static FeedSet allSaved() {
        FeedSet fs = new FeedSet();
        fs.savedTags = Collections.EMPTY_SET;
        return fs;
    }

    /**
     * Convenience constructor for a single saved tag.
     */
    public static FeedSet singleSavedTag(String tag) {
        FeedSet fs = new FeedSet();
        fs.savedTags = new HashSet<String>(1);
        fs.savedTags.add(tag);
        fs.savedTags = Collections.unmodifiableSet(fs.savedTags);
        return fs;
    }

    /**
     * Convenience constructor for global shared stories feed.
     */
    public static FeedSet globalShared() {
        FeedSet fs = new FeedSet();
        fs.isGlobalShared = true;
        return fs;
    }

    /** 
     * Convenience constructor for all shared/social feeds.
     */
    public static FeedSet allSocialFeeds() {
        FeedSet fs = new FeedSet();
        fs.socialFeeds = Collections.EMPTY_MAP;
        return fs;
    }

    /** 
     * Convenience constructor for a folder.
     */
    public static FeedSet folder(String folderName, Set<String> feedIds) {
        FeedSet fs = new FeedSet();
        fs.feeds = Collections.unmodifiableSet(feedIds);
        fs.setFolderName(folderName);
        return fs;
    }

    /**
     * Gets a single feed ID iff there is only one or null otherwise.
     */
    public String getSingleFeed() {
        if (folderName != null) return null;
        if (feeds != null && feeds.size() == 1) return feeds.iterator().next(); else return null;
    }

    /**
     * Gets a set of feed IDs iff there are multiples or null otherwise.
     */
    public Set<String> getMultipleFeeds() {
        if (feeds != null && ((feeds.size() > 1) || (folderName != null))) return feeds; else return null;
    }

    /**
     * Gets a single social feed ID and username iff there is only one or null otherwise.
     */
    public Map.Entry<String,String> getSingleSocialFeed() {
        if (socialFeeds != null && socialFeeds.size() == 1) return socialFeeds.entrySet().iterator().next(); else return null;
    }

    /**
     * Gets a set of social feed IDs and usernames iff there are multiples or null otherwise.
     */
    public Map<String,String> getMultipleSocialFeeds() {
        if (socialFeeds != null && socialFeeds.size() > 1) return socialFeeds; else return null;
    }

    public boolean isAllNormal() {
        return ((feeds != null) && (feeds.size() < 1));
    }

    public boolean isAllSocial() {
        return ((socialFeeds != null) && (socialFeeds.size() < 1));
    }

    public boolean isAllRead() {
        return this.isAllRead;
    }

    public boolean isAllSaved() {
        return ((savedTags != null) && (savedTags.size() < 1));
    }

    /**
     * Gets a single saved tag iff there is only one or null otherwise.
     */
    public String getSingleSavedTag() {
        if (folderName != null) return null;
        if (savedTags != null && savedTags.size() == 1) return savedTags.iterator().next(); else return null;
    }

    public boolean isSingleSocial() {
        return ((socialFeeds != null) && (socialFeeds.size() == 1));
    }

    public boolean isGlobalShared() {
        return this.isGlobalShared;
    }

    public void setFolderName(String folderName) {
        this.folderName = folderName;
    }

    public String getFolderName() {
        return this.folderName;
    }

    public boolean isFolder() {
        return (this.folderName != null);
    }

    public void setSearchQuery(String searchQuery) {
        this.searchQuery = searchQuery;
    }

    public String getSearchQuery() {
        return this.searchQuery;
    }

    public void setFilterSaved(boolean isFilterSaved) {
        this.isFilterSaved = isFilterSaved;
    }

    public boolean isFilterSaved() {
        return this.isFilterSaved;
    }

    /**
     * Gets a flat set of feed IDs that can be passed to API calls that take raw numeric IDs or
     * social IDs prefixed with "social:". Returns an empty set for feed sets that don't track
     * unread counts or that are essentially "everything".
     */
    public Set<String> getFlatFeedIds() {
        Set<String> result = new HashSet<String>();
        if (feeds != null) {
            for (String id : feeds) {
                result.add(id);
            }
        }
        if (socialFeeds != null) {
            for (Map.Entry<String,String> e : socialFeeds.entrySet()) {
                result.add(APIConstants.VALUE_PREFIX_SOCIAL + e.getKey());
            }
        }
        return result;
    }

    public String toCompactSerial() {
        return DatabaseConstants.JsonHelper.toJson(this);
    }

    public static FeedSet fromCompactSerial(String s) {
        return DatabaseConstants.JsonHelper.fromJson(s, FeedSet.class);
    }

    @Override
    public boolean equals(Object o) {
        if (!( o instanceof FeedSet)) return false;
        FeedSet s = (FeedSet) o;

        if ( !TextUtils.equals(searchQuery, s.searchQuery)) return false;
        if ( !TextUtils.equals(folderName, s.folderName)) return false;
        if ( isFilterSaved != s.isFilterSaved ) return false;
        if ( (feeds != null) && (s.feeds != null) && s.feeds.equals(feeds) ) return true;
        if ( (socialFeeds != null) && (s.socialFeeds != null) && s.socialFeeds.equals(socialFeeds) ) return true;
        if ( (savedTags != null) && (s.savedTags != null) && s.savedTags.equals(savedTags) ) return true;
        if ( isAllRead && s.isAllRead ) return true;
        if ( isGlobalShared && s.isGlobalShared ) return true;
        return false;
    }

    @Override
    public int hashCode() {
        int result = 17;
        if (isAllNormal()) result = 11;
        if (isAllSocial()) result = 12;
        if (isAllSaved()) result = 13;
        if (isGlobalShared) result = 14;
        if (isAllRead) result = 15;
        if (feeds != null) result = 31 * result + feeds.hashCode();
        if (socialFeeds != null) result = 37 * result + socialFeeds.hashCode();
        if (folderName != null) result = 41 * result + folderName.hashCode();
        if (searchQuery != null) result = 43 * result + searchQuery.hashCode();
        if (savedTags != null) result = 53 * result + savedTags.hashCode();
        if (isFilterSaved) result = 59 * result;
        return result;
    }

}
