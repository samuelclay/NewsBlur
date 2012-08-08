package com.newsblur.fragment;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.support.v4.app.Fragment;
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
import android.widget.ImageView;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedExpandableListAdapter;
import com.newsblur.network.APIManager;
import com.newsblur.network.MarkFeedAsReadTask;
import com.newsblur.network.MarkFolderAsReadTask;
import com.newsblur.util.AppConstants;
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
	private String TAG = "FolderListFragment";
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		resolver = getActivity().getContentResolver();
		apiManager = new APIManager(getActivity());

		Cursor folderCursor = resolver.query(FeedProvider.FOLDERS_URI, null, null, new String[] { DatabaseConstants.FOLDER_INTELLIGENCE_SOME }, null);
		Cursor socialFeedCursor = resolver.query(FeedProvider.SOCIAL_FEEDS_URI, null, null, new String[] { DatabaseConstants.FOLDER_INTELLIGENCE_SOME }, null);
		groupViewBinder = new FolderTreeViewBinder();
		blogViewBinder = new SocialFeedViewBinder(getActivity());

		leftBound = UIUtils.convertDPsToPixels(getActivity(), 20);
		rightBound = UIUtils.convertDPsToPixels(getActivity(), 10);

		final String[] groupFrom = new String[] { DatabaseConstants.FOLDER_NAME, DatabaseConstants.SUM_POS, DatabaseConstants.SUM_NEG, DatabaseConstants.SUM_NEUT };
		final int[] groupTo = new int[] { R.id.row_foldername, R.id.row_foldersumpos, R.id.row_foldersumneg, R.id.row_foldersumneu };
		final String[] childFrom = new String[] { DatabaseConstants.FEED_TITLE, DatabaseConstants.FEED_FAVICON, DatabaseConstants.FEED_NEUTRAL_COUNT, DatabaseConstants.FEED_NEGATIVE_COUNT, DatabaseConstants.FEED_POSITIVE_COUNT };
		final int[] childTo = new int[] { R.id.row_feedname, R.id.row_feedfavicon, R.id.row_feedneutral, R.id.row_feednegative, R.id.row_feedpositive };
		final String[] blogFrom = new String[] { DatabaseConstants.SOCIAL_FEED_USERNAME, DatabaseConstants.SOCIAL_FEED_ICON, DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT, DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT, DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT };
		final int[] blogTo = new int[] { R.id.row_socialfeed_name, R.id.row_socialfeed_icon, R.id.row_socialsumneu, R.id.row_socialsumneg, R.id.row_socialsumpos };

		//folderAdapter = new FolderTreeAdapter(getActivity(), cursor, R.layout.row_folder_collapsed, groupFrom, groupTo, R.layout.row_feed, childFrom, childTo);
		folderAdapter = new MixedExpandableListAdapter(getActivity(), folderCursor, socialFeedCursor, R.layout.row_folder_collapsed, R.layout.row_folder_expanded, R.layout.row_socialfeed, groupFrom, groupTo, R.layout.row_feed, childFrom, childTo, blogFrom, blogTo);
		folderAdapter.setViewBinders(groupViewBinder, blogViewBinder);
	}

	public void hasUpdated() {
		folderAdapter.requery();
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
		
		return v;
	}

	@Override
	public void onCreateContextMenu(ContextMenu menu, View v, ContextMenuInfo menuInfo) {
		Log.d("Context", "ContextMenu created");
		MenuInflater inflater = getActivity().getMenuInflater();
		ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) menuInfo;
		int type = ExpandableListView.getPackedPositionType(info.packedPosition);
		//Only create a context menu for child items
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
			new MarkFeedAsReadTask(getActivity(), apiManager, resolver, folderAdapter).execute(Long.toString(info.id));
			return true;
			
		case R.id.menu_mark_folder_as_read:
			int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);
			final Cursor folderCursor = ((MixedExpandableListAdapter) list.getExpandableListAdapter()).getGroup(groupPosition);
			
			String folderId = folderCursor.getString(folderCursor.getColumnIndex(DatabaseConstants.FOLDER_NAME));
			
			new MarkFolderAsReadTask(getActivity(), apiManager, resolver, folderAdapter).execute(folderId);
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
		
		folderAdapter.currentState = groupSelection;
		Cursor cursor = resolver.query(FeedProvider.FOLDERS_URI, null, null, new String[] { groupSelection }, null);
		Cursor blogCursor = resolver.query(FeedProvider.SOCIAL_FEEDS_URI, null, blogSelection, null, null);
		
		folderAdapter.setBlogCursor(blogCursor);
		folderAdapter.setGroupCursor(cursor);
		folderAdapter.notifyDataSetChanged();	
	}

	@Override
	public boolean onGroupClick(ExpandableListView list, View group, int groupPosition, long id) {
		if (folderAdapter.isGroup(groupPosition)) {
			if (list.isGroupExpanded(groupPosition)) {
				group.findViewById(R.id.row_foldersums).setVisibility(View.VISIBLE);
				((ImageView) group.findViewById(R.id.indicator_icon)).setImageResource(R.drawable.indicator_collapsed);
			} else {
				group.findViewById(R.id.row_foldersums).setVisibility(View.INVISIBLE);
				((ImageView) group.findViewById(R.id.indicator_icon)).setImageResource(R.drawable.indicator_expanded);
			}
			return false;
		} else {
			Log.d(TAG, "Clicked blog.");
			Cursor blurblogCursor = folderAdapter.getGroup(groupPosition);
			String username = blurblogCursor.getString(blurblogCursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_USERNAME));
			String userId = blurblogCursor.getString(blurblogCursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_ID));
			
			final Intent intent = new Intent(getActivity(), ItemsList.class);
			intent.putExtra(ItemsList.EXTRA_BLURBLOG_USERNAME, username);
			intent.putExtra(ItemsList.EXTRA_BLURBLOG_USERID, userId);
			intent.putExtra(ItemsList.EXTRA_STATE, currentState);
			getActivity().startActivityForResult(intent, FEEDCHECK );
				
			return true;
		}
	}

	@Override
	public boolean onChildClick(ExpandableListView list, View childView, int groupPosition, int childPosition, long id) {
		final Intent intent = new Intent(getActivity(), ItemsList.class);
		Cursor childCursor = folderAdapter.getChild(groupPosition, childPosition);
		String feedId = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_ID));
		intent.putExtra(ItemsList.EXTRA_FEED, feedId);
		intent.putExtra(ItemsList.EXTRA_STATE, currentState);
		getActivity().startActivityForResult(intent, FEEDCHECK );
		return true;
	}

}
