package com.newsblur.util;

import android.text.TextUtils;
import android.util.Pair;

import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * A subset of one, several, or all NewsBlur feeds or social feeds.  Used to encapsulate the
 * complexity of the fact that social feeds are special and requesting a river of feeds is not
 * the same as requesting one or more individual feeds.
 */
public class FeedSet {

    private Set<String> feeds;
    /** Mapping of social feed IDs to usernames. */
    private Map<String,String> socialFeeds;
    private boolean isAllNormal;
    private boolean isAllSocial;
    private boolean isAllSaved;

    private String folderName;

    /**
     * Construct a new set of feeds. Only one of the arguments may be non-null or true. Specify an empty
     * set to request all of a given type.
     */
    public FeedSet(Set<String> feeds, Map<String,String> socialFeeds, boolean allSaved) {

        if ( booleanCardinality( (feeds != null), (socialFeeds != null), allSaved ) > 1 ) {
            throw new IllegalArgumentException("at most one type of feed may be specified");
        }

        if (feeds != null) {
            if (feeds.size() < 1) {
                isAllNormal = true;
                return;
            } else {
                this.feeds = Collections.unmodifiableSet(feeds);
                return;
            }
        }

        if (socialFeeds != null) {
            if (socialFeeds.size() < 1) {
                isAllSocial = true;
                return;
            } else {
                this.socialFeeds = Collections.unmodifiableMap(socialFeeds);
                return;
            }
        }

        if (allSaved) {
            isAllSaved = true;
            return;
        }

        throw new IllegalArgumentException("no type of feed specified");
    }

    /**
     * Convenience constructor for a single feed.
     */
    public static FeedSet singleFeed(String feedId) {
        Set<String> feedIds = new HashSet<String>(1);
        feedIds.add(feedId);
        return new FeedSet(feedIds, null, false);
    }

    /**
     * Convenience constructor for a single social feed.
     */
    public static FeedSet singleSocialFeed(String userId, String username) {
        Map<String,String> socialFeedIds = new HashMap<String,String>(1);
        socialFeedIds.put(userId, username);
        return new FeedSet(null, socialFeedIds, false);
    }

    /** 
     * Convenience constructor for all (non-social) feeds.
     */
    public static FeedSet allFeeds() {
        return new FeedSet(Collections.EMPTY_SET, null, false);
    }

    /** 
     * Convenience constructor for all shared/social feeds.
     */
    public static FeedSet allSocialFeeds() {
        return new FeedSet(null, Collections.EMPTY_MAP, false);
    }

    /** 
     * Convenience constructor for a folder.
     */
    public static FeedSet folder(String folderName, Set<String> feedIds) {
        FeedSet fs = new FeedSet(feedIds, null, false);
        fs.setFolderName(folderName);
        return fs;
    }

    public Set<String> getFeeds() {
        return this.feeds;
    }

    public Map<String,String> getSocialFeeds() {
        return this.socialFeeds;
    }

    public boolean isAllSaved() {
        return this.isAllSaved;
    }

    public void setFolderName(String folderName) {
        this.folderName = folderName;
    }

    public String getFolderName() {
        return this.folderName;
    }

    private int booleanCardinality(boolean... args) {
        int card = 0;
        for (boolean b : args) {
            if (b) card++;
        }
        return card;
    }

    public boolean equals(FeedSet s) {
        if ( (feeds != null) && (s.feeds != null) && TextUtils.equals(folderName, s.folderName) && s.feeds.equals(feeds) ) return true;
        if ( (socialFeeds != null) && (s.socialFeeds != null) && s.socialFeeds.equals(socialFeeds) ) return true;
        if ( isAllNormal && s.isAllNormal ) return true;
        if ( isAllSocial && s.isAllSocial ) return true;
        if ( isAllSaved && s.isAllSaved ) return true;
        return false;
    }

}
