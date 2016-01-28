package com.newsblur.fragment;

import android.app.LoaderManager;
import android.content.Loader;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.os.Bundle;
import android.app.DialogFragment;
import android.util.Log;
import android.view.ContextMenu;
import android.view.ContextMenu.ContextMenuInfo;
import android.view.Display;
import android.view.LayoutInflater;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnCreateContextMenuListener;
import android.view.ViewGroup;
import android.widget.ExpandableListView;

import butterknife.ButterKnife;
import butterknife.FindView;
import butterknife.OnChildClick;
import butterknife.OnGroupClick;
import butterknife.OnGroupCollapse;
import butterknife.OnGroupExpand;

import com.newsblur.R;
import com.newsblur.activity.AllStoriesItemsList;
import com.newsblur.activity.FeedItemsList;
import com.newsblur.activity.Main;
import com.newsblur.activity.ReadStoriesItemsList;
import com.newsblur.activity.SavedStoriesItemsList;
import com.newsblur.activity.SocialFeedItemsList;
import com.newsblur.database.FolderListAdapter;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.MarkAllReadConfirmation;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StateFilter;
import com.newsblur.util.UIUtils;

public class FolderListFragment extends NbFragment implements OnCreateContextMenuListener, 
                                                              LoaderManager.LoaderCallbacks<Cursor> {

    private static final int SOCIALFEEDS_LOADER = 1;
    private static final int FOLDERS_LOADER = 2;
    private static final int FEEDS_LOADER = 3;
    private static final int SAVEDCOUNT_LOADER = 4;

	private FolderListAdapter adapter;
	public StateFilter currentState = StateFilter.SOME;
	private SharedPreferences sharedPreferences;
    @FindView(R.id.folderfeed_list) ExpandableListView list;
    public boolean firstCursorSeenYet = false;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
        currentState = PrefsUtils.getStateFilter(getActivity());
		adapter = new FolderListAdapter(getActivity(), currentState);
        // NB: it is by design that loaders are not started until we get a
        // ping from the sync service indicating that it has initialised
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
                return FeedUtils.dbHelper.getSocialFeedsLoader(currentState);
            case FOLDERS_LOADER:
                return FeedUtils.dbHelper.getFoldersLoader();
            case FEEDS_LOADER:
                return FeedUtils.dbHelper.getFeedsLoader(currentState);
            case SAVEDCOUNT_LOADER:
                return FeedUtils.dbHelper.getSavedStoryCountLoader();
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
                    break;
                case FOLDERS_LOADER:
                    adapter.setFoldersCursor(cursor);
                    break;
                case FEEDS_LOADER:
                    adapter.setFeedCursor(cursor);
                    firstCursorSeenYet = true;
                    break;
                case SAVEDCOUNT_LOADER:
                    adapter.setSavedCountCursor(cursor);
                    break;
                default:
                    throw new IllegalArgumentException("unknown loader created");
            }
            checkOpenFolderPreferences();
            pushUnreadCounts();
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
            try {
                getLoaderManager().restartLoader(SOCIALFEEDS_LOADER, null, this);
                getLoaderManager().restartLoader(FOLDERS_LOADER, null, this);
                getLoaderManager().restartLoader(FEEDS_LOADER, null, this);
                getLoaderManager().restartLoader(SAVEDCOUNT_LOADER, null, this);
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
            }
        }
    }

    public void reset() {
        if (adapter != null) adapter.reset();
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View v = inflater.inflate(R.layout.fragment_folderfeedlist, container);
        ButterKnife.bind(this, v);

        list.setGroupIndicator(getResources().getDrawable(R.drawable.transparent));
        list.setOnCreateContextMenuListener(this);

        Display display = getActivity().getWindowManager().getDefaultDisplay();
        list.setIndicatorBounds(
                display.getWidth() - UIUtils.dp2px(getActivity(), 20),
                display.getWidth() - UIUtils.dp2px(getActivity(), 10));

        list.setChildDivider(getActivity().getResources().getDrawable(R.drawable.divider_light));
        list.setAdapter(adapter);

        // Main activity needs to listen for scrolls to prevent refresh from firing unnecessarily
        list.setOnScrollListener((android.widget.AbsListView.OnScrollListener) getActivity());

        return v;
    }

    /**
     * Check the open/closed status of folders against what we have stored in the prefs
     * database.  The list widget likes to default all folders to closed, so open them up
     * unless expressly collapsed at some point.
     */
	public void checkOpenFolderPreferences() {
        // make sure we didn't beat construction
        if ((this.list == null) || (this.sharedPreferences == null)) return;

		for (int i = 0; i < adapter.getGroupCount(); i++) {
			String flatGroupName = adapter.getGroupUniqueName(i);
			if (sharedPreferences.getBoolean(AppConstants.FOLDER_PRE + "_" + flatGroupName, true)) {
				if (list.isGroupExpanded(i) == false) list.expandGroup(i);
                adapter.setFolderClosed(flatGroupName, false);
			} else {
				if (list.isGroupExpanded(i) == true) list.collapseGroup(i);
                adapter.setFolderClosed(flatGroupName, true);
			}
		}
        // we might have just initialised the closed set of folders in the adapter
        adapter.forceRecount();
	}

	@Override
	public void onCreateContextMenu(ContextMenu menu, View v, ContextMenuInfo menuInfo) {
		MenuInflater inflater = getActivity().getMenuInflater();
		ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) menuInfo;
		int type = ExpandableListView.getPackedPositionType(info.packedPosition);
        int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);

		switch(type) {
		case ExpandableListView.PACKED_POSITION_TYPE_GROUP:
            if (adapter.isRowSavedStories(groupPosition)) break;
            if (adapter.isRowReadStories(groupPosition)) break;
            if (groupPosition == FolderListAdapter.GLOBAL_SHARED_STORIES_GROUP_POSITION) break;
            if (groupPosition == FolderListAdapter.ALL_SHARED_STORIES_GROUP_POSITION) break;
            inflater.inflate(R.menu.context_folder, menu);
			break;

		case ExpandableListView.PACKED_POSITION_TYPE_CHILD: 
			inflater.inflate(R.menu.context_feed, menu);
            if (groupPosition == FolderListAdapter.ALL_SHARED_STORIES_GROUP_POSITION) {
                menu.removeItem(R.id.menu_delete_feed);
                menu.removeItem(R.id.menu_choose_folders);
            } else {
                menu.removeItem(R.id.menu_unfollow);
            }
			break;
		}
	}

    @Override
	public boolean onContextItemSelected(MenuItem item) {
		ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) item.getMenuInfo();
        int childPosition = ExpandableListView.getPackedPositionChild(info.packedPosition);
        int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);

		if (item.getItemId() == R.id.menu_delete_feed || item.getItemId() == R.id.menu_unfollow) {
			DialogFragment deleteFeedFragment;
            if (groupPosition == FolderListAdapter.ALL_SHARED_STORIES_GROUP_POSITION) {
                deleteFeedFragment = DeleteFeedFragment.newInstance(adapter.getSocialFeed(adapter.getChild(groupPosition, childPosition)));
            } else {
                String folderName = adapter.getGroup(groupPosition);
                deleteFeedFragment = DeleteFeedFragment.newInstance(adapter.getFeed(adapter.getChild(groupPosition, childPosition)), folderName);
            }
			deleteFeedFragment.show(getFragmentManager(), "dialog");
			return true;
		} else if (item.getItemId() == R.id.menu_mark_feed_as_read) {
            String feedId = adapter.getChild(groupPosition, childPosition);
            FeedSet fs = null;
            if (groupPosition == FolderListAdapter.ALL_SHARED_STORIES_GROUP_POSITION) {
                SocialFeed socialFeed = adapter.getSocialFeed(feedId);
                fs = FeedSet.singleSocialFeed(socialFeed.userId, socialFeed.username);
            } else {
                fs = FeedSet.singleFeed(feedId);
            }

            markFeedsAsRead(fs);
			return true;
		} else if (item.getItemId() == R.id.menu_mark_folder_as_read) {
            FeedSet fs = null;
            if (!adapter.isFolderRoot(groupPosition)) {
				String folderName = adapter.getGroup(groupPosition);
                fs = FeedUtils.feedSetFromFolderName(folderName);
			} else {
                fs = FeedSet.allFeeds();
			}
            markFeedsAsRead(fs);
			return true;
		} else if (item.getItemId() == R.id.menu_choose_folders) {
            DialogFragment chooseFoldersFragment = ChooseFoldersFragment.newInstance(adapter.getFeed(adapter.getChild(groupPosition, childPosition)));
            chooseFoldersFragment.show(getFragmentManager(), "dialog");
        }

		return super.onContextItemSelected(item);
	}

    private void markFeedsAsRead(FeedSet fs) {
        MarkAllReadConfirmation confirmation = PrefsUtils.getMarkAllReadConfirmation(getActivity());
        if (confirmation.feedSetRequiresConfirmation(fs)) {
            MarkAllReadDialogFragment dialog = MarkAllReadDialogFragment.newInstance(fs);
            dialog.show(getFragmentManager(), "dialog");
        } else {
            FeedUtils.markFeedsRead(fs, null, null, getActivity());
        }
    }

	public void changeState(StateFilter state) {
		currentState = state;
        PrefsUtils.setStateFilter(getActivity(), state);
        adapter.changeState(state);
		hasUpdated();
	}

    /**
     * Every time unread counts are updated in the adapter, ping the Main activity with
     * the new data.  It is, unfortunately, quite expensive to compute given the current
     * DB model, so having Main also load it would cause some lag.
     */
    public void pushUnreadCounts() {
        ((Main) getActivity()).updateUnreadCounts((adapter.totalNeutCount+adapter.totalSocialNeutCount), (adapter.totalPosCount+adapter.totalSocialPosiCount));
    }

	@OnGroupClick(R.id.folderfeed_list) boolean onGroupClick(ExpandableListView list, View group, int groupPosition, long id) {
        if (adapter.isFolderRoot(groupPosition)) {
			Intent i = new Intent(getActivity(), AllStoriesItemsList.class);
			startActivity(i);
			return true;
        } else if (adapter.isRowReadStories(groupPosition)) {
            Intent i = new Intent(getActivity(), ReadStoriesItemsList.class);
            startActivity(i);
            return true;
        } else if (adapter.isRowSavedStories(groupPosition)) {
            Intent i = new Intent(getActivity(), SavedStoriesItemsList.class);
            startActivity(i);
            return true;
        } else {
            // the intents started by clicking on folder group names are handled in the Adapter, this
            // just handles clicks on the expandos
            if ((group != null) && (group.findViewById(R.id.row_foldersums) != null)) {
                // the isGroupExpanded() call reflects the state of the group before this click
                if (list.isGroupExpanded(groupPosition)) {
                    group.findViewById(R.id.row_foldersums).setVisibility(View.VISIBLE);
                } else {
                    group.findViewById(R.id.row_foldersums).setVisibility(View.INVISIBLE);
                }
            }
			return false;
		}
	}

    @OnGroupExpand(R.id.folderfeed_list) void onGroupExpand(int groupPosition) {
        // these shouldn't ever be collapsible
        if (adapter.isFolderRoot(groupPosition)) return;
        if (adapter.isRowSavedStories(groupPosition)) return;
        if (adapter.isRowReadStories(groupPosition)) return;

        String flatGroupName = adapter.getGroupUniqueName(groupPosition);
        // save the expanded preference, since the widget likes to forget it
        sharedPreferences.edit().putBoolean(AppConstants.FOLDER_PRE + "_" + flatGroupName, true).commit();
        // trigger display/hide of sub-folders
        adapter.setFolderClosed(flatGroupName, false);
        adapter.forceRecount();
        // re-check open/closed state of sub folders, since the list will have forgot them
        checkOpenFolderPreferences();
    }

    @OnGroupCollapse(R.id.folderfeed_list) void onGroupCollapse(int groupPosition) {
        // these shouldn't ever be collapsible
        if (adapter.isFolderRoot(groupPosition)) return;
        if (adapter.isRowSavedStories(groupPosition)) return;
        if (adapter.isRowReadStories(groupPosition)) return;

        String flatGroupName = adapter.getGroupUniqueName(groupPosition);
        // save the collapsed preference, since the widget likes to forget it
        sharedPreferences.edit().putBoolean(AppConstants.FOLDER_PRE + "_" + flatGroupName, false).commit();
        // trigger display/hide of sub-folders
        adapter.setFolderClosed(flatGroupName, true);
        adapter.forceRecount();
    }

	@OnChildClick(R.id.folderfeed_list) boolean onChildClick(ExpandableListView list, View childView, int groupPosition, int childPosition, long id) {
        String childName = adapter.getChild(groupPosition, childPosition);
		if (groupPosition == FolderListAdapter.ALL_SHARED_STORIES_GROUP_POSITION) {
            SocialFeed socialFeed = adapter.getSocialFeed(childName);
			Intent intent = new Intent(getActivity(), SocialFeedItemsList.class);
			intent.putExtra(SocialFeedItemsList.EXTRA_SOCIAL_FEED, socialFeed);
			getActivity().startActivity(intent);
		} else {
            Feed feed = adapter.getFeed(childName);
			String folderName = adapter.getGroup(groupPosition);
			Intent intent = new Intent(getActivity(), FeedItemsList.class);
			intent.putExtra(FeedItemsList.EXTRA_FEED, feed);
			intent.putExtra(FeedItemsList.EXTRA_FOLDER_NAME, folderName);
			getActivity().startActivity(intent);
		}
		return true;
	}

}
