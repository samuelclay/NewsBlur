package com.newsblur.database;

import static com.newsblur.util.AppConstants.ALL_SHARED_STORIES_GROUP_KEY;
import static com.newsblur.util.AppConstants.ALL_STORIES_GROUP_KEY;
import static com.newsblur.util.AppConstants.GLOBAL_SHARED_STORIES_GROUP_KEY;
import static com.newsblur.util.AppConstants.INFREQUENT_SITE_STORIES_GROUP_KEY;
import static com.newsblur.util.AppConstants.READ_STORIES_GROUP_KEY;
import static com.newsblur.util.AppConstants.SAVED_SEARCHES_GROUP_KEY;
import static com.newsblur.util.AppConstants.SAVED_STORIES_GROUP_KEY;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import android.content.Context;
import android.graphics.Bitmap;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseExpandableListAdapter;
import android.widget.ExpandableListView;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.RelativeLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.material.progressindicator.CircularProgressIndicator;
import com.newsblur.R;
import com.newsblur.domain.CustomIcon;
import com.newsblur.domain.Feed;
import com.newsblur.util.CustomIconRenderer;
import com.newsblur.domain.FeedQueryResult;
import com.newsblur.domain.Folder;
import com.newsblur.domain.FolderQueryResult;
import com.newsblur.domain.SavedSearch;
import com.newsblur.domain.SavedStoryCountsQueryResult;
import com.newsblur.domain.StarredCount;
import com.newsblur.domain.SocialFeed;
import com.newsblur.preference.PrefsRepo;
import com.newsblur.util.Session;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedListOrder;
import com.newsblur.util.SessionDataSource;
import com.newsblur.util.SpacingStyle;
import com.newsblur.util.FeedSet;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.StateFilter;
import com.newsblur.util.UIUtils;

/**
 * Custom adapter to display a nested folder/feed list in an ExpandableListView.
 */
public class FolderListAdapter extends BaseExpandableListAdapter {

    private enum GroupType { GLOBAL_SHARED_STORIES, ALL_SHARED_STORIES, INFREQUENT_STORIES, ALL_STORIES, FOLDER, READ_STORIES, SAVED_SEARCHES, SAVED_STORIES }
    private enum ChildType { SOCIAL_FEED, FEED, SAVED_BY_TAG, SAVED_SEARCH }

    private final static float defaultTextSize_childName = 14;
    private final static float defaultTextSize_count = 13;

    private final static float NONZERO_UNREADS_ALPHA = 0.87f;
    private final static float ZERO_UNREADS_ALPHA = 0.70f;

    /** Social feed in display order. */
    private final List<SocialFeed> socialFeedsOrdered = new ArrayList<>();
    /** Active social feed in display order. */
    private final List<SocialFeed> socialFeedsActive = new ArrayList<>();
    /** Total neutral unreads for all social feeds. */
    public int totalSocialNeutCount = 0;
    /** Total positive unreads for all social feeds. */
    public int totalSocialPosiCount = 0;
    /** Total active feeds. */
    public int totalActiveFeedCount = 0;

    /** Feeds, indexed by feed ID. */
    private final Map<String,Feed> feeds = new LinkedHashMap<>();
    /** Neutral counts for active feeds, indexed by feed ID. */
    private final Map<String,Integer> feedNeutCounts = new LinkedHashMap<>();
    /** Positive counts for active feeds, indexed by feed ID. */
    private final Map<String,Integer> feedPosCounts = new LinkedHashMap<>();
    /** Canonical folder name to active (non-muted) feed IDs (includes descendants). */
    private final Map<String, Set<String>> activeFeedIdsByFolder = new LinkedHashMap<>();
    /** Total neutral unreads for all feeds. */
    public int totalNeutCount = 0;
    /** Total positive unreads for all feeds. */
    public int totalPosCount = 0;
    /** Saved counts for active feeds, indexed by feed ID. */
    private final Map<String,Integer> feedSavedCounts = new LinkedHashMap<>();

    /** Folders, indexed by canonical name. */
    private final Map<String,Folder> folders = new LinkedHashMap<>();
    /** Folders, indexed by flat name. */
    private final Map<String,Folder> flatFolders = new LinkedHashMap<>();
    /** Flat names of currently displayed folders in display order. */
    private List<String> activeFolderNames;
    /** List of currently displayed feeds for a folder, ordered the same as activeFolderNames. */
    private List<List<Feed>> activeFolderChildren;
    /** List of folder neutral counts, ordered the same as activeFolderNames. */
    private List<Integer> folderNeutCounts;
    /** List of foler positive counts, ordered the same as activeFolderNames. */
    private List<Integer> folderPosCounts;

    /** Starred story sets in display order. */
    private final List<StarredCount> starredCountsByTag = new ArrayList<>();
    /** Saved Searches */
    private final List<SavedSearch> savedSearches = new ArrayList<>();

    private int savedStoriesTotalCount;

    /** A simple count of how many feeds/children are actually being displayed. */
    public int lastFeedCount = 0;

    /** Flat names of folders explicity closed by the user. */
    private final Set<String> closedFolders = new HashSet<String>();

    private final Context context;
	private final LayoutInflater inflater;
	private StateFilter currentState;
	private final ImageLoader iconLoader;
    private final PrefsRepo prefsRepo;

    // since we want to implement a custom expando that does group collapse/expand, we need
    // a way to call back to those functions on the listview from the onclick listener of
    // views we crate for the list.
    public WeakReference<ExpandableListView> listBackref;

    private float textSize;
    private SpacingStyle spacingStyle;

    // in order to implement the laggy disappearance of marked-read feeds, preserve the ID of
    // the last feed or folder viewed and force the DB to include it in the selection
    public String lastFeedViewedId;
    public String lastFolderViewed;

    public String activeSearchQuery;

	public FolderListAdapter(Context context, StateFilter currentState, ImageLoader iconLoader, PrefsRepo prefsRepo) {
        this.currentState = currentState;
        this.context = context;
		this.inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
		this.iconLoader = iconLoader;
        this.prefsRepo = prefsRepo;

        textSize = prefsRepo.getListTextSize();
        spacingStyle = prefsRepo.getSpacingStyle();
	}

	@Override
	public synchronized View getGroupView(final int groupPosition, final boolean isExpanded, View convertView, ViewGroup parent) {
		View v = convertView;
        if (isRowGlobalSharedStories(groupPosition)) {
            if (v == null) v = inflater.inflate(R.layout.row_global_shared_stories, null, false);
        } else if (isRowAllSharedStories(groupPosition)) {
            if (socialFeedsOrdered.isEmpty()) {
                return inflater.inflate(R.layout.row_hidden_folder, null, false);
            }
			v =  inflater.inflate(R.layout.row_all_shared_stories, null, false);
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
		} else if (isRowAllStories(groupPosition)) {
			if (v == null) v =  inflater.inflate(R.layout.row_all_stories, null, false);
		} else if (isRowInfrequentStories(groupPosition)) {
			if (v == null) v =  inflater.inflate(R.layout.row_infrequent_stories, null, false);
        } else if (isRowReadStories(groupPosition)) {
            if (v == null) v = inflater.inflate(R.layout.row_read_stories, null, false);
        } else if (isRowSavedSearches(groupPosition)) {
            if (savedSearches.isEmpty()) {
                return inflater.inflate(R.layout.row_hidden_folder, null, false);
            }
            v = inflater.inflate(R.layout.row_saved_searches, null, false);
        } else if (isRowSavedStories(groupPosition)) {
            if (v == null) v = inflater.inflate(R.layout.row_saved_stories, null, false);
            TextView savedSum = v.findViewById(R.id.row_foldersum);
            if (savedStoriesTotalCount > 0) {
                savedSum.setVisibility(View.VISIBLE);
                savedSum.setText(Integer.toString(savedStoriesTotalCount));
            } else {
                savedSum.setVisibility(View.GONE);
            }
		} else {
			if (v == null) v = inflater.inflate(R.layout.row_folder, parent, false);
            String folderName = activeFolderNames.get(groupPosition);
			TextView folderTitle = v.findViewById(R.id.row_foldername);
		    folderTitle.setText(folderName);
		    folderTitle.setTextSize(textSize * defaultTextSize_childName);
            bindCountViews(v, folderNeutCounts.get(groupPosition), folderPosCounts.get(groupPosition), false);
            v.findViewById(R.id.row_foldersums).setVisibility(isExpanded ? View.INVISIBLE : View.VISIBLE);
            ImageView folderIconView = v.findViewById(R.id.row_folder_icon);
            if ( folderIconView != null ) {
                CustomIcon customIcon = BlurDatabaseHelper.getFolderIcon(folderName);
                if (customIcon != null) {
                    int iconSize = UIUtils.dp2px(context, 19);
                    Bitmap iconBitmap = CustomIconRenderer.renderIcon(context, customIcon, iconSize);
                    if (iconBitmap != null) {
                        folderIconView.setImageBitmap(iconBitmap);
                    } else {
                        folderIconView.setImageResource(isExpanded ? R.drawable.ic_folder : R.drawable.ic_folder_closed);
                    }
                } else {
                    folderIconView.setImageResource(isExpanded ? R.drawable.ic_folder : R.drawable.ic_folder_closed);
                }
            }
		}

        @NonNull TextView groupNameView = v.findViewById(R.id.row_foldername);
        groupNameView.setTextSize(textSize * defaultTextSize_childName);
        int titleVerticalPadding = spacingStyle.getGroupTitleVerticalPadding(context);
        groupNameView.setPadding(0, titleVerticalPadding, 0, titleVerticalPadding);
        @Nullable TextView sumNeutView = v.findViewById(R.id.row_foldersumneu);
        if (sumNeutView != null ) sumNeutView.setTextSize(textSize * defaultTextSize_count);
        @Nullable TextView sumPosiView = v.findViewById(R.id.row_foldersumpos);
        if (sumPosiView != null ) sumPosiView.setTextSize(textSize * defaultTextSize_count);
        @Nullable TextView sumSavedView = v.findViewById(R.id.row_foldersum);
        if (sumSavedView != null ) sumSavedView.setTextSize(textSize * defaultTextSize_count);

        // if a group has a sub-view called row_folder_indicator, it will act as an expando
        @Nullable ImageView folderIndicatorView = v.findViewById(R.id.row_folder_indicator);
        if ( folderIndicatorView != null ) {
            folderIndicatorView.setImageResource(isExpanded ? R.drawable.ic_arrow_down : R.drawable.ic_arrow_up);
			folderIndicatorView.setOnClickListener(v1 -> toggleGroup(v1, groupPosition, isExpanded));
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
		int titleVerticalPadding = spacingStyle.getChildTitleVerticalPadding(context);
		if (isRowAllSharedStories(groupPosition)) {
            if (v == null) v = inflater.inflate(R.layout.row_socialfeed, parent, false);
            SocialFeed f = socialFeedsActive.get(childPosition);
            TextView nameView = v.findViewById(R.id.row_socialfeed_name);
            nameView.setText(f.feedTitle);
            nameView.setTextSize(textSize * defaultTextSize_childName);
            nameView.setPadding(nameView.getPaddingLeft(), titleVerticalPadding, nameView.getPaddingRight(), titleVerticalPadding);
            ImageView iconView = v.findViewById(R.id.row_socialfeed_icon);
            iconLoader.displayImage(f.photoUrl, iconView);
            TextView neutCounter = v.findViewById(R.id.row_socialsumneu);
            if (f.neutralCount > 0 && currentState != StateFilter.BEST) {
                neutCounter.setVisibility(View.VISIBLE);
                neutCounter.setText(Integer.toString(checkNegativeUnreads(f.neutralCount)));
            } else {
                neutCounter.setVisibility(View.GONE);
            }
            TextView posCounter = v.findViewById(R.id.row_socialsumpos);
            if (f.positiveCount > 0) {
                posCounter.setVisibility(View.VISIBLE);
                posCounter.setText(Integer.toString(checkNegativeUnreads(f.positiveCount)));
            } else {
                posCounter.setVisibility(View.GONE);
            }
            neutCounter.setTextSize(textSize * defaultTextSize_count);
            posCounter.setTextSize(textSize * defaultTextSize_count);
            if ((f.neutralCount <= 0) && (f.positiveCount <= 0)) {
                nameView.setAlpha(ZERO_UNREADS_ALPHA);
                iconView.setAlpha(ZERO_UNREADS_ALPHA);
            } else {
                nameView.setAlpha(NONZERO_UNREADS_ALPHA);
                iconView.setAlpha(NONZERO_UNREADS_ALPHA);
            }
        } else if (isRowSavedStories(groupPosition)) {
            if (v == null) v = inflater.inflate(R.layout.row_saved_tag, parent, false);
            StarredCount sc = starredCountsByTag.get(childPosition);
            TextView nameView = v.findViewById(R.id.row_tag_name);
            nameView.setText(sc.tag);
            nameView.setTextSize(textSize * defaultTextSize_childName);
            nameView.setAlpha(NONZERO_UNREADS_ALPHA);
            nameView.setPadding(nameView.getPaddingLeft(), titleVerticalPadding, nameView.getPaddingRight(), titleVerticalPadding);
            TextView savedCounter = v.findViewById(R.id.row_saved_tag_sum);
            savedCounter.setText(Integer.toString(checkNegativeUnreads(sc.count)));
            savedCounter.setTextSize(textSize * defaultTextSize_count);
		} else if (isRowSavedSearches(groupPosition)) {
            if (v == null) v = inflater.inflate(R.layout.row_saved_search_child, parent, false);
            SavedSearch ss = savedSearches.get(childPosition);
            TextView nameView = v.findViewById(R.id.row_saved_search_title);
            nameView.setText(UIUtils.fromHtml(ss.feedTitle));
            nameView.setPadding(nameView.getPaddingLeft(), titleVerticalPadding, nameView.getPaddingRight(), titleVerticalPadding);
            ImageView iconView = v.findViewById(R.id.row_saved_search_icon);
            iconLoader.preCheck(ss.faviconUrl, iconView);
            iconLoader.displayImage(ss.faviconUrl, iconView);
        } else {
            if (v == null) v = inflater.inflate(R.layout.row_feed, parent, false);
            Feed f = activeFolderChildren.get(groupPosition).get(childPosition);
            FrameLayout containerTitle = v.findViewById(R.id.row_title);
            int rowMarginStart = isRowAllStories(groupPosition) ? 0 : UIUtils.dp2px(context, 32);
            RelativeLayout.LayoutParams lp = (RelativeLayout.LayoutParams) containerTitle.getLayoutParams();
            lp.setMarginStart(rowMarginStart);
            containerTitle.setLayoutParams(lp);
            TextView nameView = v.findViewById(R.id.row_feedname);
            nameView.setText(f.title);
            nameView.setTextSize(textSize * defaultTextSize_childName);
            nameView.setPadding(nameView.getPaddingLeft(), titleVerticalPadding, nameView.getPaddingRight(), titleVerticalPadding);
            ImageView iconView = v.findViewById(R.id.row_feedfavicon);
            CustomIcon customFeedIcon = BlurDatabaseHelper.getFeedIcon(f.feedId);
            if (customFeedIcon != null) {
                int iconSize = UIUtils.dp2px(context, 19);
                Bitmap iconBitmap = CustomIconRenderer.renderIcon(context, customFeedIcon, iconSize);
                if (iconBitmap != null) {
                    iconView.setImageBitmap(iconBitmap);
                } else {
                    iconLoader.preCheck(f.faviconUrl, iconView);
                    iconLoader.displayImage(f.faviconUrl, iconView);
                }
            } else {
                iconLoader.preCheck(f.faviconUrl, iconView);
                iconLoader.displayImage(f.faviconUrl, iconView);
            }
            TextView neutCounter = v.findViewById(R.id.row_feedneutral);
            TextView posCounter = v.findViewById(R.id.row_feedpositive);
            TextView savedCounter = v.findViewById(R.id.row_feedsaved);
            ImageView muteIcon = v.findViewById(R.id.row_feedmuteicon);
            CircularProgressIndicator fetchingIcon = v.findViewById(R.id.row_feedfetching);
            if (!f.active) {
                muteIcon.setVisibility(View.VISIBLE);
                neutCounter.setVisibility(View.GONE);
                posCounter.setVisibility(View.GONE);
                savedCounter.setVisibility(View.GONE);
                fetchingIcon.setVisibility(View.GONE);
                fetchingIcon.setProgress(100);
                nameView.setAlpha(ZERO_UNREADS_ALPHA);
                iconView.setAlpha(ZERO_UNREADS_ALPHA);
            } else if (f.fetchPending) {
                muteIcon.setVisibility(View.GONE);
                neutCounter.setVisibility(View.GONE);
                posCounter.setVisibility(View.GONE);
                savedCounter.setVisibility(View.GONE);
                fetchingIcon.setVisibility(View.VISIBLE);
                fetchingIcon.setProgress(0);
                nameView.setAlpha(NONZERO_UNREADS_ALPHA);
                iconView.setAlpha(NONZERO_UNREADS_ALPHA);
            } else if (currentState == StateFilter.SAVED) {
                muteIcon.setVisibility(View.GONE);
                neutCounter.setVisibility(View.GONE);
                posCounter.setVisibility(View.GONE);
                savedCounter.setVisibility(View.VISIBLE);
                savedCounter.setText(Integer.toString(zeroForNull(feedSavedCounts.get(f.feedId))));
                fetchingIcon.setVisibility(View.GONE);
                fetchingIcon.setProgress(100);
                nameView.setAlpha(NONZERO_UNREADS_ALPHA);
                iconView.setAlpha(NONZERO_UNREADS_ALPHA);
            } else if (currentState == StateFilter.BEST) {
                muteIcon.setVisibility(View.GONE);
                neutCounter.setVisibility(View.GONE);
                savedCounter.setVisibility(View.GONE);
                posCounter.setVisibility(View.VISIBLE);
                fetchingIcon.setVisibility(View.GONE);
                fetchingIcon.setProgress(100);
                if (f.positiveCount <= 0) {
                    posCounter.setVisibility(View.GONE);
                    nameView.setAlpha(ZERO_UNREADS_ALPHA);
                    iconView.setAlpha(ZERO_UNREADS_ALPHA);
                } else {
                    posCounter.setText(Integer.toString(checkNegativeUnreads(f.positiveCount)));
                    nameView.setAlpha(NONZERO_UNREADS_ALPHA);
                    iconView.setAlpha(NONZERO_UNREADS_ALPHA);
                }
            } else {
                muteIcon.setVisibility(View.GONE);
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
                fetchingIcon.setVisibility(View.GONE);
                fetchingIcon.setProgress(100);
                if ((f.neutralCount <= 0) && (f.positiveCount <= 0)) {
                    nameView.setAlpha(ZERO_UNREADS_ALPHA);
                    iconView.setAlpha(ZERO_UNREADS_ALPHA);
                } else {
                    nameView.setAlpha(NONZERO_UNREADS_ALPHA);
                    iconView.setAlpha(NONZERO_UNREADS_ALPHA);
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
        if (isRowGlobalSharedStories(groupPosition)) {
            return FeedSet.globalShared();
        } else if (isRowAllSharedStories(groupPosition)) {
            return FeedSet.allSocialFeeds();
        } else if (isRowAllStories(groupPosition)) {
            if (currentState == StateFilter.SAVED) return FeedSet.allSaved();
            return FeedSet.allFeeds();
        } else if (isRowInfrequentStories(groupPosition)) {
            return FeedSet.infrequentFeeds();
        } else if (isRowReadStories(groupPosition)) {
            return FeedSet.allRead();
        } else if (isRowSavedStories(groupPosition)) {
            return FeedSet.allSaved();
        } else {
            String folderName = getGroupFolderName(groupPosition);
            Set<String> activeIds = activeFeedIdsByFolder.get(folderName);
            if (activeIds == null) activeIds = Collections.emptySet();
            FeedSet fs = FeedSet.folder(folderName, activeIds);
            if (currentState == StateFilter.SAVED) fs.setFilterSaved(true);
            return fs;
        }
    }

    /**
     * Get the canonical (not flattened with parents) name of the folder at the given group position.
     * Supports normal folders only, not special all-type meta-folders.
     */
    public String getGroupFolderName(int groupPosition) {
        if (isRowRootFolder(groupPosition)) return AppConstants.ROOT_FOLDER;
        String flatFolderName = activeFolderNames.get(groupPosition);
        Folder folder = flatFolders.get(flatFolderName);
        return folder.name;
    }

    public Folder getGroupFolder(int groupPosition) {
        String flatFolderName = activeFolderNames.get(groupPosition);
        return flatFolders.get(flatFolderName);
    }

	@Override
	public synchronized int getGroupCount() {
        if (activeFolderNames == null) return 0;
		return (activeFolderNames.size());
	}

	@Override
	public synchronized long getGroupId(int groupPosition) {
        return activeFolderNames.get(groupPosition).hashCode();
	}

	@Override
	public synchronized int getChildrenCount(int groupPosition) {
		if (isRowAllSharedStories(groupPosition)) {
			return socialFeedsActive.size();
        } else if (isRowSavedStories(groupPosition)) {
            return starredCountsByTag.size();
		} else if (isRowSavedSearches(groupPosition)) {
		    return savedSearches.size();
        } else {
            return activeFolderChildren.get(groupPosition).size();
		}
	}

	@Override
	public synchronized FeedSet getChild(int groupPosition, int childPosition) {
		if (isRowAllSharedStories(groupPosition)) {
            SocialFeed socialFeed = socialFeedsActive.get(childPosition);
            return FeedSet.singleSocialFeed(socialFeed.userId, socialFeed.username);
        } else if (isRowSavedStories(groupPosition)) {
            return FeedSet.singleSavedTag(starredCountsByTag.get(childPosition).tag);
        } else if (isRowSavedSearches(groupPosition)) {
		    SavedSearch savedSearch = savedSearches.get(childPosition);
		    return FeedSet.singleSavedSearch(savedSearch.feedId, savedSearch.query);
        } else {
            Feed feed = activeFolderChildren.get(groupPosition).get(childPosition);
            FeedSet fs = FeedSet.singleFeed(feed.feedId);
            if (!feed.active) fs.setMuted(true);
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
        return activeFolderNames.get(groupPosition);
	}

    public boolean isRowGlobalSharedStories(int groupPosition) {
        return GLOBAL_SHARED_STORIES_GROUP_KEY.equals(activeFolderNames.get(groupPosition));
    }

    public boolean isRowAllSharedStories(int groupPosition) {
        return ALL_SHARED_STORIES_GROUP_KEY.equals(activeFolderNames.get(groupPosition));
    }

    public boolean isRowAllStories(int groupPosition) {
        return ALL_STORIES_GROUP_KEY.equals(activeFolderNames.get(groupPosition));
    }

    public boolean isRowInfrequentStories(int groupPosition) {
        return INFREQUENT_SITE_STORIES_GROUP_KEY.equals(activeFolderNames.get(groupPosition));
    }

    public boolean isRowReadStories(int groupPosition) {
        return READ_STORIES_GROUP_KEY.equals(activeFolderNames.get(groupPosition));
    }

    public boolean isRowSavedStories(int groupPosition) {
        return SAVED_STORIES_GROUP_KEY.equals(activeFolderNames.get(groupPosition));
    }

    public boolean isRowSavedSearches(int groupPosition) {
        return SAVED_SEARCHES_GROUP_KEY.equals(activeFolderNames.get(groupPosition));
    }

    /**
     * Determines if the row at the specified position is last of the special rows, under which
     * un-foldered "root level" feeds are created as children.  These feeds are not in any folder,
     * but the UI convention is that they appear below special rows and above folders.
     */
    public boolean isRowRootFolder(int groupPosition) {
        return isRowAllStories(groupPosition);
    }

    private int getRootFolderIndex() {
        return activeFolderNames.indexOf(ALL_STORIES_GROUP_KEY);
    }

	public synchronized void setSocialFeeds(@NonNull List<SocialFeed> socialFeeds) {
        socialFeedsOrdered.clear();
        socialFeedsOrdered.addAll(socialFeeds);
        recountSocialFeeds();
    }

    private void recountSocialFeeds() {
        socialFeedsActive.clear();
        totalSocialNeutCount = 0;
        totalSocialPosiCount = 0;
        for (SocialFeed f : socialFeedsOrdered) {
            totalSocialNeutCount += checkNegativeUnreads(f.neutralCount);
            totalSocialPosiCount += checkNegativeUnreads(f.positiveCount);
            if ( (currentState == StateFilter.ALL) ||
                 ((currentState == StateFilter.SOME) && (f.neutralCount > 0 || f.positiveCount > 0)) ||
                 ((currentState == StateFilter.BEST) && (f.positiveCount > 0)) ) {
                if ((activeSearchQuery == null) || (f.feedTitle.toLowerCase().indexOf(activeSearchQuery.toLowerCase()) >= 0)) {
                    socialFeedsActive.add(f);
                }
            }
        }

        recountChildren();
        notifyDataSetChanged();
	}

    public synchronized void setFolders(FolderQueryResult foldersResult) {
        folders.clear();
        flatFolders.clear();
        folders.putAll(foldersResult.getFolders());
        flatFolders.putAll(foldersResult.getFlatFolders());

        recountFeeds();
        notifyDataSetChanged();
    }

	public synchronized void setFeeds(FeedQueryResult feedQueryResult) {
        feeds.clear();
        feeds.putAll(feedQueryResult.getFeeds());
        feedNeutCounts.clear();
        feedNeutCounts.putAll(feedQueryResult.getFeedNeutCounts());
        feedPosCounts.clear();
        feedPosCounts.putAll(feedQueryResult.getFeedPosCounts());
        totalNeutCount = feedQueryResult.getTotalNeutCount();
        totalPosCount = feedQueryResult.getTotalPosCount();
        totalActiveFeedCount = feedQueryResult.getTotalActiveFeedCount();

        recountFeeds();
        notifyDataSetChanged();
	}

	public synchronized void setStarredCount(SavedStoryCountsQueryResult result) {
        starredCountsByTag.clear();
        feedSavedCounts.clear();
        starredCountsByTag.addAll(result.getStarredCountsByTag());
        feedSavedCounts.putAll(result.getFeedSavedCounts());
        if (result.getSavedStoriesTotalCount() != null) {
            savedStoriesTotalCount = result.getSavedStoriesTotalCount();
        }

        recountFeeds();
        notifyDataSetChanged();
	}

	public synchronized void setSavedSearches(List<SavedSearch> savedSearches) {
        this.savedSearches.clear();
        this.savedSearches.addAll(savedSearches);
        notifyDataSetChanged();
    }

    private void recountFeeds() {
        if ((folders == null) || (feeds == null)) return;
        // re-init our local vars
        activeFolderNames = new ArrayList<String>();
        activeFolderChildren = new ArrayList<List<Feed>>();
        folderNeutCounts = new ArrayList<Integer>();
        folderPosCounts = new ArrayList<Integer>();

        if (prefsRepo.isEnableRowInfrequent() && (currentState != StateFilter.SAVED)) addSpecialRow(INFREQUENT_SITE_STORIES_GROUP_KEY);
        addSpecialRow(ALL_STORIES_GROUP_KEY);

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
                     ((currentState == StateFilter.SAVED) && feedSavedCounts.containsKey(feedId)) ||
                     f.feedId.equals(lastFeedViewedId) ) {
                    if ((activeSearchQuery == null) || (f.title.toLowerCase().indexOf(activeSearchQuery.toLowerCase()) >= 0)) {
                        activeFeeds.add(f);
                    }
                }
            }
            if ((activeFeeds.size() > 0) || (folderName.equals(AppConstants.ROOT_FOLDER)) || folder.name.equals(lastFolderViewed)) {
                Collections.sort(activeFeeds);
                if (folderName.equals(AppConstants.ROOT_FOLDER)) {
                    activeFolderChildren.set(getRootFolderIndex(), activeFeeds);
                } else {
                    activeFolderNames.add(folderName);
                    activeFolderChildren.add(activeFeeds);
                    folderNeutCounts.add(getFolderNeutralCountRecursive(folder, null));
                    folderPosCounts.add(getFolderPositiveCountRecursive(folder, null));
                }
            }
        }

        // sort feeds within each folder
        FeedListOrder feedListOrder = prefsRepo.getFeedListOrder();
        Comparator<Feed> feedComparator = Feed.getFeedListOrderComparator(feedListOrder);
        for (List<Feed> folderChildren : activeFolderChildren) {
            folderChildren.sort(feedComparator);
        }

        addSpecialRow(READ_STORIES_GROUP_KEY);
        if (prefsRepo.isEnableRowGlobalShared() && (currentState != StateFilter.SAVED)) addSpecialRow(GLOBAL_SHARED_STORIES_GROUP_KEY);
        if ((currentState != StateFilter.SAVED)) addSpecialRow(ALL_SHARED_STORIES_GROUP_KEY);
        addSpecialRow(SAVED_SEARCHES_GROUP_KEY);
        addSpecialRow(SAVED_STORIES_GROUP_KEY);
        rebuildActiveFolderFeedIdCache();
        recountChildren();
    }

    /**
     * Add a special (non-folder) row to activeFolderNames and blank data to all lists indexed
     * from said list.
     */
    private void addSpecialRow(String specialRowName) {
        activeFolderNames.add(specialRowName);
        List<Feed> emptyList = Collections.emptyList();
        activeFolderChildren.add(emptyList);
        folderNeutCounts.add(0);
        folderPosCounts.add(0);
    }

    private void recountChildren() {
        if (activeFolderChildren == null) return;
        int newFeedCount = 0;
        newFeedCount += socialFeedsActive.size();
        if (currentState == StateFilter.SAVED) {
            // only count saved feeds if in saved mode, since the expectation is that we are
            // counting to detect a zero-feeds-in-this-mode situation
            newFeedCount += starredCountsByTag.size();
        }
        for (List<Feed> folder : activeFolderChildren) {
            newFeedCount += folder.size();
        }
        lastFeedCount = newFeedCount;
    }

    /**
     * Given a set of (not-flat) folder names, figure out child folder names (also not flat). Does
     * not include the initially passed folder names, unless they occur as children of one of the
     * other parents passed.
     */
    private Set<String> getSubFoldersRecursive(Set<String> parentFolders) {
        HashSet<String> subFolders = new HashSet<String>();
        for (String folder : parentFolders) {
            Folder f = folders.get(folder);
            if (f == null) continue;
            subFolders.addAll(f.children);
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

    private void rebuildActiveFolderFeedIdCache() {
        activeFeedIdsByFolder.clear();
        for (String canonicalName : folders.keySet()) {
            buildActiveFeedIdsForFolder(canonicalName, new HashSet<>());
        }
    }

    private Set<String> buildActiveFeedIdsForFolder(String canonicalFolderName, Set<String> visiting) {
        Set<String> cached = activeFeedIdsByFolder.get(canonicalFolderName);
        if (cached != null) return cached;

        // folder cycle guard
        if (!visiting.add(canonicalFolderName)) return Collections.emptySet();

        Folder folder = folders.get(canonicalFolderName);
        if (folder == null) return Collections.emptySet();

        Set<String> result = new HashSet<>();
        for (String feedId : folder.feedIds) {
            Feed feed = feeds.get(feedId);
            if (feed != null && feed.active) {
                result.add(feedId);
            }
        }

        for (String childCanonicalName : folder.children) {
            result.addAll(buildActiveFeedIdsForFolder(childCanonicalName, visiting));
        }

        visiting.remove(canonicalFolderName);

        activeFeedIdsByFolder.put(canonicalFolderName, result);
        return result;
    }

    public synchronized void forceRecount() {
        recountFeeds();
        recountSocialFeeds();
        notifyDataSetChanged();
    }

    public void reset() {
        notifyDataSetInvalidated();

        synchronized (this) {
            socialFeedsOrdered.clear();
            socialFeedsActive.clear();
            totalSocialNeutCount = 0;
            totalSocialPosiCount = 0;

            folders.clear();
            flatFolders.clear();
            safeClear(activeFolderNames);
            safeClear(activeFolderChildren);
            safeClear(folderNeutCounts);
            safeClear(folderPosCounts);

            feeds.clear();
            safeClear(feedNeutCounts);
            safeClear(feedPosCounts);
            totalNeutCount = 0;
            totalPosCount = 0;

            safeClear(savedSearches);
            safeClear(starredCountsByTag);
            safeClear(closedFolders);

            notifyDataSetChanged();
        }
    }

    /** Get the cached Feed object for the feed at the given list location. */
    public synchronized Feed getFeed(int groupPosition, int childPosition) {
        if (groupPosition > activeFolderChildren.size()) return null;
        if (childPosition > activeFolderChildren.get(groupPosition).size()) return null;
        return activeFolderChildren.get(groupPosition).get(childPosition);
    }

    public Set<String> getAllFeedsForFolder(int groupPosition) {
        String flatFolderName = activeFolderNames.get(groupPosition);
        Folder folder = flatFolders.get(flatFolderName);
        return new HashSet<>(folder.feedIds);
    }

    /** Get the cached SocialFeed object for the feed at the given list location. */
    public SocialFeed getSocialFeed(int groupPosition, int childPosition) {
        return socialFeedsActive.get(childPosition);
    }

    /** Get the cached SavedSearch object at the given saved search list location. */
    public SavedSearch getSavedSearch(int childPosition) {
        return savedSearches.get(childPosition);
    }

	public synchronized void changeState(StateFilter state) {
		currentState = state;
        lastFeedViewedId = null; // clear when changing modes
        lastFolderViewed = null;
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
		if (isRowGlobalSharedStories(groupPosition)) {
			return GroupType.GLOBAL_SHARED_STORIES.ordinal();
		} else if (isRowAllSharedStories(groupPosition)) {
            return GroupType.ALL_SHARED_STORIES.ordinal();
        } else if (isRowAllStories(groupPosition)) {
            return GroupType.ALL_STORIES.ordinal();
        } else if (isRowInfrequentStories(groupPosition)) {
            return GroupType.INFREQUENT_STORIES.ordinal();
        } else if (isRowReadStories(groupPosition)) {
            return GroupType.READ_STORIES.ordinal();
        } else if (isRowSavedSearches(groupPosition)) {
		    return GroupType.SAVED_SEARCHES.ordinal();
        } else if (isRowSavedStories(groupPosition)) {
            return GroupType.SAVED_STORIES.ordinal();
        } else {
			return GroupType.FOLDER.ordinal();
		}
	}

    @Override
	public int getChildType(int groupPosition, int childPosition) {
		if (isRowAllSharedStories(groupPosition)) {
			return ChildType.SOCIAL_FEED.ordinal();
        } else if (isRowSavedStories(groupPosition)) {
            return ChildType.SAVED_BY_TAG.ordinal();
		} else if (isRowSavedSearches(groupPosition)) {
		    return ChildType.SAVED_SEARCH.ordinal();
        } else {
			return ChildType.FEED.ordinal();
		}
	}

	@Override
	public int getGroupTypeCount() {
	    int c = GroupType.values().length;
        return c;
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

    public void setSpacingStyle(SpacingStyle spacingStyle) {
        this.spacingStyle = spacingStyle;
    }

    public SessionDataSource buildSessionDataSource(Session activeSession) {
        return new SessionDataSource(activeSession, activeFolderNames, activeFolderChildren);
    }
}
