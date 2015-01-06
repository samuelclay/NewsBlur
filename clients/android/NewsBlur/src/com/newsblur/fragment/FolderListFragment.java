package com.newsblur.fragment;

import android.app.LoaderManager;
import android.content.Loader;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.os.Bundle;
import android.app.DialogFragment;
import android.app.Fragment;
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
import android.widget.ExpandableListView.OnChildClickListener;
import android.widget.ExpandableListView.OnGroupClickListener;

import com.newsblur.R;
import com.newsblur.activity.AllStoriesItemsList;
import com.newsblur.activity.FeedItemsList;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.SavedStoriesItemsList;
import com.newsblur.activity.SocialFeedItemsList;
import com.newsblur.database.DatabaseConstants;
import static com.newsblur.database.DatabaseConstants.getStr;
import com.newsblur.database.FolderListAdapter;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StateFilter;
import com.newsblur.util.UIUtils;

public class FolderListFragment extends NbFragment implements OnGroupClickListener, OnChildClickListener, OnCreateContextMenuListener, LoaderManager.LoaderCallbacks<Cursor> {

    private static final int SOCIALFEEDS_LOADER = 1;
    private static final int FOLDERFEEDMAP_LOADER = 2;
    private static final int FEEDS_LOADER = 3;
    private static final int SAVEDCOUNT_LOADER = 4;

	private FolderListAdapter adapter;
	public StateFilter currentState = StateFilter.SOME;
	private SharedPreferences sharedPreferences;
    private ExpandableListView list;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
        currentState = PrefsUtils.getStateFilter(getActivity());
		adapter = new FolderListAdapter(getActivity(), currentState);
	}

    @Override
    public synchronized void onActivityCreated(Bundle savedInstanceState) {
        super.onActivityCreated(savedInstanceState);
		sharedPreferences = getActivity().getSharedPreferences(PrefConstants.PREFERENCES, 0);
        if (getLoaderManager().getLoader(FOLDERFEEDMAP_LOADER) == null) {
            getLoaderManager().initLoader(SOCIALFEEDS_LOADER, null, this);
            getLoaderManager().initLoader(FOLDERFEEDMAP_LOADER, null, this);
            getLoaderManager().initLoader(FEEDS_LOADER, null, this);
            getLoaderManager().initLoader(SAVEDCOUNT_LOADER, null, this);
        }
    }

	@Override
	public Loader<Cursor> onCreateLoader(int id, Bundle args) {
        switch (id) {
            case SOCIALFEEDS_LOADER:
                return FeedUtils.dbHelper.getSocialFeedsLoader(currentState);
            case FOLDERFEEDMAP_LOADER:
                return FeedUtils.dbHelper.getFolderFeedMapLoader();
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
                case FOLDERFEEDMAP_LOADER:
                    adapter.setFolderFeedMapCursor(cursor);
                    break;
                case FEEDS_LOADER:
                    adapter.setFeedCursor(cursor);
                    break;
                case SAVEDCOUNT_LOADER:
                    adapter.setSavedCountCursor(cursor);
                    break;
                default:
                    throw new IllegalArgumentException("unknown loader created");
            }
            checkOpenFolderPreferences();
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
		    getLoaderManager().restartLoader(SOCIALFEEDS_LOADER, null, this);
		    getLoaderManager().restartLoader(FOLDERFEEDMAP_LOADER, null, this);
		    getLoaderManager().restartLoader(FEEDS_LOADER, null, this);
		    getLoaderManager().restartLoader(SAVEDCOUNT_LOADER, null, this);
        }
	}

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View v = inflater.inflate(R.layout.fragment_folderfeedlist, container);
        list = (ExpandableListView) v.findViewById(R.id.folderfeed_list);
        list.setGroupIndicator(getResources().getDrawable(R.drawable.transparent));
        list.setOnCreateContextMenuListener(this);

        Display display = getActivity().getWindowManager().getDefaultDisplay();
        list.setIndicatorBounds(
                display.getWidth() - UIUtils.convertDPsToPixels(getActivity(), 20),
                display.getWidth() - UIUtils.convertDPsToPixels(getActivity(), 10));

        list.setChildDivider(getActivity().getResources().getDrawable(R.drawable.divider_light));
        list.setAdapter(adapter);
        list.setOnGroupClickListener(this);
        list.setOnChildClickListener(this);

        // Main activity needs to listen for scrolls to prevent refresh from firing unnecessarily
        list.setOnScrollListener((android.widget.AbsListView.OnScrollListener) getActivity());

        return v;
    }

	public void checkOpenFolderPreferences() {
        // make sure we didn't beat construction
        if ((this.list == null) || (this.sharedPreferences == null)) return;

		for (int i = 0; i < adapter.getGroupCount(); i++) {
			String groupName = adapter.getGroupName(i);
			if (sharedPreferences.getBoolean(AppConstants.FOLDER_PRE + "_" + groupName, true)) {
				this.list.expandGroup(i);
			} else {
				this.list.collapseGroup(i);
			}
		}
	}

	@Override
	public void onCreateContextMenu(ContextMenu menu, View v, ContextMenuInfo menuInfo) {
		MenuInflater inflater = getActivity().getMenuInflater();
		ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) menuInfo;
		int type = ExpandableListView.getPackedPositionType(info.packedPosition);

		switch(type) {
		case ExpandableListView.PACKED_POSITION_TYPE_GROUP:
            int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);
            if (! adapter.isRowSavedStories(groupPosition) ) {
			    inflater.inflate(R.menu.context_folder, menu);
            }
			break;

		case ExpandableListView.PACKED_POSITION_TYPE_CHILD: 
			inflater.inflate(R.menu.context_feed, menu);
			break;
		}
	}

	@Override
	public boolean onContextItemSelected(MenuItem item) {
		ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) item.getMenuInfo();
        int childPosition = ExpandableListView.getPackedPositionChild(info.packedPosition);
        int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);

		if (item.getItemId() == R.id.menu_delete_feed) {
			String folderName = adapter.getGroup(groupPosition);
			DialogFragment deleteFeedFragment;
            if (groupPosition == 0) {
                deleteFeedFragment = DeleteFeedFragment.newInstance(adapter.getSocialFeed(adapter.getChild(groupPosition, childPosition)), folderName);
            } else {
                deleteFeedFragment = DeleteFeedFragment.newInstance(adapter.getFeed(adapter.getChild(groupPosition, childPosition)), folderName);
            }
			deleteFeedFragment.show(getFragmentManager(), "dialog");
			return true;
		} else if (item.getItemId() == R.id.menu_mark_feed_as_read) {
            String feedId = adapter.getChild(groupPosition, childPosition);
            if (groupPosition == 0) {
                SocialFeed socialFeed = adapter.getSocialFeed(feedId);
                FeedUtils.markFeedsRead(FeedSet.singleSocialFeed(socialFeed.userId, socialFeed.username), null, null, getActivity());
            } else {
                FeedUtils.markFeedsRead(FeedSet.singleFeed(feedId), null, null, getActivity());
            }
			return true;
		} else if (item.getItemId() == R.id.menu_mark_folder_as_read) {
			if (!adapter.isFolderRoot(groupPosition)) {
				String folderName = adapter.getGroup(groupPosition);
                FeedUtils.markFeedsRead(FeedUtils.feedSetFromFolderName(folderName, getActivity()), null, null, getActivity());
			} else {
                FeedUtils.markFeedsRead(FeedSet.allFeeds(), null, null, getActivity());
			}
			return true;
		}

		return super.onContextItemSelected(item);
	}

	public void changeState(StateFilter state) {
		currentState = state;
        PrefsUtils.setStateFilter(getActivity(), state);
        adapter.changeState(state);
		hasUpdated();
	}

	@Override
	public boolean onGroupClick(ExpandableListView list, View group, int groupPosition, long id) {
        if (adapter.isFolderRoot(groupPosition)) {
			Intent i = new Intent(getActivity(), AllStoriesItemsList.class);
			i.putExtra(ItemsList.EXTRA_STATE, currentState);
			startActivity(i);
			return true;
        } else if (adapter.isRowSavedStories(groupPosition)) {
            Intent i = new Intent(getActivity(), SavedStoriesItemsList.class);
            startActivity(i);
            return true;
        } else {
            if ((group != null) && (group.findViewById(R.id.row_foldersums) != null)) {
                String groupName = adapter.getGroupName(groupPosition);
                if (list.isGroupExpanded(groupPosition)) {
                    group.findViewById(R.id.row_foldersums).setVisibility(View.VISIBLE);
                    sharedPreferences.edit().putBoolean(AppConstants.FOLDER_PRE + "_" + groupName, false).commit();
                } else {
                    group.findViewById(R.id.row_foldersums).setVisibility(View.INVISIBLE);
                    sharedPreferences.edit().putBoolean(AppConstants.FOLDER_PRE + "_" + groupName, true).commit();
                }
            }
			return false;
		}
	}

	@Override
	public boolean onChildClick(ExpandableListView list, View childView, int groupPosition, int childPosition, long id) {
        String childName = adapter.getChild(groupPosition, childPosition);
		if (groupPosition == 0) {
            SocialFeed socialFeed = adapter.getSocialFeed(childName);
			Intent intent = new Intent(getActivity(), SocialFeedItemsList.class);
			intent.putExtra(SocialFeedItemsList.EXTRA_SOCIAL_FEED, socialFeed);
			intent.putExtra(ItemsList.EXTRA_STATE, currentState);
			getActivity().startActivity(intent);
		} else {
            Feed feed = adapter.getFeed(childName);
			String folderName = adapter.getGroup(groupPosition);
			Intent intent = new Intent(getActivity(), FeedItemsList.class);
			intent.putExtra(FeedItemsList.EXTRA_FEED, feed);
			intent.putExtra(FeedItemsList.EXTRA_FOLDER_NAME, folderName);
			intent.putExtra(ItemsList.EXTRA_STATE, currentState);
			getActivity().startActivity(intent);
		}
		return true;
	}

}
