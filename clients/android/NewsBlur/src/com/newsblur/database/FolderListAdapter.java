package com.newsblur.database;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.text.TextUtils;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.BaseExpandableListAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.AllSharedStoriesItemsList;
import com.newsblur.activity.AllStoriesItemsList;
import com.newsblur.activity.FolderItemsList;
import com.newsblur.activity.GlobalSharedStoriesItemsList;
import com.newsblur.activity.NewsBlurApplication;
import static com.newsblur.database.DatabaseConstants.getStr;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.AppConstants;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.StateFilter;

/**
 * Custom adapter to display a nested folder/feed list in an ExpandableListView.
 */
public class FolderListAdapter extends BaseExpandableListAdapter {

    public static final int GLOBAL_SHARED_STORIES_GROUP_POSITION = 0;
    public static final int ALL_SHARED_STORIES_GROUP_POSITION = 1;

    private enum GroupType { GLOBAL_SHARED_STORIES, ALL_SHARED_STORIES, ALL_STORIES, FOLDER, READ_STORIES, SAVED_STORIES }
    private enum ChildType { SOCIAL_FEED, FEED }

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
    private Map<String,Integer> feedNeutCounts;
    /** Positive counts for active feeds, indexed by feed ID. */
    private Map<String,Integer> feedPosCounts;
    /** Total neutral unreads for all feeds. */
    public int totalNeutCount = 0;
    /** Total positive unreads for all feeds. */
    public int totalPosCount = 0;

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

    /** Flat names of folders explicity closed by the user. */
    private Set<String> closedFolders = new HashSet<String>();

    private int savedStoriesCount;

	private Context context;

	private LayoutInflater inflater;
    private ImageLoader imageLoader;

	private StateFilter currentState;

	public FolderListAdapter(Context context, StateFilter currentState) {
		this.context = context;
        this.currentState = currentState;
		imageLoader = ((NewsBlurApplication) context.getApplicationContext()).getImageLoader();
		this.inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
	}

	@Override
	public synchronized View getGroupView(int groupPosition, boolean isExpanded, View convertView, ViewGroup parent) {
		View v = convertView;
        if (groupPosition == GLOBAL_SHARED_STORIES_GROUP_POSITION) {
            v = inflater.inflate(R.layout.row_global_shared_stories, null, false);
            ((TextView) v.findViewById(R.id.row_everythingtext)).setOnClickListener(new OnClickListener() {
                @Override
                public void onClick(View v) {
                    Intent i = new Intent(context, GlobalSharedStoriesItemsList.class);
                    i.putExtra(GlobalSharedStoriesItemsList.EXTRA_STATE, currentState);
                    context.startActivity(i);
                }
            });
        } else if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
			v =  inflater.inflate(R.layout.row_all_shared_stories, null, false);
			((TextView) v.findViewById(R.id.row_everythingtext)).setOnClickListener(new OnClickListener() {
				@Override
				public void onClick(View v) {
					Intent i = new Intent(context, AllSharedStoriesItemsList.class);
					i.putExtra(AllStoriesItemsList.EXTRA_STATE, currentState);
					context.startActivity(i);
				}
			});
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
			((ImageView) v.findViewById(R.id.row_folder_indicator)).setImageResource(isExpanded ? R.drawable.indicator_expanded : R.drawable.indicator_collapsed);
		} else if (isFolderRoot(groupPosition)) {
			v =  inflater.inflate(R.layout.row_all_stories, null, false);
        } else if (isRowReadStories(groupPosition)) {
            if (convertView == null) {
                v = inflater.inflate(R.layout.row_read_stories, null, false);
            }
        } else if (isRowSavedStories(groupPosition)) {
            if (convertView == null) {
                v = inflater.inflate(R.layout.row_saved_stories, null, false);
            }
            ((TextView) v.findViewById(R.id.row_foldersum)).setText(Integer.toString(savedStoriesCount));
		} else {
			if (convertView == null) {
				v = inflater.inflate((isExpanded) ? R.layout.row_folder_collapsed : R.layout.row_folder_collapsed, parent, false);
			}
            String folderName = activeFolderNames.get(convertGroupPositionToActiveFolderIndex(groupPosition));
			TextView folderTitle = ((TextView) v.findViewById(R.id.row_foldername));
		    folderTitle.setText(folderName.toUpperCase());
            final String canonicalFolderName = flatFolders.get(folderName).name;
			folderTitle.setOnClickListener(new OnClickListener() {
				@Override
				public void onClick(View v) {
					Intent i = new Intent(v.getContext(), FolderItemsList.class);
					i.putExtra(FolderItemsList.EXTRA_FOLDER_NAME, canonicalFolderName);
					i.putExtra(FolderItemsList.EXTRA_STATE, currentState);
					context.startActivity(i);
				}
			});
            int countPosition = convertGroupPositionToActiveFolderIndex(groupPosition);
            bindCountViews(v, folderNeutCounts.get(countPosition), folderPosCounts.get(countPosition), false);
            v.findViewById(R.id.row_foldersums).setVisibility(isExpanded ? View.INVISIBLE : View.VISIBLE);
            ImageView folderIconView = ((ImageView) v.findViewById(R.id.row_folder_icon));
            if ( folderIconView != null ) {
                folderIconView.setImageResource(isExpanded ? R.drawable.g_icn_folder : R.drawable.g_icn_folder_rss);
            }
            ImageView folderIndicatorView = ((ImageView) v.findViewById(R.id.row_folder_indicator));
            if ( folderIndicatorView != null ) {
                folderIndicatorView.setImageResource(isExpanded ? R.drawable.indicator_expanded : R.drawable.indicator_collapsed);
            }
		}
		return v;
	}

	@Override
	public synchronized View getChildView(int groupPosition, int childPosition, boolean isLastChild, View convertView, ViewGroup parent) {
		View v;
		if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
			if (convertView == null) {
                v = inflater.inflate(R.layout.row_socialfeed, parent, false);
			} else {
				v = convertView;
			}
            SocialFeed f = socialFeedsOrdered.get(childPosition);
            ((TextView) v.findViewById(R.id.row_socialfeed_name)).setText(f.feedTitle);
            imageLoader.displayImage(f.photoUrl, ((ImageView) v.findViewById(R.id.row_socialfeed_icon)), false);
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
		} else {
            Feed f = activeFolderChildren.get(convertGroupPositionToActiveFolderIndex(groupPosition)).get(childPosition);
			if (convertView == null) {
				v = inflater.inflate(R.layout.row_feed, parent, false);
			} else {
				v = convertView;
			}
            ((TextView) v.findViewById(R.id.row_feedname)).setText(f.title);
            imageLoader.displayImage(f.faviconUrl, ((ImageView) v.findViewById(R.id.row_feedfavicon)), false);
            TextView neutCounter = ((TextView) v.findViewById(R.id.row_feedneutral));
            if (f.neutralCount > 0 && currentState != StateFilter.BEST) {
                neutCounter.setVisibility(View.VISIBLE);
                neutCounter.setText(Integer.toString(checkNegativeUnreads(f.neutralCount)));
            } else {
                neutCounter.setVisibility(View.GONE);
            }
            TextView posCounter = ((TextView) v.findViewById(R.id.row_feedpositive));
            if (f.positiveCount > 0) {
                posCounter.setVisibility(View.VISIBLE);
                posCounter.setText(Integer.toString(checkNegativeUnreads(f.positiveCount)));
            } else {
                posCounter.setVisibility(View.GONE);
            }
		}
		return v;
	}

    /*
     * Gets the name of a folder, provided it isn't a special folder. Returns only the
     * canonical name of the folder, not the flattened heirachial name.
     */
    @Override
	public synchronized String getGroup(int groupPosition) {
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
        } else if (isRowReadStories(groupPosition) || isRowSavedStories(groupPosition) || groupPosition == GLOBAL_SHARED_STORIES_GROUP_POSITION) {
            return 0; // these rows never have children
		} else {
            return activeFolderChildren.get(convertGroupPositionToActiveFolderIndex(groupPosition)).size();
		}
	}

	@Override
	public synchronized String getChild(int groupPosition, int childPosition) {
		if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
            return socialFeedsOrdered.get(childPosition).userId;
        } else {
			return activeFolderChildren.get(convertGroupPositionToActiveFolderIndex(groupPosition)).get(childPosition).feedId;
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
        while (cursor.moveToNext()) {
            Feed f = Feed.fromCursor(cursor);
            feeds.put(f.feedId, f);
        }
        recountFeeds();
        notifyDataSetChanged();
	}

	public void setSavedCountCursor(Cursor cursor) {
        cursor.moveToFirst();
        if (cursor.getCount() > 0) {
            savedStoriesCount = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STARRED_STORY_COUNT_COUNT));
        }
        notifyDataSetChanged();
	}
    
    private void recountFeeds() {
        if ((folders == null) || (feeds == null)) return;
        // re-init our local vars
        activeFolderNames = new ArrayList<String>();
        activeFolderChildren = new ArrayList<List<Feed>>();
        feedNeutCounts = new HashMap<String,Integer>();
        feedPosCounts = new HashMap<String,Integer>();
        folderNeutCounts = new ArrayList<Integer>();
        folderPosCounts = new ArrayList<Integer>();
        totalNeutCount = 0;
        totalPosCount = 0;
        // count feed unreads for the current state
        for (Feed f : feeds.values()) {
            if (((currentState == StateFilter.BEST) && (f.positiveCount > 0)) ||
                ((currentState == StateFilter.SOME) && ((f.positiveCount + f.neutralCount > 0))) ||
                (currentState == StateFilter.ALL)) {
                int neut = checkNegativeUnreads(f.neutralCount);
                int pos = checkNegativeUnreads(f.positiveCount);
                feedNeutCounts.put(f.feedId, neut);
                feedPosCounts.put(f.feedId, pos);
                totalNeutCount += neut;
                totalPosCount += pos;
            }
        }
        // create a sorted list of folder display names
        List<String> sortedFolderNames = new ArrayList<String>(flatFolders.keySet());
        customSortList(sortedFolderNames);
        // figure out which sub-folders are hidden because their parents are closed (flat names)
        Set<String> hiddenSubFolders = getSubFoldersRecursive(closedFolders);
        Set<String> hiddenSubFoldersFlat = new HashSet<String>(hiddenSubFolders.size());
        for (String hiddenSub : hiddenSubFolders) hiddenSubFoldersFlat.add(folders.get(hiddenSub).flatName());
        // inspect folders to see if the are active for display
        for (String folderName : sortedFolderNames) {
            if (hiddenSubFoldersFlat.contains(folderName)) continue;
            Folder folder = flatFolders.get(folderName);
            List<Feed> activeFeeds = new ArrayList<Feed>();
            for (String feedId : folder.feedIds) {
                Feed f = feeds.get(feedId);
                // activeFeeds is a list, so it doesn't handle duplication (which the API allows) gracefully
                if ((f != null) &&(!activeFeeds.contains(f))) {
                    // the code to count feeds will only have added an entry if it was nonzero
                    if (feedNeutCounts.containsKey(feedId) || feedPosCounts.containsKey(feedId)) {
                        activeFeeds.add(f);
                    }
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
     * not include the initially passed folder names.
     */
    private Set<String> getSubFoldersRecursive(Set<String> parentFolders) {
        HashSet<String> subFolders = new HashSet<String>();
        outerloop: for (String folder : parentFolders) {
            Folder f = folders.get(folder);
            if (f == null) continue;
            innerloop: for (String child : f.children) {
                if (parentFolders.contains(child)) continue innerloop;
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

    public synchronized void forceRecount() {
        recountFeeds();
        notifyDataSetChanged();
    }

    public Feed getFeed(String feedId) {
        return feeds.get(feedId);
    }

    public SocialFeed getSocialFeed(String socialFeedId) {
        return socialFeeds.get(socialFeedId);
    }

	public void changeState(StateFilter state) {
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

    /**
     * Custom sorting for folders. Handles the special case to keep the root
     * folder on top, and also the expectation that *despite locale*, folders
     * starting with an underscore should show up on top.
     */
    private void customSortList(List<String> list) {
        Collections.sort(list, CustomComparator);
    }

    private final static Comparator<String> CustomComparator = new Comparator<String>() {
        @Override
        public int compare(String s1, String s2) {
            if (TextUtils.equals(s1, s2)) return 0;
            if (s1.equals(AppConstants.ROOT_FOLDER)) return -1;
            if (s2.equals(AppConstants.ROOT_FOLDER)) return 1;
            if (s1.startsWith("_")) return -1;
            if (s2.startsWith("_")) return 1;
            return String.CASE_INSENSITIVE_ORDER.compare(s1, s2);
        }
    };

}
