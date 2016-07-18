package com.newsblur.fragment;

import java.lang.ref.WeakReference;

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

import butterknife.ButterKnife;
import butterknife.Bind;

import com.newsblur.R;
import com.newsblur.activity.AllSharedStoriesItemsList;
import com.newsblur.activity.AllStoriesItemsList;
import com.newsblur.activity.FeedItemsList;
import com.newsblur.activity.FolderItemsList;
import com.newsblur.activity.GlobalSharedStoriesItemsList;
import com.newsblur.activity.ItemsList;
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
                                                              LoaderManager.LoaderCallbacks<Cursor>,
                                                              OnChildClickListener, 
                                                              OnGroupClickListener,
                                                              OnGroupCollapseListener,
                                                              OnGroupExpandListener {

    private static final int SOCIALFEEDS_LOADER = 1;
    private static final int FOLDERS_LOADER = 2;
    private static final int FEEDS_LOADER = 3;
    private static final int SAVEDCOUNT_LOADER = 4;

	private FolderListAdapter adapter;
	public StateFilter currentState = StateFilter.SOME;
	private SharedPreferences sharedPreferences;
    @Bind(R.id.folderfeed_list) ExpandableListView list;
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
                return FeedUtils.dbHelper.getSocialFeedsLoader(currentState);
            case FOLDERS_LOADER:
                return FeedUtils.dbHelper.getFoldersLoader();
            case FEEDS_LOADER:
                return FeedUtils.dbHelper.getFeedsLoader(currentState);
            case SAVEDCOUNT_LOADER:
                return FeedUtils.dbHelper.getSavedStoryCountsLoader();
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

        list.setGroupIndicator(UIUtils.getDrawable(getActivity(), R.drawable.transparent));
        list.setOnCreateContextMenuListener(this);
        list.setOnChildClickListener(this);
        list.setOnGroupClickListener(this);
        list.setOnGroupCollapseListener(this);
        list.setOnGroupExpandListener(this);

        adapter.listBackref = new WeakReference(list); // see note in adapter about backref
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
				if (list.isGroupExpanded(i) == false) {
                    list.expandGroup(i);
                    adapter.setFolderClosed(flatGroupName, false);
                }
			} else {
				if (list.isGroupExpanded(i) == true) {
                    list.collapseGroup(i);
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
            if (adapter.isRowSavedStories(groupPosition)) break;
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
            DialogFragment chooseFoldersFragment = ChooseFoldersFragment.newInstance(adapter.getFeed(groupPosition, childPosition));
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

	@Override
    public boolean onGroupClick(ExpandableListView list, View group, int groupPosition, long id) {
        Intent i = null;
        if (adapter.isFolderRoot(groupPosition)) {
			i = new Intent(getActivity(), AllStoriesItemsList.class);
        } else if (groupPosition == FolderListAdapter.GLOBAL_SHARED_STORIES_GROUP_POSITION) {
            i = new Intent(getActivity(), GlobalSharedStoriesItemsList.class);
        } else if (groupPosition == FolderListAdapter.ALL_SHARED_STORIES_GROUP_POSITION) {
            i = new Intent(getActivity(), AllSharedStoriesItemsList.class);
        } else if (adapter.isRowReadStories(groupPosition)) {
            i = new Intent(getActivity(), ReadStoriesItemsList.class);
        } else if (adapter.isRowSavedStories(groupPosition)) {
            i = new Intent(getActivity(), SavedStoriesItemsList.class);
        } else {
            i = new Intent(getActivity(), FolderItemsList.class);
            String canonicalFolderName = adapter.getGroupFolderName(groupPosition);
            i.putExtra(FolderItemsList.EXTRA_FOLDER_NAME, canonicalFolderName);
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
        if (adapter.isFolderRoot(groupPosition)) return;
        if (adapter.isRowReadStories(groupPosition)) return;

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
        if (adapter.isFolderRoot(groupPosition)) return;
        if (adapter.isRowReadStories(groupPosition)) return;

        String flatGroupName = adapter.getGroupUniqueName(groupPosition);
        // save the collapsed preference, since the widget likes to forget it
        sharedPreferences.edit().putBoolean(AppConstants.FOLDER_PRE + "_" + flatGroupName, false).commit();

        if (adapter.isRowSavedStories(groupPosition)) return;

        // trigger display/hide of sub-folders
        adapter.setFolderClosed(flatGroupName, true);
    }

	@Override
    public boolean onChildClick(ExpandableListView list, View childView, int groupPosition, int childPosition, long id) {
        FeedSet fs = adapter.getChild(groupPosition, childPosition);
		if (groupPosition == FolderListAdapter.ALL_SHARED_STORIES_GROUP_POSITION) {
            SocialFeed socialFeed = adapter.getSocialFeed(groupPosition, childPosition);
			Intent intent = new Intent(getActivity(), SocialFeedItemsList.class);
            intent.putExtra(ItemsList.EXTRA_FEED_SET, fs);
			intent.putExtra(SocialFeedItemsList.EXTRA_SOCIAL_FEED, socialFeed);
			getActivity().startActivity(intent);
        } else if (adapter.isRowSavedStories(groupPosition)) {
            Intent intent = new Intent(getActivity(), SavedStoriesItemsList.class);
            intent.putExtra(ItemsList.EXTRA_FEED_SET, fs);
			getActivity().startActivity(intent);
		} else {
            Feed feed = adapter.getFeed(groupPosition, childPosition);
            // NB: FeedItemsList needs the name of the containing folder, but this is not the same as setting
            // a folder name on the FeedSet and making it into a folder-type set.  it is just a single feed,
            // and the folder name is a bit of metadata needed by the UI/API
			String folderName = adapter.getGroupFolderName(groupPosition);
			Intent intent = new Intent(getActivity(), FeedItemsList.class);
            intent.putExtra(ItemsList.EXTRA_FEED_SET, fs);
			intent.putExtra(FeedItemsList.EXTRA_FEED, feed);
			intent.putExtra(FeedItemsList.EXTRA_FOLDER_NAME, folderName);
			getActivity().startActivity(intent);
		}
		return true;
	}

    public void setTextSize(Float size) {
        if (adapter != null) {
            adapter.setTextSize(size);
            adapter.notifyDataSetChanged();
        }

    }

}
