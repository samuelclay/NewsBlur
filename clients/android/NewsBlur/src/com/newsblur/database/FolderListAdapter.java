package com.newsblur.database;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
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

    private enum GroupType { GLOBAL_SHARED_STORIES, ALL_SHARED_STORIES, ALL_STORIES, FOLDER, SAVED_STORIES }
    private enum ChildType { SOCIAL_FEED, FEED }

    private Cursor socialFeedCursor;

    private Map<String,Folder> folders = Collections.emptyMap();
    private List<String> activeFolderNames;
    private List<List<Feed>> activeFolderChildren;
    private List<Integer> neutCounts;
    private List<Integer> posCounts;
    private Map<String,Feed> feeds = Collections.emptyMap();
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
                    ((Activity) context).startActivityForResult(i, Activity.RESULT_OK);
                }
            });
        } else if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
			v =  inflater.inflate(R.layout.row_all_shared_stories, null, false);
			((TextView) v.findViewById(R.id.row_everythingtext)).setOnClickListener(new OnClickListener() {
				@Override
				public void onClick(View v) {
					Intent i = new Intent(context, AllSharedStoriesItemsList.class);
					i.putExtra(AllStoriesItemsList.EXTRA_STATE, currentState);
					((Activity) context).startActivityForResult(i, Activity.RESULT_OK);
				}
			});
            if (socialFeedCursor != null) {
                int neutCount = sumIntRows(socialFeedCursor, socialFeedCursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT));
                neutCount = checkNegativeUnreads(neutCount);
                if (currentState == StateFilter.BEST || (neutCount == 0)) {
                    v.findViewById(R.id.row_foldersumneu).setVisibility(View.GONE);
                } else {
                    v.findViewById(R.id.row_foldersumneu).setVisibility(View.VISIBLE);
                    ((TextView) v.findViewById(R.id.row_foldersumneu)).setText(Integer.toString(neutCount));	
                }
                int posCount = sumIntRows(socialFeedCursor, socialFeedCursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT));
                posCount = checkNegativeUnreads(posCount);
                if (posCount == 0) {
                    v.findViewById(R.id.row_foldersumpos).setVisibility(View.GONE);
                } else {
                    v.findViewById(R.id.row_foldersumpos).setVisibility(View.VISIBLE);
                    ((TextView) v.findViewById(R.id.row_foldersumpos)).setText(Integer.toString(posCount));
                }
            } 
            v.findViewById(R.id.row_foldersums).setVisibility(isExpanded ? View.INVISIBLE : View.VISIBLE);
			((ImageView) v.findViewById(R.id.row_folder_indicator)).setImageResource(isExpanded ? R.drawable.indicator_expanded : R.drawable.indicator_collapsed);
		} else if (isFolderRoot(groupPosition)) {
			v =  inflater.inflate(R.layout.row_all_stories, null, false);
            int posCount = 0;
            for (int i : posCounts) posCount += i;
            int neutCount = 0;
            for (int i : neutCounts) neutCount += i;
            bindCountViews(v, neutCount, posCount, true);
        } else if (isRowSavedStories(groupPosition)) {
            if (convertView == null) {
                v = inflater.inflate(R.layout.row_saved_stories, null, false);
            }
            ((TextView) v.findViewById(R.id.row_foldersum)).setText(Integer.toString(savedStoriesCount));
		} else {
			if (convertView == null) {
				v = inflater.inflate((isExpanded) ? R.layout.row_folder_collapsed : R.layout.row_folder_collapsed, parent, false);
			}
            final String folderName = activeFolderNames.get(convertGroupPositionToActiveFolderIndex(groupPosition));
			TextView folderTitle = ((TextView) v.findViewById(R.id.row_foldername));
		    folderTitle.setText(folderName.toUpperCase());
			folderTitle.setOnClickListener(new OnClickListener() {
				@Override
				public void onClick(View v) {
					Intent i = new Intent(v.getContext(), FolderItemsList.class);
					i.putExtra(FolderItemsList.EXTRA_FOLDER_NAME, folderName);
					i.putExtra(FolderItemsList.EXTRA_STATE, currentState);
					((Activity) context).startActivity(i);
				}
			});
            int countPosition = convertGroupPositionToActiveFolderIndex(groupPosition);
            bindCountViews(v, neutCounts.get(countPosition), posCounts.get(countPosition), false);
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
			socialFeedCursor.moveToPosition(childPosition);
			if (convertView == null) {
                v = inflater.inflate(R.layout.row_socialfeed, parent, false);
			} else {
				v = convertView;
			}
            SocialFeed f = SocialFeed.fromCursor(socialFeedCursor);
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

	@Override
	public String getGroup(int groupPosition) {
		return activeFolderNames.get(convertGroupPositionToActiveFolderIndex(groupPosition));
	}

    private int convertGroupPositionToActiveFolderIndex(int groupPosition) {
        // Global and social feeds are shown above the named folders so the groupPosition
        // needs to be adjusted to index into the active folders lists.
        return groupPosition - 2;
    }

	@Override
	public int getGroupCount() {
        // in addition to the real folders returned by the /reader/feeds API, there are virtual folders
        // for global shared stories, social feeds and saved stories
        if (activeFolderNames == null) return 0;
		return (activeFolderNames.size() + 3);
	}

	@Override
	public long getGroupId(int groupPosition) {
        // Global shared, all shared and saved stories don't have IDs so give them a really
        // huge one.
        if (groupPosition == GLOBAL_SHARED_STORIES_GROUP_POSITION) {
            return Long.MAX_VALUE;
        } else if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
            return Long.MAX_VALUE-1;
        } else if (isRowSavedStories(groupPosition)) {
            return Long.MAX_VALUE-2;
        } else {
		    return activeFolderNames.get(convertGroupPositionToActiveFolderIndex(groupPosition)).hashCode();
		}
	}
	
	@Override
	public int getChildrenCount(int groupPosition) {
		if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
            if (socialFeedCursor == null) return 0;
			return socialFeedCursor.getCount();
        } else if (isRowSavedStories(groupPosition) || groupPosition == GLOBAL_SHARED_STORIES_GROUP_POSITION) {
            return 0; // these rows never have children
		} else {
            return activeFolderChildren.get(convertGroupPositionToActiveFolderIndex(groupPosition)).size();
		}
	}

	@Override
	public String getChild(int groupPosition, int childPosition) {
		if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
			socialFeedCursor.moveToPosition(childPosition);
			return getStr(socialFeedCursor, DatabaseConstants.SOCIAL_FEED_ID);
        } else {
			return activeFolderChildren.get(convertGroupPositionToActiveFolderIndex(groupPosition)).get(childPosition).feedId;
		}
	}

	@Override
    public long getChildId(int groupPosition, int childPosition) {
		return getChild(groupPosition, childPosition).hashCode();
	}

	public String getGroupName(int groupPosition) {
        // these "names" aren't actually what is used to render the row, but are used
        // by the fragment for tracking row identity to save open/close preferences
		if (groupPosition == ALL_SHARED_STORIES_GROUP_POSITION) {
			return "[ALL_SHARED_STORIES]";
		} else if (groupPosition == GLOBAL_SHARED_STORIES_GROUP_POSITION) {
            return "[GLOBAL_SHARED_STORIES]";
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
        return ( getGroupName(groupPosition).equals(AppConstants.ROOT_FOLDER) );
    }

    /**
     * Determines if the row at the specified position is the special "saved" folder. This
     * row doesn't actually correspond to a row in the DB, much like the social row, but
     * it is located at the bottom of the set rather than the top.
     */
    public boolean isRowSavedStories(int groupPosition) {
        return ( groupPosition > (activeFolderNames.size() + 1) );
    }

	public void setSocialFeedCursor(Cursor cursor) {
		this.socialFeedCursor = cursor;
        notifyDataSetChanged();
	}

    public synchronized void setFoldersCursor(Cursor cursor) {
        if ((cursor.getCount() < 1) || (!cursor.isBeforeFirst())) return;
        folders = new LinkedHashMap<String,Folder>(cursor.getCount());
        while (cursor.moveToNext()) {
            Folder folder = Folder.fromCursor(cursor);
            folders.put(folder.flatName(), folder);
        }
        /*
        if (!folders.containsKey(AppConstants.ROOT_FOLDER)) {
            Folder fakeRoot = new Folder();
            fakeRoot.name = AppConstants.ROOT_FOLDER;
            fakeRoot.parents = Collections.emptyList();
            fakeRoot.children = Collections.emptyList();
            fakeRoot.feedIds = Collections.emptyList();
            folders.put(AppConstants.ROOT_FOLDER, fakeRoot);
        }
        */
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
        neutCounts = new ArrayList<Integer>();
        posCounts = new ArrayList<Integer>();
        // create a sorted list of folder display names
        List<String> sortedFolderNames = new ArrayList<String>(folders.keySet());
        customSortList(sortedFolderNames);
        // inspect folders to see if the are active for display
        for (String folderName : sortedFolderNames) {
            List<Feed> activeFeeds = new ArrayList<Feed>();
            int neutCount = 0;
            int posCount = 0;
            for (Long feedId : folders.get(folderName).feedIds) {
                Feed f = feeds.get(feedId.toString());
                if (f != null) {
                    if (((currentState == StateFilter.BEST) && (f.positiveCount > 0)) ||
                        ((currentState == StateFilter.SOME) && ((f.positiveCount + f.neutralCount > 0))) ||
                        (currentState == StateFilter.ALL)) {
                        activeFeeds.add(f);
                    }
                    neutCount += checkNegativeUnreads(f.neutralCount);
                    posCount += checkNegativeUnreads(f.positiveCount);
                }
            }
            if ((activeFeeds.size() > 0) || (folderName.equals(AppConstants.ROOT_FOLDER))) {
                activeFolderNames.add(folderName);
                Collections.sort(activeFeeds);
                activeFolderChildren.add(activeFeeds);
                neutCounts.add(neutCount);
                posCounts.add(posCount);
            }
        }
    }

    public Feed getFeed(String feedId) {
        return feeds.get(feedId);
    }

    public SocialFeed getSocialFeed(String socialFeedId) {
        socialFeedCursor.moveToPosition(-1);
        while (socialFeedCursor.moveToNext()) {
            if (getStr(socialFeedCursor, DatabaseConstants.SOCIAL_FEED_ID).equals(socialFeedId)) break;
        }
        return SocialFeed.fromCursor(socialFeedCursor);
    }

	public void changeState(StateFilter state) {
		currentState = state;
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

    private static Comparator<String> CustomComparator = new Comparator<String>() {
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
