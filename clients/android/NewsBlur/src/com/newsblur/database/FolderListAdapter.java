package com.newsblur.database;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import android.content.Context;
import android.database.Cursor;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.BaseExpandableListAdapter;
import android.widget.ExpandableListView;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.domain.StarredCount;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StateFilter;

/**
 * Custom adapter to display a nested folder/feed list in an ExpandableListView.
 */
public class FolderListAdapter extends BaseExpandableListAdapter {

    public static final int GLOBAL_SHARED_STORIES_GROUP_POSITION = 0;
    public static final int ALL_SHARED_STORIES_GROUP_POSITION = 1;

    private enum GroupType { GLOBAL_SHARED_STORIES, ALL_SHARED_STORIES, ALL_STORIES, FOLDER, READ_STORIES, SAVED_STORIES }
    private enum ChildType { SOCIAL_FEED, FEED, SAVED_BY_TAG }

    private final static float defaultTextSize_childName = 14;
    private final static float defaultTextSize_groupName = 13;
    private final static float defaultTextSize_count = 14;

    /** Social feeds, indexed by feed ID. */
    private Map<String,SocialFeed> socialFeeds = Collections.emptyMap();
    /** Social feed in display order. */
    private List<SocialFeed> socialFeedsOrdered = Collections.emptyList();
    /** Total neutral unreads for all social feeds. */
    public int totalSocialNeutCount = 0;
    /** Total positive unreads for all social feeds. */
    public int totalSocialPosiCount = 0;

    /** Feeds, indexed by feed ID. */
    private Map<String,Feed> feeds = Collections.emptyMap();
    /** Neutral counts for active feeds, indexed by feed ID. */
    private Map<String,Integer> feedNeutCounts = Collections.emptyMap();
    /** Positive counts for active feeds, indexed by feed ID. */
    private Map<String,Integer> feedPosCounts = Collections.emptyMap();
    /** Total neutral unreads for all feeds. */
    public int totalNeutCount = 0;
    /** Total positive unreads for all feeds. */
    public int totalPosCount = 0;
    /** Saved counts for active feeds, indexed by feed ID. */
    private Map<String,Integer> feedSavedCounts = Collections.emptyMap();

    /** Folders, indexed by canonical name. */
    private Map<String,Folder> folders = Collections.emptyMap();
    /** Folders, indexed by flat name. */
    private Map<String,Folder> flatFolders = Collections.emptyMap();
    /** Flat names of currently displayed folders in display order. */
    private List<String> activeFolderNames;
    /** List of currently displayed feeds for a folder, ordered the same as activeFolderNames. */
    private List<List<Feed>> activeFolderChildren;
    /** List of folder neutral counts, ordered the same as activeFolderNames. */
    private List<Integer> folderNeutCounts;
    /** List of foler positive counts, ordered the same as activeFolderNames. */
    private List<Integer> folderPosCounts;

    /** Starred story sets in display order. */
    private List<StarredCount> starredCountsByTag = Collections.emptyList();

    private int savedStoriesTotalCount;

    /** Flat names of folders explicity closed by the user. */
    private Set<String> closedFolders = new HashSet<String>();

	private Context context;
	private LayoutInflater inflater;
	private StateFilter currentState;
    
    // since we want to implement a custom expando that does group collapse/expand, we need
    // a way to call back to those functions on the listview from the onclick listener of
    // views we crate for the list.
    public WeakReference<ExpandableListView> listBackref;

    private float textSize;

	public FolderListAdapter(Context context, StateFilter currentState) {
		this.context = context;
        this.currentState = currentState;
		this.inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);

        textSize = PrefsUtils.getListTextSize(context);
	}

	@Override
	public synchronized View getGroupView(final int groupPosition, final boolean isExpanded, View convertView, ViewGroup parent) {
		View v = convertView;
        if (groupPosition == GLOBAL_SHARED_STORIES_GROUP_POSITION) {
            if (v == null) v = inflater.inflate(R.layout.row_global_shared_stories, null, false);
        } else if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
			if (v == null) v =  inflater.inflate(R.layout.row_all_shared_stories, null, false);
            if (currentState == StateFilter.BEST || (totalSocialNeutCount == 0)) {
                v.findViewById(R.id.row_foldersumneu).setVisibility(View.GONE);
            } else {
                v.findViewById(R.id.row_foldersumneu).setVisibility(View.VISIBLE);
                ((TextView) v.findViewById(R.id.row_foldersumneu)).setText(Integer.toString(totalSocialNeutCount));	
            }
            if (totalSocialPosiCount == 0) {
                v.findViewById(R.id.row_foldersumpos).setVisibility(View.GONE);
            } else {
                v.findViewById(R.id.row_foldersumpos).setVisibility(View.VISIBLE);
                ((TextView) v.findViewById(R.id.row_foldersumpos)).setText(Integer.toString(totalSocialPosiCount));
            }
            v.findViewById(R.id.row_foldersums).setVisibility(isExpanded ? View.INVISIBLE : View.VISIBLE);
		} else if (isFolderRoot(groupPosition)) {
			if (v == null) v =  inflater.inflate(R.layout.row_all_stories, null, false);
        } else if (isRowReadStories(groupPosition)) {
            if (v == null) v = inflater.inflate(R.layout.row_read_stories, null, false);
        } else if (isRowSavedStories(groupPosition)) {
            if (v == null) v = inflater.inflate(R.layout.row_saved_stories, null, false);
            TextView savedSum = ((TextView) v.findViewById(R.id.row_foldersum));
            if (savedStoriesTotalCount > 0) {
                savedSum.setVisibility(View.VISIBLE);
                savedSum.setText(Integer.toString(savedStoriesTotalCount));
            } else {
                savedSum.setVisibility(View.GONE);
            }
		} else {
			if (v == null) v = inflater.inflate(R.layout.row_folder, parent, false);
            String folderName = activeFolderNames.get(convertGroupPositionToActiveFolderIndex(groupPosition));
			TextView folderTitle = ((TextView) v.findViewById(R.id.row_foldername));
		    folderTitle.setText(folderName);
            int countPosition = convertGroupPositionToActiveFolderIndex(groupPosition);
            bindCountViews(v, folderNeutCounts.get(countPosition), folderPosCounts.get(countPosition), false);
            v.findViewById(R.id.row_foldersums).setVisibility(isExpanded ? View.INVISIBLE : View.VISIBLE);
            ImageView folderIconView = ((ImageView) v.findViewById(R.id.row_folder_icon));
            if ( folderIconView != null ) {
                folderIconView.setImageResource(isExpanded ? R.drawable.g_icn_folder : R.drawable.g_icn_folder_rss);
            }
		}

        TextView groupNameView = ((TextView) v.findViewById(R.id.row_foldername));
        groupNameView.setTextSize(textSize * defaultTextSize_groupName);
        TextView sumNeutView = ((TextView) v.findViewById(R.id.row_foldersumneu));
        if (sumNeutView != null ) sumNeutView.setTextSize(textSize * defaultTextSize_count);
        TextView sumPosiView = ((TextView) v.findViewById(R.id.row_foldersumpos));
        if (sumPosiView != null ) sumPosiView.setTextSize(textSize * defaultTextSize_count);
        TextView sumSavedView = ((TextView) v.findViewById(R.id.row_foldersum));
        if (sumSavedView != null ) sumSavedView.setTextSize(textSize * defaultTextSize_count);

        // if a group has a sub-view called row_folder_indicator, it will act as an expando
        ImageView folderIndicatorView = ((ImageView) v.findViewById(R.id.row_folder_indicator));
        if ( folderIndicatorView != null ) {
            folderIndicatorView.setImageResource(isExpanded ? R.drawable.indicator_expanded : R.drawable.indicator_collapsed);
			folderIndicatorView.setOnClickListener(new OnClickListener() {
				@Override
				public void onClick(View v) {
                    toggleGroup(v, groupPosition, isExpanded);
				}
			});
        }

		return v;
	}

    /**
     * handle clicks on group view expandos. we need to launch custom actions when the user clicks
     * on groups anywhere other than an expando, so the default onGroupClick action in the Listview
     * is overridden in the fragment that uses this adapter.
     */
    private void toggleGroup(View v, int groupPosition, boolean isExpanded) {
        ExpandableListView list = listBackref.get();
        if (list == null) return;

        if (isExpanded) {
            list.collapseGroup(groupPosition);
        } else {
            list.expandGroup(groupPosition, true);
        }
    }

	@Override
	public synchronized View getChildView(int groupPosition, int childPosition, boolean isLastChild, View convertView, ViewGroup parent) {
		View v = convertView;
		if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
            if (v == null) v = inflater.inflate(R.layout.row_socialfeed, parent, false);
            SocialFeed f = socialFeedsOrdered.get(childPosition);
            TextView nameView = ((TextView) v.findViewById(R.id.row_socialfeed_name));
            nameView.setText(f.feedTitle);
            nameView.setTextSize(textSize * defaultTextSize_childName);
            FeedUtils.iconLoader.displayImage(f.photoUrl, ((ImageView) v.findViewById(R.id.row_socialfeed_icon)), 0, false);
            TextView neutCounter = ((TextView) v.findViewById(R.id.row_socialsumneu));
            if (f.neutralCount > 0 && currentState != StateFilter.BEST) {
                neutCounter.setVisibility(View.VISIBLE);
                neutCounter.setText(Integer.toString(checkNegativeUnreads(f.neutralCount)));
            } else {
                neutCounter.setVisibility(View.GONE);
            }
            TextView posCounter = ((TextView) v.findViewById(R.id.row_socialsumpos));
            if (f.positiveCount > 0) {
                posCounter.setVisibility(View.VISIBLE);
                posCounter.setText(Integer.toString(checkNegativeUnreads(f.positiveCount)));
            } else {
                posCounter.setVisibility(View.GONE);
            }
            neutCounter.setTextSize(textSize * defaultTextSize_count);
            posCounter.setTextSize(textSize * defaultTextSize_count);
        } else if (isRowSavedStories(groupPosition)) {
            if (v == null) v = inflater.inflate(R.layout.row_saved_tag, parent, false);
            StarredCount sc = starredCountsByTag.get(childPosition);
            TextView nameView =((TextView) v.findViewById(R.id.row_tag_name));
            nameView.setText(sc.tag);
            nameView.setTextSize(textSize * defaultTextSize_childName);
            TextView savedCounter =((TextView) v.findViewById(R.id.row_saved_tag_sum));
            savedCounter.setText(Integer.toString(checkNegativeUnreads(sc.count)));
            savedCounter.setTextSize(textSize * defaultTextSize_count);
		} else {
            if (v == null) v = inflater.inflate(R.layout.row_feed, parent, false);
            Feed f = activeFolderChildren.get(convertGroupPositionToActiveFolderIndex(groupPosition)).get(childPosition);
            TextView nameView =((TextView) v.findViewById(R.id.row_feedname));
            nameView.setText(f.title);
            nameView.setTextSize(textSize * defaultTextSize_childName);
            FeedUtils.iconLoader.displayImage(f.faviconUrl, ((ImageView) v.findViewById(R.id.row_feedfavicon)), 0, false);
            TextView neutCounter = ((TextView) v.findViewById(R.id.row_feedneutral));
            TextView posCounter = ((TextView) v.findViewById(R.id.row_feedpositive));
            TextView savedCounter = ((TextView) v.findViewById(R.id.row_feedsaved));
            if (currentState == StateFilter.SAVED) {
                neutCounter.setVisibility(View.GONE);
                posCounter.setVisibility(View.GONE);
                savedCounter.setVisibility(View.VISIBLE);
                savedCounter.setText(Integer.toString(zeroForNull(feedSavedCounts.get(f.feedId))));
            } else if (currentState == StateFilter.BEST) {
                neutCounter.setVisibility(View.GONE);
                savedCounter.setVisibility(View.GONE);
                posCounter.setVisibility(View.VISIBLE);
                posCounter.setText(Integer.toString(checkNegativeUnreads(f.positiveCount)));
            } else {
                savedCounter.setVisibility(View.GONE);
                if (f.neutralCount > 0) {
                    neutCounter.setVisibility(View.VISIBLE);
                    neutCounter.setText(Integer.toString(checkNegativeUnreads(f.neutralCount)));
                } else {
                    neutCounter.setVisibility(View.GONE);
                }
                if (f.positiveCount > 0) {
                    posCounter.setVisibility(View.VISIBLE);
                    posCounter.setText(Integer.toString(checkNegativeUnreads(f.positiveCount)));
                } else {
                    posCounter.setVisibility(View.GONE);
                }
            }
            neutCounter.setTextSize(textSize * defaultTextSize_count);
            posCounter.setTextSize(textSize * defaultTextSize_count);
            savedCounter.setTextSize(textSize * defaultTextSize_count);
		}
		return v;
	}

    @Override
	public synchronized FeedSet getGroup(int groupPosition) {
        if (groupPosition == GLOBAL_SHARED_STORIES_GROUP_POSITION) {
            return FeedSet.globalShared();
        } else if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
            return FeedSet.allSocialFeeds();
        } else if (isFolderRoot(groupPosition)) {
            if (currentState == StateFilter.SAVED) return FeedSet.allSaved();
            return FeedSet.allFeeds();
        } else if (isRowReadStories(groupPosition)) {
            return FeedSet.allRead();
        } else if (isRowSavedStories(groupPosition)) {
            return FeedSet.allSaved();
        } else {
            String folderName = getGroupFolderName(groupPosition);
            // TODO: technically we have the data this util method gives us, could we save a DB call?
            FeedSet fs = FeedUtils.feedSetFromFolderName(folderName);
            if (currentState == StateFilter.SAVED) fs.setFilterSaved(true);
            return fs;
        }
	}

    /**
     * Get the canonical (not flattened with parents) name of the folder at the given group position.
     * Supports normal folders only, not special all-type meta-folders.
     */
    public String getGroupFolderName(int groupPosition) {
        int activeFolderIndex = convertGroupPositionToActiveFolderIndex(groupPosition);
        String flatFolderName = activeFolderNames.get(activeFolderIndex);
        Folder folder = flatFolders.get(flatFolderName);
        return folder.name;
    }

    private int convertGroupPositionToActiveFolderIndex(int groupPosition) {
        // Global and social feeds are shown above the named folders so the groupPosition
        // needs to be adjusted to index into the active folders lists.
        return groupPosition - 2;
    }

	@Override
	public synchronized int getGroupCount() {
        // in addition to the real folders returned by the /reader/feeds API, there are virtual folders
        // for global shared stories, social feeds and saved stories
        if (activeFolderNames == null) return 0;
        // two types of group (folder and All Stories are represented as folders, and don't count, so -2)
		return (activeFolderNames.size() + (GroupType.values().length - 2));
	}

	@Override
	public synchronized long getGroupId(int groupPosition) {
        // Global shared, all shared and saved stories don't have IDs so give them a really
        // huge one.
        if (groupPosition == GLOBAL_SHARED_STORIES_GROUP_POSITION) {
            return Long.MAX_VALUE;
        } else if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
            return Long.MAX_VALUE-1;
        } else if (isRowReadStories(groupPosition)) {
            return Long.MAX_VALUE-2;
        } else if (isRowSavedStories(groupPosition)) {
            return Long.MAX_VALUE-3;
        } else {
		    return activeFolderNames.get(convertGroupPositionToActiveFolderIndex(groupPosition)).hashCode();
		}
	}
	
	@Override
	public synchronized int getChildrenCount(int groupPosition) {
		if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
			return socialFeedsOrdered.size();
        } else if (isRowSavedStories(groupPosition)) {
            return starredCountsByTag.size();
        } else if (isRowReadStories(groupPosition) || groupPosition == GLOBAL_SHARED_STORIES_GROUP_POSITION) {
            return 0; // these rows never have children
		} else {
            return activeFolderChildren.get(convertGroupPositionToActiveFolderIndex(groupPosition)).size();
		}
	}

	@Override
	public synchronized FeedSet getChild(int groupPosition, int childPosition) {
		if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
            SocialFeed socialFeed = socialFeedsOrdered.get(childPosition);
            return FeedSet.singleSocialFeed(socialFeed.userId, socialFeed.username);
        } else if (isRowSavedStories(groupPosition)) {
            return FeedSet.singleSavedTag(starredCountsByTag.get(childPosition).tag);
        } else {
            Feed feed = activeFolderChildren.get(convertGroupPositionToActiveFolderIndex(groupPosition)).get(childPosition);
            FeedSet fs = FeedSet.singleFeed(feed.feedId);
            if (currentState == StateFilter.SAVED) fs.setFilterSaved(true);
            return fs;
		}
	}

	@Override
    public synchronized long getChildId(int groupPosition, int childPosition) {
		return getChild(groupPosition, childPosition).hashCode();
	}

	public synchronized String getGroupUniqueName(int groupPosition) {
        // these "names" aren't actually what is used to render the row, but are used
        // by the fragment for tracking row identity to save open/close preferences
		if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
			return "[ALL_SHARED_STORIES]";
		} else if (groupPosition == GLOBAL_SHARED_STORIES_GROUP_POSITION) {
            return "[GLOBAL_SHARED_STORIES]";
        } else if (isRowReadStories(groupPosition)) {
            return "[READ_STORIES]";
        } else if (isRowSavedStories(groupPosition)) {
            return "[SAVED_STORIES]";
        } else {
			return activeFolderNames.get(convertGroupPositionToActiveFolderIndex(groupPosition));
		}
	}

    /**
     * Determines if the folder at the specified position is the special "root" folder.  This
     * folder is returned by the API in a special way and the APIManager ensures it gets a
     * specific name in the DB so we can find it.
     */
    public boolean isFolderRoot(int groupPosition) {
        return ( getGroupUniqueName(groupPosition).equals(AppConstants.ROOT_FOLDER) );
    }

    /**
     * Determines if the row at the specified position is the special "read" folder. This
     * row doesn't actually correspond to a row in the DB, much like the social row, but
     * it is located at the bottom of the set rather than the top.
     */
    public boolean isRowReadStories(int groupPosition) {
        return ( groupPosition == (activeFolderNames.size() + 2) );
    }

    /**
     * Determines if the row at the specified position is the special "saved" folder. This
     * row doesn't actually correspond to a row in the DB, much like the social row, but
     * it is located at the bottom of the set rather than the top.
     */
    public boolean isRowSavedStories(int groupPosition) {
        return ( groupPosition == (activeFolderNames.size() + 3) );
    }

	public synchronized void setSocialFeedCursor(Cursor cursor) {
        if (!cursor.isBeforeFirst()) return;
        socialFeeds = new HashMap<String,SocialFeed>(cursor.getCount());
        socialFeedsOrdered = new ArrayList<SocialFeed>(cursor.getCount());
        totalSocialNeutCount = 0;
        totalSocialPosiCount = 0;
        while (cursor.moveToNext()) {
            SocialFeed f = SocialFeed.fromCursor(cursor);
            socialFeedsOrdered.add(f);
            socialFeeds.put(f.userId, f);
            totalSocialNeutCount += checkNegativeUnreads(f.neutralCount);
            totalSocialPosiCount += checkNegativeUnreads(f.positiveCount);
        }
        notifyDataSetChanged();
	}

    public synchronized void setFoldersCursor(Cursor cursor) {
        if ((cursor.getCount() < 1) || (!cursor.isBeforeFirst())) return;
        folders = new LinkedHashMap<String,Folder>(cursor.getCount());
        flatFolders = new LinkedHashMap<String,Folder>(cursor.getCount());
        while (cursor.moveToNext()) {
            Folder folder = Folder.fromCursor(cursor);
            folders.put(folder.name, folder);
            flatFolders.put(folder.flatName(), folder);
        }
        recountFeeds();
        notifyDataSetChanged();
    }

	public synchronized void setFeedCursor(Cursor cursor) {
        if (!cursor.isBeforeFirst()) return;
        feeds = new LinkedHashMap<String,Feed>(cursor.getCount());
        feedNeutCounts = new HashMap<String,Integer>();
        feedPosCounts = new HashMap<String,Integer>();
        totalNeutCount = 0;
        totalPosCount = 0;
        while (cursor.moveToNext()) {
            Feed f = Feed.fromCursor(cursor);
            feeds.put(f.feedId, f);
            if (f.positiveCount > 0) {
                int pos = checkNegativeUnreads(f.positiveCount);
                feedPosCounts.put(f.feedId, pos);
                totalPosCount += pos;
            }
            if (f.neutralCount > 0) {
                int neut = checkNegativeUnreads(f.neutralCount);
                feedNeutCounts.put(f.feedId, neut);
                totalNeutCount += neut;
            }
        }
        recountFeeds();
        notifyDataSetChanged();
	}

	public synchronized void setStarredCountCursor(Cursor cursor) {
        if (!cursor.isBeforeFirst()) return;
        starredCountsByTag = new ArrayList<StarredCount>();
        feedSavedCounts = new HashMap<String,Integer>();
        while (cursor.moveToNext()) {
            StarredCount sc = StarredCount.fromCursor(cursor);
            if (sc.isTotalCount()) {
                savedStoriesTotalCount = sc.count;
            } else if (sc.tag != null) {
                starredCountsByTag.add(sc);
            } else if (sc.feedId != null) {
                feedSavedCounts.put(sc.feedId, sc.count);
            }
        }
        Collections.sort(starredCountsByTag, StarredCount.StarredCountComparatorByTag);
        recountFeeds();
        notifyDataSetChanged();
	}
    
    private void recountFeeds() {
        if ((folders == null) || (feeds == null)) return;
        // re-init our local vars
        activeFolderNames = new ArrayList<String>();
        activeFolderChildren = new ArrayList<List<Feed>>();
        folderNeutCounts = new ArrayList<Integer>();
        folderPosCounts = new ArrayList<Integer>();
        // create a sorted list of folder display names
        List<String> sortedFolderNames = new ArrayList<String>(flatFolders.keySet());
        Collections.sort(sortedFolderNames, Folder.FolderNameComparator);
        // figure out which sub-folders are hidden because their parents are closed (flat names)
        Set<String> hiddenSubFolders = getSubFoldersRecursive(closedFolders);
        Set<String> hiddenSubFoldersFlat = new HashSet<String>(hiddenSubFolders.size());
        for (String hiddenSub : hiddenSubFolders) hiddenSubFoldersFlat.add(folders.get(hiddenSub).flatName());
        // inspect folders to see if the are active for display
        for (String folderName : sortedFolderNames) {
            if (hiddenSubFoldersFlat.contains(folderName)) continue;
            Folder folder = flatFolders.get(folderName);
            List<Feed> activeFeeds = new ArrayList<Feed>();
            feedinfolderloop: for (String feedId : folder.feedIds) {
                Feed f = feeds.get(feedId);
                // activeFeeds is a list, so it doesn't handle duplication (which the API allows) gracefully
                if (f == null) continue feedinfolderloop;
                if (activeFeeds.contains(f)) break feedinfolderloop;

                if ( (currentState == StateFilter.ALL) ||
                     ((currentState == StateFilter.SOME) && (feedNeutCounts.containsKey(feedId) || feedPosCounts.containsKey(feedId))) ||
                     ((currentState == StateFilter.BEST) && feedPosCounts.containsKey(feedId)) ||
                     ((currentState == StateFilter.SAVED) && feedSavedCounts.containsKey(feedId)) ) {
                    activeFeeds.add(f);
                }
            }
            if ((activeFeeds.size() > 0) || (folderName.equals(AppConstants.ROOT_FOLDER))) {
                activeFolderNames.add(folderName);
                Collections.sort(activeFeeds);
                activeFolderChildren.add(activeFeeds);
                folderNeutCounts.add(getFolderNeutralCountRecursive(folder, null));
                folderPosCounts.add(getFolderPositiveCountRecursive(folder, null));
            }
        }
    }

    /**
     * Given a set of (not-flat) folder names, figure out child folder names (also not flat). Does
     * not include the initially passed folder names, unless they occur as children of one of the
     * other parents passed.
     */
    private Set<String> getSubFoldersRecursive(Set<String> parentFolders) {
        HashSet<String> subFolders = new HashSet<String>();
        outerloop: for (String folder : parentFolders) {
            Folder f = folders.get(folder);
            if (f == null) continue;
            innerloop: for (String child : f.children) {
                subFolders.add(child);
            }
            subFolders.addAll(getSubFoldersRecursive(subFolders));
        }
        return subFolders;
    }

    private int getFolderNeutralCountRecursive(Folder folder, Set<String> visitedParents) {
        int count = 0;
        if (visitedParents == null) visitedParents = new HashSet<String>();
        visitedParents.add(folder.name);
        for (String feedId : folder.feedIds) {
            Integer feedCount = feedNeutCounts.get(feedId);
            if (feedCount != null) count += feedCount;
        }
        for (String childName : folder.children) {
            if (!visitedParents.contains(childName)) {
                count += getFolderNeutralCountRecursive(folders.get(childName), visitedParents);
            }
        }
        return count;
    }

    private int getFolderPositiveCountRecursive(Folder folder, Set<String> visitedParents) {
        int count = 0;
        if (visitedParents == null) visitedParents = new HashSet<String>();
        visitedParents.add(folder.name);
        for (String feedId : folder.feedIds) {
            Integer feedCount = feedPosCounts.get(feedId);
            if (feedCount != null) count += feedCount;
        }
        for (String childName : folder.children) {
            if (!visitedParents.contains(childName)) {
                count += getFolderPositiveCountRecursive(folders.get(childName), visitedParents);
            }
        }
        return count;
    }

    private synchronized void forceRecount() {
        recountFeeds();
        notifyDataSetChanged();
    }

    public void reset() {
        notifyDataSetInvalidated();

        synchronized (this) {
            socialFeeds = Collections.emptyMap();
            socialFeedsOrdered = Collections.emptyList();
            totalSocialNeutCount = 0;
            totalSocialPosiCount = 0;

            folders = Collections.emptyMap();
            flatFolders = Collections.emptyMap();
            safeClear(activeFolderNames);
            safeClear(activeFolderChildren);
            safeClear(folderNeutCounts);
            safeClear(folderPosCounts);

            feeds = Collections.emptyMap();
            safeClear(feedNeutCounts);
            safeClear(feedPosCounts);
            totalNeutCount = 0;
            totalPosCount = 0;

            safeClear(starredCountsByTag);
            safeClear(closedFolders);

            notifyDataSetChanged();
        }
    }

    /** Get the cached Feed object for the feed at the given list location. */
    public Feed getFeed(int groupPosition, int childPosition) {
        return activeFolderChildren.get(convertGroupPositionToActiveFolderIndex(groupPosition)).get(childPosition);
    }

    /** Get the cached SocialFeed object for the feed at the given list location. */
    public SocialFeed getSocialFeed(int groupPosition, int childPosition) {
        return socialFeedsOrdered.get(childPosition);
    }

	public synchronized void changeState(StateFilter state) {
		currentState = state;
    }

    /**
     * Indicates that a folder is closed or not, so we can correctly display (or not) sub-folders.
     */
    public void setFolderClosed(String folderName, boolean closed) {
        // we get a flat name, but need to use a canonical name internally
        Folder folder = flatFolders.get(folderName);
        if (folder == null) return; // beat the cursors
        if (closed) {
            closedFolders.add(folder.name);
        } else {
            closedFolders.remove(folder.name);
        }
        // the logic to open/close sub-folders happens during recounts
        forceRecount();
    }

	@Override
	public boolean isChildSelectable(int groupPosition, int childPosition) {
		return true;
	}

    /*
     * These next five methods are used by the framework to decide which views can
     * be recycled when calling getChildView and getGroupView.
     */

	@Override
	public boolean hasStableIds() {
		return true;
	}

	@Override
	public int getGroupType(int groupPosition) {
		if (groupPosition == GLOBAL_SHARED_STORIES_GROUP_POSITION) {
			return GroupType.GLOBAL_SHARED_STORIES.ordinal();
		} else if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
            return GroupType.ALL_SHARED_STORIES.ordinal();
        } else if (isFolderRoot(groupPosition)) {
            return GroupType.ALL_STORIES.ordinal();
        } else if (isRowReadStories(groupPosition)) {
            return GroupType.READ_STORIES.ordinal();
        } else if (isRowSavedStories(groupPosition)) {
            return GroupType.SAVED_STORIES.ordinal();
        } else {
			return GroupType.FOLDER.ordinal();
		}
	}

    @Override
	public int getChildType(int groupPosition, int childPosition) {
		if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
			return ChildType.SOCIAL_FEED.ordinal();
        } else if (isRowSavedStories(groupPosition)) {
            return ChildType.SAVED_BY_TAG.ordinal();
		} else {
			return ChildType.FEED.ordinal();
		}
	}

	@Override
	public int getGroupTypeCount() {
		return GroupType.values().length;
	}

	@Override
	public int getChildTypeCount() {
		return ChildType.values().length;
	}

    private void bindCountViews(View v, int neutCount, int posCount, boolean showNeutZero) {
        switch (currentState) {
            case SAVED:
                v.findViewById(R.id.row_foldersumneu).setVisibility(View.GONE);
                v.findViewById(R.id.row_foldersumpos).setVisibility(View.GONE);
                break;
            case BEST:
                v.findViewById(R.id.row_foldersumneu).setVisibility(View.GONE);
                v.findViewById(R.id.row_foldersumpos).setVisibility(View.VISIBLE);
                ((TextView) v.findViewById(R.id.row_foldersumpos)).setText(Integer.toString(posCount));
                break;
            default:
                if ((neutCount > 0) || showNeutZero) {
                    v.findViewById(R.id.row_foldersumneu).setVisibility(View.VISIBLE);
                } else {    
                    v.findViewById(R.id.row_foldersumneu).setVisibility(View.GONE);
                }
                if (posCount == 0) {
                    v.findViewById(R.id.row_foldersumpos).setVisibility(View.GONE);
                } else {
                    v.findViewById(R.id.row_foldersumpos).setVisibility(View.VISIBLE);
                }
                ((TextView) v.findViewById(R.id.row_foldersumneu)).setText(Integer.toString(neutCount));
                ((TextView) v.findViewById(R.id.row_foldersumpos)).setText(Integer.toString(posCount));
                break;
        }
    }

    private int sumIntRows(Cursor c, int columnIndex) {
        if (c == null) return 0;
        int i = 0;
        c.moveToPosition(-1);
        while (c.moveToNext()) {
            i += c.getInt(columnIndex);
        }
        return i;
    }

    /**
     * Utility method to filter out and carp about negative unread counts.  These tend to indicate
     * a problem in the app or API, but are very confusing to users.
     */
    private int checkNegativeUnreads(int count) {
        if (count < 0) {
            Log.w(this.getClass().getName(), "Negative unread count found and rounded up to zero.");
            return 0;
        }
        return count;
    }

    public void safeClear(Collection c) {
        if (c != null) c.clear();
    }

    public void safeClear(Map m) {
        if (m != null) m.clear();
    }

    private int zeroForNull(Integer i) {
        if (i == null) return 0;
        return i;
    }

    public void setTextSize(float textSize) {
        this.textSize = textSize;
    }

}
