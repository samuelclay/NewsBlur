package com.newsblur.fragment;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.os.Bundle;
import android.support.v4.app.Fragment;
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
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.AllStoriesItemsList;
import com.newsblur.activity.FeedItemsList;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Main;
import com.newsblur.activity.SocialFeedItemsList;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedExpandableListAdapter;
import com.newsblur.network.APIManager;
import com.newsblur.network.MarkFeedAsReadTask;
import com.newsblur.network.MarkFolderAsReadTask;
import com.newsblur.network.MarkSocialFeedAsReadTask;
import com.newsblur.util.AppConstants;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.UIUtils;
import com.newsblur.view.FolderTreeViewBinder;
import com.newsblur.view.SocialFeedViewBinder;

public class FolderListFragment extends Fragment implements OnGroupClickListener, OnChildClickListener, OnCreateContextMenuListener {

	private ExpandableListView list;
	private ContentResolver resolver;
	private MixedExpandableListAdapter folderAdapter;
	private FolderTreeViewBinder groupViewBinder;
	private int leftBound, rightBound;
	private APIManager apiManager;
	private int currentState = AppConstants.STATE_SOME;
	private int FEEDCHECK = 0x01;
	private SocialFeedViewBinder blogViewBinder;
	private SharedPreferences sharedPreferences;


	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		Cursor folderCursor = resolver.query(FeedProvider.FOLDERS_URI, null, null, new String[] { DatabaseConstants.FOLDER_INTELLIGENCE_SOME }, null);
		Cursor socialFeedCursor = resolver.query(FeedProvider.SOCIAL_FEEDS_URI, null, DatabaseConstants.SOCIAL_INTELLIGENCE_SOME, null, null);
		Cursor countCursor = resolver.query(FeedProvider.FEED_COUNT_URI, null, DatabaseConstants.SOCIAL_INTELLIGENCE_SOME, null, null);
		Cursor sharedCountCursor = resolver.query(FeedProvider.SOCIALCOUNT_URI, null, DatabaseConstants.SOCIAL_INTELLIGENCE_SOME, null, null);

		groupViewBinder = new FolderTreeViewBinder();
		blogViewBinder = new SocialFeedViewBinder(getActivity());

		leftBound = UIUtils.convertDPsToPixels(getActivity(), 20);
		rightBound = UIUtils.convertDPsToPixels(getActivity(), 10);

		final String[] groupFrom = new String[] { DatabaseConstants.FOLDER_NAME, DatabaseConstants.SUM_POS, DatabaseConstants.SUM_NEUT };
		final int[] groupTo = new int[] { R.id.row_foldername, R.id.row_foldersumpos, R.id.row_foldersumneu };
		final String[] childFrom = new String[] { DatabaseConstants.FEED_TITLE, DatabaseConstants.FEED_FAVICON, DatabaseConstants.FEED_NEUTRAL_COUNT, DatabaseConstants.FEED_POSITIVE_COUNT };
		final int[] childTo = new int[] { R.id.row_feedname, R.id.row_feedfavicon, R.id.row_feedneutral, R.id.row_feedpositive };
		final String[] blogFrom = new String[] { DatabaseConstants.SOCIAL_FEED_TITLE, DatabaseConstants.SOCIAL_FEED_ICON, DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT, DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT };
		final int[] blogTo = new int[] { R.id.row_socialfeed_name, R.id.row_socialfeed_icon, R.id.row_socialsumneu, R.id.row_socialsumpos };

		folderAdapter = new MixedExpandableListAdapter(getActivity(), folderCursor, socialFeedCursor, countCursor, sharedCountCursor, R.layout.row_folder_collapsed, R.layout.row_folder_collapsed, R.layout.row_socialfeed, groupFrom, groupTo, R.layout.row_feed, childFrom, childTo, blogFrom, blogTo);
		folderAdapter.setViewBinders(groupViewBinder, blogViewBinder);
	}

	@Override
	public void onAttach(Activity activity) {
		sharedPreferences = activity.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		resolver = activity.getContentResolver();
		apiManager = new APIManager(activity);

		super.onAttach(activity);
	}

	public void hasUpdated() {
		folderAdapter.requery();
		checkOpenFolderPreferences();
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_folderfeedlist, container);
		list = (ExpandableListView) v.findViewById(R.id.folderfeed_list);
		list.setGroupIndicator(getResources().getDrawable(R.drawable.transparent));
		list.setOnCreateContextMenuListener(this);

		Display display = getActivity().getWindowManager().getDefaultDisplay();
		int width = display.getWidth();
		list.setIndicatorBounds(width - leftBound, width - rightBound);

		list.setChildDivider(getActivity().getResources().getDrawable(R.drawable.divider_light));
		list.setAdapter(folderAdapter);
		list.setOnGroupClickListener(this);
		list.setOnChildClickListener(this);

		checkOpenFolderPreferences();

		return v;
	}

	public void checkOpenFolderPreferences() {
		if (sharedPreferences == null) {
			sharedPreferences = getActivity().getSharedPreferences(PrefConstants.PREFERENCES, 0);
		}
		for (int i = 0; i < folderAdapter.getGroupCount(); i++) {
			long groupId = folderAdapter.getGroupId(i);
			if (sharedPreferences.getBoolean(AppConstants.FOLDER_PRE + groupId, true)) {
				list.expandGroup(i);
			} else {
				list.collapseGroup(i);
			}
		}
	}

	@Override
	public void onCreateContextMenu(ContextMenu menu, View v, ContextMenuInfo menuInfo) {
		MenuInflater inflater = getActivity().getMenuInflater();
		ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) menuInfo;
		int type = ExpandableListView.getPackedPositionType(info.packedPosition);

		// Only create a context menu for child items
		switch(type) {
		// Group (folder) item
		case 0:
			inflater.inflate(R.menu.context_folder, menu);
			break;
			// Child (feed) item
		case 1:
			inflater.inflate(R.menu.context_feed, menu);
			break;
		}
	}

	@Override
	public boolean onContextItemSelected(MenuItem item) {
		final ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) item.getMenuInfo();
		switch (item.getItemId()) {

		case R.id.menu_mark_feed_as_read:
			new MarkFeedAsReadTask(getActivity(), apiManager) {
				@Override
				protected void onPostExecute(Boolean result) {
					if (result.booleanValue()) {
						ContentValues values = new ContentValues();
						values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, 0);
						values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, 0);
						values.put(DatabaseConstants.FEED_POSITIVE_COUNT, 0);
						resolver.update(FeedProvider.FEEDS_URI.buildUpon().appendPath(Long.toString(info.id)).build(), values, null, null);
						folderAdapter.requery();
						Toast.makeText(getActivity(), R.string.toast_marked_feed_as_read, Toast.LENGTH_SHORT).show();
					} else {
						Toast.makeText(getActivity(), R.string.toast_error_marking_feed_as_read, Toast.LENGTH_LONG).show();
					}	
				}
			}.execute(Long.toString(info.id));
			return true;

		case R.id.menu_delete_feed:
			Toast.makeText(getActivity(), "Deleted feed", Toast.LENGTH_SHORT).show();
			((Main) getActivity()).deleteFeed(info.id, null);
			return true;

		case R.id.menu_mark_folder_as_read:
			int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);
			if (folderAdapter.isExpandable(groupPosition)) {
				final Cursor folderCursor = ((MixedExpandableListAdapter) list.getExpandableListAdapter()).getGroup(groupPosition);
				String folderId = folderCursor.getString(folderCursor.getColumnIndex(DatabaseConstants.FOLDER_NAME));
				new MarkFolderAsReadTask(apiManager, resolver) {
					@Override
					protected void onPostExecute(Boolean result) {
						if (result) {
							folderAdapter.requery();
							Toast.makeText(getActivity(), R.string.toast_marked_folder_as_read, Toast.LENGTH_SHORT).show();
						} else {
							Toast.makeText(getActivity(), R.string.toast_error_marking_feed_as_read, Toast.LENGTH_SHORT).show();
						}
					}
				}.execute(folderId);
			} else {
				final Cursor socialFeedCursor = ((MixedExpandableListAdapter) list.getExpandableListAdapter()).getGroup(groupPosition);
				String socialFeedId = socialFeedCursor.getString(socialFeedCursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_ID));
				new MarkSocialFeedAsReadTask(apiManager, resolver){
					@Override
					protected void onPostExecute(Boolean result) {
						if (result.booleanValue()) {
							folderAdapter.requery();
							Toast.makeText(getActivity(), R.string.toast_marked_socialfeed_as_read, Toast.LENGTH_SHORT).show();
						} else {
							Toast.makeText(getActivity(), R.string.toast_error_marking_feed_as_read, Toast.LENGTH_LONG).show();
						}
					}
				}.execute(socialFeedId);
			}
			return true;	
		}
		return super.onContextItemSelected(item);
	}

	public void changeState(int state) {
		String groupSelection = null, blogSelection = null;
		groupViewBinder.setState(state);
		blogViewBinder.setState(state);
		currentState = state;

		switch (state) {
		case (AppConstants.STATE_ALL):
			groupSelection = DatabaseConstants.FOLDER_INTELLIGENCE_ALL;
			blogSelection = DatabaseConstants.SOCIAL_INTELLIGENCE_ALL;
			break;
		case (AppConstants.STATE_SOME):
			groupSelection = DatabaseConstants.FOLDER_INTELLIGENCE_SOME;
			blogSelection = DatabaseConstants.SOCIAL_INTELLIGENCE_SOME;
			break;
		case (AppConstants.STATE_BEST):
			groupSelection = DatabaseConstants.FOLDER_INTELLIGENCE_BEST;
			blogSelection = DatabaseConstants.SOCIAL_INTELLIGENCE_BEST;
			break;
		}

		folderAdapter.currentState = state;
		Cursor cursor = resolver.query(FeedProvider.FOLDERS_URI, null, null, new String[] { groupSelection }, null);
		Cursor blogCursor = resolver.query(FeedProvider.SOCIAL_FEEDS_URI, null, blogSelection, null, null);
		Cursor countCursor = resolver.query(FeedProvider.FEED_COUNT_URI, null, DatabaseConstants.SOCIAL_INTELLIGENCE_SOME, null, null); 

		folderAdapter.setBlogCursor(blogCursor);
		folderAdapter.setGroupCursor(cursor);
		folderAdapter.setCountCursor(countCursor);
		folderAdapter.notifyDataSetChanged();	
	}

	@Override
	public boolean onGroupClick(ExpandableListView list, View group, int groupPosition, long id) {
		if (folderAdapter.isExpandable(groupPosition)) {
			long groupId = folderAdapter.getGroupId(groupPosition);
			if (list.isGroupExpanded(groupPosition)) {
				group.findViewById(R.id.row_foldersums).setVisibility(View.VISIBLE);
				sharedPreferences.edit().putBoolean(AppConstants.FOLDER_PRE + groupId, false).commit();
			} else {
				group.findViewById(R.id.row_foldersums).setVisibility(View.INVISIBLE);
				sharedPreferences.edit().putBoolean(AppConstants.FOLDER_PRE + groupId, true).commit();
			}
			return false;
		} else {
			Intent i = new Intent(getActivity(), AllStoriesItemsList.class);
			i.putExtra(AllStoriesItemsList.EXTRA_STATE, currentState);
			startActivityForResult(i, FEEDCHECK);
			return true;
		}
	}

	@Override
	public boolean onChildClick(ExpandableListView list, View childView, int groupPosition, int childPosition, long id) {
		if (groupPosition == 0) {
			Cursor blurblogCursor = folderAdapter.getBlogCursor(childPosition);
			String username = blurblogCursor.getString(blurblogCursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_USERNAME));
			String userIcon = blurblogCursor.getString(blurblogCursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_ICON));
			String userId = blurblogCursor.getString(blurblogCursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_ID));
			String blurblogTitle = blurblogCursor.getString(blurblogCursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_TITLE));

			final Intent intent = new Intent(getActivity(), SocialFeedItemsList.class);
			intent.putExtra(ItemsList.EXTRA_BLURBLOG_USER_ICON, userIcon);
			intent.putExtra(ItemsList.EXTRA_BLURBLOG_USERNAME, username);
			intent.putExtra(ItemsList.EXTRA_BLURBLOG_TITLE, blurblogTitle);
			intent.putExtra(ItemsList.EXTRA_BLURBLOG_USERID, userId);
			intent.putExtra(ItemsList.EXTRA_STATE, currentState);
			getActivity().startActivityForResult(intent, FEEDCHECK );
		} else {
			final Intent intent = new Intent(getActivity(), FeedItemsList.class);
			Cursor childCursor = folderAdapter.getChild(groupPosition, childPosition);
			String feedId = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_ID));
			intent.putExtra(FeedItemsList.EXTRA_FEED, feedId);
			intent.putExtra(ItemsList.EXTRA_STATE, currentState);
			getActivity().startActivityForResult(intent, FEEDCHECK );
		}
		return true;
	}

}
