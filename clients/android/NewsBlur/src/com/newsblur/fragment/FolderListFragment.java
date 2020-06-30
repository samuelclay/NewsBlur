package com.newsblur.fragment;

import java.lang.ref.WeakReference;
import java.util.HashSet;
import java.util.Set;

import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.LoaderManager;
import android.support.v4.content.Loader;
import android.util.Log;
import android.view.ContextMenu;
import android.view.ContextMenu.ContextMenuInfo;
import android.view.LayoutInflater;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnCreateContextMenuListener;
import android.view.ViewGroup;
import android.widget.ExpandableListView;
import android.widget.ExpandableListView.OnChildClickListener;
import android.widget.ExpandableListView.OnGroupClickListener;
import android.widget.ExpandableListView.OnGroupCollapseListener;
import android.widget.ExpandableListView.OnGroupExpandListener;

import com.newsblur.R;
import com.newsblur.activity.AllSharedStoriesItemsList;
import com.newsblur.activity.AllStoriesItemsList;
import com.newsblur.activity.FeedItemsList;
import com.newsblur.activity.FolderItemsList;
import com.newsblur.activity.GlobalSharedStoriesItemsList;
import com.newsblur.activity.InfrequentItemsList;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Main;
import com.newsblur.activity.NbActivity;
import com.newsblur.activity.ReadStoriesItemsList;
import com.newsblur.activity.SavedStoriesItemsList;
import com.newsblur.activity.SocialFeedItemsList;
import com.newsblur.database.FolderListAdapter;
import com.newsblur.databinding.FragmentFolderfeedlistBinding;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SavedSearch;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StateFilter;
import com.newsblur.util.UIUtils;

public class FolderListFragment extends NbFragment implements OnCreateContextMenuListener, 
                                                              LoaderManager.LoaderCallbacks<Cursor>,
                                                              OnChildClickListener, 
                                                              OnGroupClickListener,
                                                              OnGroupCollapseListener,
                                                              OnGroupExpandListener {

    private static final int SOCIALFEEDS_LOADER = 1;
    private static final int FOLDERS_LOADER = 2;
    private static final int FEEDS_LOADER = 3;
    private static final int SAVEDCOUNT_LOADER = 4;
    private static final int SAVED_SEARCH_LOADER = 5;

	private FolderListAdapter adapter;
	public StateFilter currentState = StateFilter.SOME;
	private SharedPreferences sharedPreferences;
	private FragmentFolderfeedlistBinding binding;
    public boolean firstCursorSeenYet = false;

    // the two-step context menu for feeds requires us to temp store the feed long-pressed so
    // it can be accessed during the sub-menu tap
    private Feed lastMenuFeed;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
        currentState = PrefsUtils.getStateFilter(getActivity());
		adapter = new FolderListAdapter(getActivity(), currentState);
        FeedUtils.currentFolderName = null;
        // NB: it is by design that loaders are not started until we get a
        // ping from the sync service indicating that it has initialised
	}

    @Override
    public void onResume() {
        super.onResume();
        if (adapter != null) {
            float textSize = PrefsUtils.getListTextSize(getActivity());
            adapter.setTextSize(textSize);
            adapter.notifyDataSetChanged();
        }
    }

    @Override
    public void onActivityCreated(Bundle savedInstanceState) {
        super.onActivityCreated(savedInstanceState);
		sharedPreferences = getActivity().getSharedPreferences(PrefConstants.PREFERENCES, 0);
    }

	@Override
	public Loader<Cursor> onCreateLoader(int id, Bundle args) {
        switch (id) {
            case SOCIALFEEDS_LOADER:
                return FeedUtils.dbHelper.getSocialFeedsLoader();
            case FOLDERS_LOADER:
                return FeedUtils.dbHelper.getFoldersLoader();
            case FEEDS_LOADER:
                return FeedUtils.dbHelper.getFeedsLoader();
            case SAVEDCOUNT_LOADER:
                return FeedUtils.dbHelper.getSavedStoryCountsLoader();
            case SAVED_SEARCH_LOADER:
                return FeedUtils.dbHelper.getSavedSearchLoader();
            default:
                throw new IllegalArgumentException("unknown loader created");
        }
	}

    @Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if (cursor == null) return;
        try {
            switch (loader.getId()) {
                case SOCIALFEEDS_LOADER:
                    adapter.setSocialFeedCursor(cursor);
                    pushUnreadCounts();
                    break;
                case FOLDERS_LOADER:
                    adapter.setFoldersCursor(cursor);
                    pushUnreadCounts();
                    checkOpenFolderPreferences();
                    break;
                case FEEDS_LOADER:
                    adapter.setFeedCursor(cursor);
                    checkOpenFolderPreferences();
                    firstCursorSeenYet = true;
                    pushUnreadCounts();
                    break;
                case SAVEDCOUNT_LOADER:
                    adapter.setStarredCountCursor(cursor);
                    break;
                case SAVED_SEARCH_LOADER:
                    adapter.setSavedSearchesCursor(cursor);
                    break;
                default:
                    throw new IllegalArgumentException("unknown loader created");
            }
        } catch (Exception e) {
            // for complex folder sets, these ops can take so long that they butt heads
            // with the destruction of the fragment and adapter. crashes can ensue.
            Log.w(this.getClass().getName(), "failed up update fragment state", e);
        }
    }

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
		; // our adapter doesn't hold on to cursors
	}

	public void hasUpdated() {
        if (isAdded()) {
            com.newsblur.util.Log.d(this, "loading feeds in mode: " + currentState);
            try {
                getLoaderManager().restartLoader(SOCIALFEEDS_LOADER, null, this);
                getLoaderManager().restartLoader(FOLDERS_LOADER, null, this);
                getLoaderManager().restartLoader(FEEDS_LOADER, null, this);
                getLoaderManager().restartLoader(SAVEDCOUNT_LOADER, null, this);
                getLoaderManager().restartLoader(SAVED_SEARCH_LOADER, null, this);
            } catch (Exception e) {
                // on heavily loaded devices, the time between isAdded() going false
                // and the loader subsystem shutting down can be nontrivial, causing
                // IllegalStateExceptions to be thrown here.
            }
        }
	}

    public synchronized void startLoaders() {
        if (isAdded()) {
            if (getLoaderManager().getLoader(FOLDERS_LOADER) == null) {
                // if the loaders haven't yet been created, do so
                getLoaderManager().initLoader(SOCIALFEEDS_LOADER, null, this);
                getLoaderManager().initLoader(FOLDERS_LOADER, null, this);
                getLoaderManager().initLoader(FEEDS_LOADER, null, this);
                getLoaderManager().initLoader(SAVEDCOUNT_LOADER, null, this);
                getLoaderManager().initLoader(SAVED_SEARCH_LOADER, null, this);
            }
        }
    }

    public void reset() {
        if (adapter != null) adapter.reset();
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View v = inflater.inflate(R.layout.fragment_folderfeedlist, container);
        binding = FragmentFolderfeedlistBinding.bind(v);

        binding.folderfeedList.setGroupIndicator(UIUtils.getDrawable(getActivity(), R.drawable.transparent));
        binding.folderfeedList.setOnCreateContextMenuListener(this);
        binding.folderfeedList.setOnChildClickListener(this);
        binding.folderfeedList.setOnGroupClickListener(this);
        binding.folderfeedList.setOnGroupCollapseListener(this);
        binding.folderfeedList.setOnGroupExpandListener(this);

        adapter.listBackref = new WeakReference(binding.folderfeedList); // see note in adapter about backref
        binding.folderfeedList.setAdapter(adapter);

        // Main activity needs to listen for scrolls to prevent refresh from firing unnecessarily
        binding.folderfeedList.setOnScrollListener((android.widget.AbsListView.OnScrollListener) getActivity());

        return v;
    }

    /**
     * Check the open/closed status of folders against what we have stored in the prefs
     * database.  The list widget likes to default all folders to closed, so open them up
     * unless expressly collapsed at some point.
     */
	public void checkOpenFolderPreferences() {
        // make sure we didn't beat construction
        if ((this.binding.folderfeedList == null) || (this.sharedPreferences == null)) return;

		for (int i = 0; i < adapter.getGroupCount(); i++) {
			String flatGroupName = adapter.getGroupUniqueName(i);
			if (sharedPreferences.getBoolean(AppConstants.FOLDER_PRE + "_" + flatGroupName, true)) {
				if (binding.folderfeedList.isGroupExpanded(i) == false) {
                    binding.folderfeedList.expandGroup(i);
                    adapter.setFolderClosed(flatGroupName, false);
                }
			} else {
				if (binding.folderfeedList.isGroupExpanded(i) == true) {
                    binding.folderfeedList.collapseGroup(i);
                    adapter.setFolderClosed(flatGroupName, true);
                }
			}
		}
	}

	@Override
	public void onCreateContextMenu(ContextMenu menu, View v, ContextMenuInfo menuInfo) {
		MenuInflater inflater = getActivity().getMenuInflater();
		ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) menuInfo;
		int type = ExpandableListView.getPackedPositionType(info.packedPosition);
        int childPosition = ExpandableListView.getPackedPositionChild(info.packedPosition);
        int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);

		switch(type) {
		case ExpandableListView.PACKED_POSITION_TYPE_GROUP:
            if (adapter.isRowSavedStories(groupPosition)) break;
            if (currentState == StateFilter.SAVED) break;
            if (adapter.isRowReadStories(groupPosition)) break;
            if (adapter.isRowGlobalSharedStories(groupPosition)) break;
            if (adapter.isRowAllSharedStories(groupPosition)) break;
            if (adapter.isRowInfrequentStories(groupPosition)) break;
            if (adapter.isRowSavedSearches(groupPosition)) break;
            inflater.inflate(R.menu.context_folder, menu);

            if (adapter.isRowAllStories(groupPosition)) {
                menu.removeItem(R.id.menu_mute_folder);
                menu.removeItem(R.id.menu_unmute_folder);
            }

			break;

		case ExpandableListView.PACKED_POSITION_TYPE_CHILD: 
            if (adapter.isRowSavedStories(groupPosition)) break;
            if (currentState == StateFilter.SAVED) break;
			inflater.inflate(R.menu.context_feed, menu);
            if (adapter.isRowAllSharedStories(groupPosition)) {
                // social feeds
                menu.removeItem(R.id.menu_delete_feed);
                menu.removeItem(R.id.menu_choose_folders);
                menu.removeItem(R.id.menu_unmute_feed);
                menu.removeItem(R.id.menu_mute_feed);
                menu.removeItem(R.id.menu_notifications);
                menu.removeItem(R.id.menu_instafetch_feed);
                menu.removeItem(R.id.menu_intel);
                menu.removeItem(R.id.menu_rename_feed);
                menu.removeItem(R.id.menu_delete_saved_search);
            } else if (adapter.isRowSavedSearches(groupPosition)) {
                menu.removeItem(R.id.menu_mark_feed_as_read);
                menu.removeItem(R.id.menu_delete_feed);
                menu.removeItem(R.id.menu_unfollow);
                menu.removeItem(R.id.menu_choose_folders);
                menu.removeItem(R.id.menu_rename_feed);
                menu.removeItem(R.id.menu_notifications);
                menu.removeItem(R.id.menu_mute_feed);
                menu.removeItem(R.id.menu_unmute_feed);
                menu.removeItem(R.id.menu_instafetch_feed);
                menu.removeItem(R.id.menu_intel);
            } else {
                // normal feeds
                menu.removeItem(R.id.menu_unfollow);
                menu.removeItem(R.id.menu_delete_saved_search);

                Feed feed = adapter.getFeed(groupPosition, childPosition);
                if (feed.active) {
                    menu.removeItem(R.id.menu_unmute_feed);
                } else {
                    menu.removeItem(R.id.menu_mute_feed);
                    menu.removeItem(R.id.menu_mark_feed_as_read);
                    menu.removeItem(R.id.menu_notifications);
                    menu.removeItem(R.id.menu_instafetch_feed);
                    menu.removeItem(R.id.menu_intel);
                    break;
                }
                if (feed.isNotifyUnread()) {
                    menu.findItem(R.id.menu_notifications_disable).setChecked(false);
                    menu.findItem(R.id.menu_notifications_unread).setChecked(true);
                    menu.findItem(R.id.menu_notifications_focus).setChecked(false);
                } else if (feed.isNotifyFocus()) {
                    menu.findItem(R.id.menu_notifications_disable).setChecked(false);
                    menu.findItem(R.id.menu_notifications_unread).setChecked(false);
                    menu.findItem(R.id.menu_notifications_focus).setChecked(true);
                } else {
                    menu.findItem(R.id.menu_notifications_disable).setChecked(true);
                    menu.findItem(R.id.menu_notifications_unread).setChecked(false);
                    menu.findItem(R.id.menu_notifications_focus).setChecked(false);
                }
            }
			break;
		}
	}

    @Override
	public boolean onContextItemSelected(MenuItem item) {
        if (item.getItemId() == R.id.menu_notifications) {
            // this means the notifications menu has been opened, but this is our one chance to see the list position
            // and get the ID of the feed for which the menu was opened. (no packed pos when the submenu is tapped)
            ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) item.getMenuInfo();
            int childPosition = ExpandableListView.getPackedPositionChild(info.packedPosition);
            int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);
            lastMenuFeed = adapter.getFeed(groupPosition, childPosition);
            return true;
        }
        if (item.getItemId() == R.id.menu_notifications_disable) {
            FeedUtils.disableNotifications(getActivity(), lastMenuFeed);
            return true;
        }
        if (item.getItemId() == R.id.menu_notifications_focus) {
            FeedUtils.enableFocusNotifications(getActivity(), lastMenuFeed);
            return true;
        }
        if (item.getItemId() == R.id.menu_notifications_unread) {
            FeedUtils.enableUnreadNotifications(getActivity(), lastMenuFeed);
            return true;
        }
		ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) item.getMenuInfo();
        int childPosition = ExpandableListView.getPackedPositionChild(info.packedPosition);
        int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);

		if (item.getItemId() == R.id.menu_delete_feed || item.getItemId() == R.id.menu_unfollow) {
			DialogFragment deleteFeedFragment;
            if (adapter.isRowAllSharedStories(groupPosition)) {
                deleteFeedFragment = DeleteFeedFragment.newInstance(adapter.getSocialFeed(groupPosition, childPosition));
            } else {
                String folderName = adapter.getGroupFolderName(groupPosition);
                deleteFeedFragment = DeleteFeedFragment.newInstance(adapter.getFeed(groupPosition, childPosition), folderName);
            }
			deleteFeedFragment.show(getFragmentManager(), "dialog");
			return true;
		} else if (item.getItemId() == R.id.menu_mark_feed_as_read) {
            FeedSet fs = adapter.getChild(groupPosition, childPosition);
            markFeedsAsRead(fs);
			return true;
		} else if (item.getItemId() == R.id.menu_mark_folder_as_read) {
            FeedSet fs = adapter.getGroup(groupPosition);
            markFeedsAsRead(fs);
			return true;
		} else if (item.getItemId() == R.id.menu_choose_folders) {
            Feed feed = adapter.getFeed(groupPosition, childPosition);
            if (feed != null) {
                DialogFragment chooseFoldersFragment = ChooseFoldersFragment.newInstance(feed);
                chooseFoldersFragment.show(getFragmentManager(), "dialog");
            }
        } else if (item.getItemId() == R.id.menu_rename_feed) {
            Feed feed = adapter.getFeed(groupPosition, childPosition);
            if (feed != null) {
                DialogFragment renameFeedFragment = RenameFeedFragment.newInstance(feed);
                renameFeedFragment.show(getFragmentManager(), "dialog");
            }
        } else if (item.getItemId() == R.id.menu_mute_feed) {
            Set<String> feedIds = new HashSet<String>();
            feedIds.add(adapter.getFeed(groupPosition, childPosition).feedId);
            FeedUtils.muteFeeds(getActivity(), feedIds);
        } else if (item.getItemId() == R.id.menu_unmute_feed) {
            Set<String> feedIds = new HashSet<String>();
            feedIds.add(adapter.getFeed(groupPosition, childPosition).feedId);
            FeedUtils.unmuteFeeds(getActivity(), feedIds);
        } else if (item.getItemId() == R.id.menu_mute_folder) {
            FeedUtils.muteFeeds(getActivity(), adapter.getAllFeedsForFolder(groupPosition));
        } else if (item.getItemId() == R.id.menu_unmute_folder) {
            FeedUtils.unmuteFeeds(getActivity(), adapter.getAllFeedsForFolder(groupPosition));
        } else if (item.getItemId() == R.id.menu_instafetch_feed) {
            FeedUtils.instaFetchFeed(getActivity(), adapter.getFeed(groupPosition, childPosition).feedId);
        } else if (item.getItemId() == R.id.menu_intel) {
            FeedIntelTrainerFragment intelFrag = FeedIntelTrainerFragment.newInstance(adapter.getFeed(groupPosition, childPosition), adapter.getChild(groupPosition, childPosition));
            intelFrag.show(getFragmentManager(), FeedIntelTrainerFragment.class.getName());
        } else if (item.getItemId() == R.id.menu_delete_saved_search) {
		    SavedSearch savedSearch = adapter.getSavedSearch(childPosition);
		    if (savedSearch != null) {
                DialogFragment deleteFeedFragment = DeleteFeedFragment.newInstance(savedSearch);
                deleteFeedFragment.show(getFragmentManager(), "dialog");
            }
		}

		return super.onContextItemSelected(item);
	}

    private void markFeedsAsRead(FeedSet fs) {
        FeedUtils.markRead(((NbActivity) getActivity()), fs, null, null, R.array.mark_all_read_options, false);
        adapter.lastFeedViewedId = fs.getSingleFeed();
        adapter.lastFolderViewed = fs.getFolderName();
    }

	public void changeState(StateFilter state) {
		currentState = state;
        PrefsUtils.setStateFilter(getActivity(), state);
        adapter.changeState(state);
		hasUpdated();
	}

    public void clearRecents() {
        adapter.lastFeedViewedId = null;
        adapter.lastFolderViewed = null;
    }

    public void forceShowFeed(String feedId) {
        adapter.lastFeedViewedId = feedId;
        adapter.lastFolderViewed = null;
    }

    public void setSearchQuery(String q) {
        adapter.activeSearchQuery = q;
        adapter.forceRecount();
        checkOpenFolderPreferences();
    }

    public String getSearchQuery() {
        return adapter.activeSearchQuery;
    }

    /**
     * Every time unread counts are updated in the adapter, ping the Main activity with
     * the new data.  It is, unfortunately, quite expensive to compute given the current
     * DB model, so having Main also load it would cause some lag.
     */
    public void pushUnreadCounts() {
        ((Main) getActivity()).updateUnreadCounts((adapter.totalNeutCount+adapter.totalSocialNeutCount), (adapter.totalPosCount+adapter.totalSocialPosiCount));
        ((Main) getActivity()).updateFeedCount(adapter.lastFeedCount);
        com.newsblur.util.Log.d(this, "showing " + adapter.lastFeedCount + " feeds");
    }

	@Override
    public boolean onGroupClick(ExpandableListView list, View group, int groupPosition, long id) {
        Intent i = null;
        if (adapter.isRowAllStories(groupPosition)) {
            if (currentState == StateFilter.SAVED) {
                // the existence of this row in saved mode is something of a framework artifact and may
                // confuse users. redirect them to the activity corresponding to what they will actually see
                i = new Intent(getActivity(), SavedStoriesItemsList.class);
            } else {
			    i = new Intent(getActivity(), AllStoriesItemsList.class);
            }
        } else if (adapter.isRowGlobalSharedStories(groupPosition)) {
            i = new Intent(getActivity(), GlobalSharedStoriesItemsList.class);
        } else if (adapter.isRowAllSharedStories(groupPosition)) {
            i = new Intent(getActivity(), AllSharedStoriesItemsList.class);
        } else if (adapter.isRowInfrequentStories(groupPosition)) {
            i = new Intent(getActivity(), InfrequentItemsList.class);
        } else if (adapter.isRowReadStories(groupPosition)) {
            i = new Intent(getActivity(), ReadStoriesItemsList.class);
        } else if (adapter.isRowSavedStories(groupPosition)) {
            i = new Intent(getActivity(), SavedStoriesItemsList.class);
        } else if (adapter.isRowSavedSearches(groupPosition)) {
            // group not clickable
            return true;
        } else {
            i = new Intent(getActivity(), FolderItemsList.class);
            String canonicalFolderName = adapter.getGroupFolderName(groupPosition);
            i.putExtra(FolderItemsList.EXTRA_FOLDER_NAME, canonicalFolderName);
            adapter.lastFeedViewedId = null;
            adapter.lastFolderViewed = canonicalFolderName;
        }
        FeedSet fs = adapter.getGroup(groupPosition);
        i.putExtra(ItemsList.EXTRA_FEED_SET, fs);
        startActivity(i);

        // by default, ExpandableListViews open/close groups when they are clicked. we want to
        // only do this when the expando is clicked, so we eat all onGroupClick events and
        // set an onClick listeneron the expandos  when creating each group view that will
        // perform the expand/collapse functionality
        return true;
	}

    @Override
    public void onGroupExpand(int groupPosition) {
        // these shouldn't ever be collapsible
        if (adapter.isRowRootFolder(groupPosition)) return;
        if (adapter.isRowReadStories(groupPosition)) return;
        if (adapter.isRowSavedSearches(groupPosition)) return;

        String flatGroupName = adapter.getGroupUniqueName(groupPosition);
        // save the expanded preference, since the widget likes to forget it
        sharedPreferences.edit().putBoolean(AppConstants.FOLDER_PRE + "_" + flatGroupName, true).commit();

        if (adapter.isRowSavedStories(groupPosition)) return;

        // trigger display/hide of sub-folders
        adapter.setFolderClosed(flatGroupName, false);
        // re-check open/closed state of sub folders, since the list will have forgot them
        checkOpenFolderPreferences();
    }

    @Override
    public void onGroupCollapse(int groupPosition) {
        // these shouldn't ever be collapsible
        if (adapter.isRowRootFolder(groupPosition)) return;
        if (adapter.isRowReadStories(groupPosition)) return;
        if (adapter.isRowSavedSearches(groupPosition)) return;

        String flatGroupName = adapter.getGroupUniqueName(groupPosition);
        // save the collapsed preference, since the widget likes to forget it
        sharedPreferences.edit().putBoolean(AppConstants.FOLDER_PRE + "_" + flatGroupName, false).commit();

        if (adapter.isRowSavedStories(groupPosition)) return;

        // trigger display/hide of sub-folders
        adapter.setFolderClosed(flatGroupName, true);
    }

	@Override
    public boolean onChildClick(ExpandableListView list, View childView, int groupPosition, int childPosition, long id) {
        FeedUtils.currentFolderName = null;
        FeedSet fs = adapter.getChild(groupPosition, childPosition);
		if (adapter.isRowAllSharedStories(groupPosition)) {
            SocialFeed socialFeed = adapter.getSocialFeed(groupPosition, childPosition);
			Intent intent = new Intent(getActivity(), SocialFeedItemsList.class);
            intent.putExtra(ItemsList.EXTRA_FEED_SET, fs);
			intent.putExtra(SocialFeedItemsList.EXTRA_SOCIAL_FEED, socialFeed);
			getActivity().startActivity(intent);
        } else if (adapter.isRowSavedStories(groupPosition)) {
            Intent intent = new Intent(getActivity(), SavedStoriesItemsList.class);
            intent.putExtra(ItemsList.EXTRA_FEED_SET, fs);
			getActivity().startActivity(intent);
		} else if (adapter.isRowSavedSearches(groupPosition)) {
		    openSavedSearch(adapter.getSavedSearch(childPosition));
        } else {
            Feed feed = adapter.getFeed(groupPosition, childPosition);
            // NB: FeedItemsList needs the name of the containing folder, but this is not the same as setting
            // a folder name on the FeedSet and making it into a folder-type set.  it is just a single feed,
            // and the folder name is a bit of metadata needed by the UI/API
			String folderName = adapter.getGroupFolderName(groupPosition);
			if(folderName == null || folderName.equals(AppConstants.ROOT_FOLDER)){
                FeedUtils.currentFolderName = null;
            }else{

                FeedUtils.currentFolderName = folderName;
            }
			FeedItemsList.startActivity(getActivity(), fs, feed, folderName);
            adapter.lastFeedViewedId = feed.feedId;
            adapter.lastFolderViewed = null;
		}
		return true;
	}

    private void openSavedSearch(SavedSearch savedSearch) {
        Intent intent = null;
        FeedSet fs = null;
        String feedId = savedSearch.feedId;
        if (feedId.equals("river:")) {
            // all site stories
            intent = new Intent(getActivity(), AllStoriesItemsList.class);
            fs = FeedSet.allFeeds();
        } else if (feedId.equals("river:infrequent")) {
            // infrequent stories
            intent = new Intent(getActivity(), InfrequentItemsList.class);
            fs = FeedSet.infrequentFeeds();
        } else if (feedId.startsWith("river:")) {
            intent = new Intent(getActivity(), FolderItemsList.class);
            String folderName = feedId.replace("river:", "");
            fs = FeedUtils.feedSetFromFolderName(folderName);
            intent.putExtra(FolderItemsList.EXTRA_FOLDER_NAME, folderName);
        } else if (feedId.equals("read")) {
            intent = new Intent(getActivity(), ReadStoriesItemsList.class);
            fs = FeedSet.allRead();
        } else if (feedId.equals("starred")) {
            intent = new Intent(getActivity(), SavedStoriesItemsList.class);
            fs = FeedSet.allSaved();
        } else if (feedId.startsWith("starred:")) {
            intent = new Intent(getActivity(), SavedStoriesItemsList.class);
            fs = FeedSet.singleSavedTag(feedId.replace("starred:", ""));
        } else if (feedId.startsWith("feed:")) {
            intent = new Intent(getActivity(), FeedItemsList.class);
            String cleanFeedId = feedId.replace("feed:", "");
            Feed feed = FeedUtils.getFeed(cleanFeedId);
            fs = FeedSet.singleFeed(cleanFeedId);
            intent.putExtra(FeedItemsList.EXTRA_FEED, feed);
        } else if (feedId.startsWith("social:")) {
            intent = new Intent(getActivity(), SocialFeedItemsList.class);
            String cleanFeedId = feedId.replace("social:", "");
            fs = FeedSet.singleFeed(cleanFeedId);
            Feed feed = FeedUtils.getFeed(cleanFeedId);
            intent.putExtra(FeedItemsList.EXTRA_FEED, feed);
        }

        if (intent != null) {
            fs.setSearchQuery(savedSearch.query);
            intent.putExtra(ItemsList.EXTRA_FEED_SET, fs);
            startActivity(intent);
        }
    }

    public void setTextSize(Float size) {
        if (adapter != null) {
            adapter.setTextSize(size);
            adapter.notifyDataSetChanged();
        }

    }

}
