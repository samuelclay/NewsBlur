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
import com.newsblur.activity.NewsBlurApplication;
import static com.newsblur.database.DatabaseConstants.getStr;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.AppConstants;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.StateFilter;

/**
 * Custom adapter to display a nested folder/feed list in an ExpandableListView.
 */
public class FolderListAdapter extends BaseExpandableListAdapter {

    private enum GroupType { ALL_SHARED_STORIES, ALL_STORIES, FOLDER, SAVED_STORIES }
    private enum ChildType { SOCIAL_FEED, FEED }

    private Cursor socialFeedCursor;

    private Map<String,List<String>> folderFeedMap = Collections.emptyMap();
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
		if (groupPosition == 0) {
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
            final String folderName = activeFolderNames.get(groupPosition-1);
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
            bindCountViews(v, neutCounts.get(groupPosition-1), posCounts.get(groupPosition-1), false);
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
		if (groupPosition == 0) {
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
            Feed f = activeFolderChildren.get(groupPosition-1).get(childPosition);
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
		return activeFolderNames.get(groupPosition - 1);
	}

	@Override
	public int getGroupCount() {
        // in addition to the real folders returned by the /reader/feeds API, there are virtual folders
        // for social feeds and saved stories
        if (activeFolderNames == null) return 0;
		return (activeFolderNames.size() + 2);
	}

	@Override
	public long getGroupId(int groupPosition) {
		if (groupPosition == 0) {
            // the social folder doesn't have an ID, so just give it a really huge one
            return Long.MAX_VALUE;
        } else if (isRowSavedStories(groupPosition)) {
            // neither does the saved stories row, give it another
            return (Long.MAX_VALUE-1);
        } else {
		    return activeFolderNames.get(groupPosition-1).hashCode();
		}
	}
	
	@Override
	public int getChildrenCount(int groupPosition) {
		if (groupPosition == 0) {
            if (socialFeedCursor == null) return 0;
			return socialFeedCursor.getCount();
        } else if (isRowSavedStories(groupPosition)) {
            return 0; // this row never has children
		} else {
            return activeFolderChildren.get(groupPosition-1).size();
		}
	}

	@Override
	public String getChild(int groupPosition, int childPosition) {
		if (groupPosition == 0) {
			socialFeedCursor.moveToPosition(childPosition);
			return getStr(socialFeedCursor, DatabaseConstants.SOCIAL_FEED_ID);
        } else {
			return activeFolderChildren.get(groupPosition-1).get(childPosition).feedId;
		}
	}

	@Override
    public long getChildId(int groupPosition, int childPosition) {
		return getChild(groupPosition, childPosition).hashCode();
	}

	public String getGroupName(int groupPosition) {
        // these "names" aren't actually what is used to render the row, but are used
        // by the fragment for tracking row identity to save open/close preferences
		if (groupPosition == 0) {
			return "[ALL_SHARED_STORIES]";
		} else if (isRowSavedStories(groupPosition)) {
            return "[SAVED_STORIES]";
        } else {
			return activeFolderNames.get(groupPosition-1);
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
        return ( groupPosition > activeFolderNames.size() );
    }

	public void setSocialFeedCursor(Cursor cursor) {
		this.socialFeedCursor = cursor;
        notifyDataSetChanged();
	}

    public synchronized void setFolderFeedMapCursor(Cursor cursor) {
        if ((cursor.getCount() < 1) || (!cursor.isBeforeFirst())) return;
        folderFeedMap = newCustomSortedMap();
        while (cursor.moveToNext()) {
            String folderName = getStr(cursor, DatabaseConstants.FEED_FOLDER_FOLDER_NAME);
            String feedId = getStr(cursor, DatabaseConstants.FEED_FOLDER_FEED_ID);
            if (! folderFeedMap.containsKey(folderName)) folderFeedMap.put(folderName, new ArrayList<String>());
            folderFeedMap.get(folderName).add(feedId);
        }
        if (!folderFeedMap.containsKey(AppConstants.ROOT_FOLDER)) {
            folderFeedMap.put(AppConstants.ROOT_FOLDER, new ArrayList<String>());
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
        if ((folderFeedMap == null) || (feeds == null)) return;
        int c = folderFeedMap.keySet().size();
        activeFolderNames = new ArrayList<String>(c);
        activeFolderChildren = new ArrayList<List<Feed>>(c);
        neutCounts = new ArrayList<Integer>(c);
        posCounts = new ArrayList<Integer>(c);
        for (String folderName : folderFeedMap.keySet()) {
            List<Feed> activeFeeds = new ArrayList<Feed>();
            int neutCount = 0;
            int posCount = 0;
            for (String feedId : folderFeedMap.get(folderName)) {
                Feed f = feeds.get(feedId);
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
		if (groupPosition == 0) {
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
		if (groupPosition == 0) {
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
    private Map<String,List<String>> newCustomSortedMap() {
        Comparator<String> c = new Comparator<String>() {
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
        return new TreeMap<String,List<String>>(c);
    }
}
