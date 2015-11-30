package com.newsblur.util;

import android.text.TextUtils;

import java.io.Serializable;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;

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
    private boolean isAllNormal;
    private boolean isAllSocial;
    private boolean isAllRead;
    private boolean isAllSaved;
    private boolean isGlobalShared;

    private String folderName;

    /**
     * Construct a new set of feeds. Only one of the arguments may be non-null or true. Specify an empty
     * set to request all of a given type.
     */
    private FeedSet(Set<String> feeds, Map<String,String> socialFeeds, boolean allSaved, boolean globalShared, boolean allRead) {

        if ( booleanCardinality( (feeds != null), (socialFeeds != null), allRead, allSaved, globalShared ) > 1 ) {
            throw new IllegalArgumentException("at most one type of feed may be specified");
        }

        if (feeds != null) {
            if (feeds.size() < 1) {
                isAllNormal = true;
                this.feeds = feeds;
                return;
            } else {
                this.feeds = Collections.unmodifiableSet(feeds);
                return;
            }
        }

        if (socialFeeds != null) {
            if (socialFeeds.size() < 1) {
                isAllSocial = true;
                this.socialFeeds = socialFeeds;
                return;
            } else {
                this.socialFeeds = Collections.unmodifiableMap(socialFeeds);
                return;
            }
        }

        if (allRead) {
            isAllRead = true;
            return;
        }

        if (allSaved) {
            isAllSaved = true;
            return;
        }

        if (globalShared) {
            isGlobalShared = true;
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
        return new FeedSet(feedIds, null, false, false, false);
    }

    /**
     * Convenience constructor for a single social feed.
     */
    public static FeedSet singleSocialFeed(String userId, String username) {
        Map<String,String> socialFeedIds = new HashMap<String,String>(1);
        socialFeedIds.put(userId, username);
        return new FeedSet(null, socialFeedIds, false, false, false);
    }

    /**
     * Convenience constructor for multiple social feeds with IDs but no usernames. Useful
     * for local operations only.
     */
    public static FeedSet multipleSocialFeeds(Set<String> userIds) {
        Map<String,String> socialFeedIds = new HashMap<String,String>(userIds.size());
        for (String id : userIds) {
            socialFeedIds.put(id, "");
        }
        return new FeedSet(null, socialFeedIds, false, false, false);
    }

    /** 
     * Convenience constructor for all (non-social) feeds.
     */
    public static FeedSet allFeeds() {
        return new FeedSet(Collections.EMPTY_SET, null, false, false, false);
    }

    /**
     * Convenience constructor for read stories meta-feed.
     */
    public static FeedSet allRead() {
        return new FeedSet(null, null, false, false, true);
    }

    /**
     * Convenience constructor for saved stories feed.
     */
    public static FeedSet allSaved() {
        return new FeedSet(null, null, true, false, false);
    }

    /**
     * Convenience constructor for global shared stories feed.
     */
    public static FeedSet globalShared() {
        return new FeedSet(null, null, false, true, false);
    }

    /** 
     * Convenience constructor for all shared/social feeds.
     */
    public static FeedSet allSocialFeeds() {
        return new FeedSet(null, Collections.EMPTY_MAP, false, false, false);
    }

    /** 
     * Convenience constructor for a folder.
     */
    public static FeedSet folder(String folderName, Set<String> feedIds) {
        FeedSet fs = new FeedSet(feedIds, null, false, false, false);
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
        return this.isAllNormal;
    }

    public boolean isAllSocial() {
        return this.isAllSocial;
    }

    public boolean isAllRead() {
        return this.isAllRead;
    }

    public boolean isAllSaved() {
        return this.isAllSaved;
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

    // TODO: get rid of this compat serialisation hack when we switch to an object store!

    private static final String COM_SER_NUL = "NUL";

    public String toCompactSerial() {
        StringBuilder s = new StringBuilder("FS|");
        if (feeds == null) {
            s.append(COM_SER_NUL).append("|");
        } else {
            s.append(TextUtils.join(",", feeds)).append("|");
        }
        if (socialFeeds == null) {
            s.append(COM_SER_NUL).append("|");
        } else {
            Iterator<Map.Entry<String,String>> i = socialFeeds.entrySet().iterator();
            while (i.hasNext()) {
                Map.Entry<String,String> e = i.next();
                s.append(e.getKey()).append(":").append(e.getValue());
                if (i.hasNext()) s.append(",");
            }
            s.append("|");
        }
        s.append(isAllSaved);
        s.append("|");
        s.append(isGlobalShared);
        s.append("|");
        s.append(isAllRead);
        return s.toString();
    }

    public static FeedSet fromCompactSerial(String s) {
        String[] fields = TextUtils.split(s, "\\|");
        if ((fields.length != 6) || (!fields[0].equals("FS"))) throw new IllegalArgumentException("invalid compact form");
        if (! fields[1].equals(COM_SER_NUL)) {
            HashSet<String> feeds = new HashSet<String>();
            for (String id : TextUtils.split(fields[1], ",")) feeds.add(id);
            return new FeedSet(feeds, null, false, false, false);
        }
        if (! fields[2].equals(COM_SER_NUL)) {
            HashMap<String,String> socialFeeds = new HashMap<String,String>();
            for (String pair : TextUtils.split(fields[2], ",")) {
                String[] kv = TextUtils.split(pair, ":");
                if (kv.length != 2) throw new IllegalArgumentException("invalid compact form");
                socialFeeds.put(kv[0], kv[1]);
            }
            return new FeedSet(null, socialFeeds, false, false, false);
        }
        if (fields[3].equals(Boolean.TRUE.toString())) {
            return new FeedSet(null, null, true, false, false);
        }
        if (fields[4].equals(Boolean.TRUE.toString())) {
            return new FeedSet(null, null, false, true, false);
        }
        if (fields[5].equals(Boolean.TRUE.toString())) {
            return new FeedSet(null, null, false, false, true);
        }
        throw new IllegalArgumentException("invalid compact form");
    }

    private int booleanCardinality(boolean... args) {
        int card = 0;
        for (boolean b : args) {
            if (b) card++;
        }
        return card;
    }

    @Override
    public boolean equals(Object o) {
        if ( o instanceof FeedSet) {
            FeedSet s = (FeedSet) o;
            if ( (feeds != null) && (s.feeds != null) && TextUtils.equals(folderName, s.folderName) && s.feeds.equals(feeds) ) return true;
            if ( (socialFeeds != null) && (s.socialFeeds != null) && s.socialFeeds.equals(socialFeeds) ) return true;
            if ( isAllNormal && s.isAllNormal ) return true;
            if ( isAllSocial && s.isAllSocial ) return true;
            if ( isAllRead && s.isAllRead ) return true;
            if ( isAllSaved && s.isAllSaved ) return true;
            if ( isGlobalShared && s.isGlobalShared ) return true;
        }
        return false;
    }

    @Override
    public int hashCode() {
        if (isAllNormal) return 11;
        if (isAllSocial) return 12;
        if (isAllSaved) return 13;
        if (isGlobalShared) return 14;
        if (isAllRead) return 15;

        int result = 17;
        if (feeds != null) result = 31 * result + feeds.hashCode();
        if (socialFeeds != null) result = 31 * result + socialFeeds.hashCode();
        if (folderName != null) result = 31 * result + folderName.hashCode();
        return result;
    }

}
