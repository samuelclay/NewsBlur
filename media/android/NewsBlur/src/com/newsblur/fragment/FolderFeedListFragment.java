package com.newsblur.fragment;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.view.Display;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ExpandableListView;
import android.widget.ExpandableListView.OnChildClickListener;
import android.widget.ExpandableListView.OnGroupClickListener;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.FolderTreeAdapter;
import com.newsblur.domain.Feed;
import com.newsblur.util.AppConstants;
import com.newsblur.util.UIUtils;
import com.newsblur.view.FolderTreeViewBinder;

public class FolderFeedListFragment extends Fragment implements OnGroupClickListener, OnChildClickListener {

	private ExpandableListView list;
	private ContentResolver resolver;
	private FolderTreeAdapter folderAdapter;
	private FolderTreeViewBinder viewBinder;
	private int leftBound, rightBound;
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		resolver = getActivity().getContentResolver();
		Cursor cursor = resolver.query(FeedProvider.FOLDERS_URI, null, null, null, null);
		viewBinder = new FolderTreeViewBinder();
		
		leftBound = UIUtils.convertDPsToPixels(getActivity(), 20);
		rightBound = UIUtils.convertDPsToPixels(getActivity(), 10);
		
		final String[] groupFrom = new String[] { DatabaseConstants.FOLDER_NAME, DatabaseConstants.SUM_POS, DatabaseConstants.SUM_NEG, DatabaseConstants.SUM_NEUT };
		final int[] groupTo = new int[] { R.id.row_foldername, R.id.row_foldersumpos, R.id.row_foldersumneg, R.id.row_foldersumneu };
		final String[] childFrom = new String[] { DatabaseConstants.FEED_TITLE, DatabaseConstants.FEED_FAVICON, DatabaseConstants.FEED_NEUTRAL_COUNT, DatabaseConstants.FEED_NEGATIVE_COUNT, DatabaseConstants.FEED_POSITIVE_COUNT };
		final int[] childTo = new int[] { R.id.row_feedname, R.id.row_feedfavicon, R.id.row_feedneutral, R.id.row_feednegative, R.id.row_feedpositive };

		folderAdapter = new FolderTreeAdapter(getActivity(), cursor, R.layout.row_folder_collapsed, groupFrom, groupTo, R.layout.row_feed, childFrom, childTo);
		folderAdapter.setViewBinder(viewBinder);
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_folderfeedlist, container);
		list = (ExpandableListView) v.findViewById(R.id.folderfeed_list);
		
		Display display = getActivity().getWindowManager().getDefaultDisplay();
		int width = display.getWidth();
		list.setIndicatorBounds(width - leftBound, width - rightBound);
		
		list.setChildDivider(getActivity().getResources().getDrawable(R.drawable.divider_light));
		list.setAdapter(folderAdapter);
		list.setOnGroupClickListener(this);
		list.setOnChildClickListener(this);
		return v;
	}

	public void changeState(int state) {
		
		String selection = null;
		viewBinder.setState(state);
		
		switch (state) {
		case (AppConstants.STATE_ALL):
			selection = FeedProvider.INTELLIGENCE_ALL;
			break;
		case (AppConstants.STATE_SOME):
			selection = FeedProvider.INTELLIGENCE_SOME;
			break;
		case (AppConstants.STATE_BEST):
			selection = FeedProvider.INTELLIGENCE_BEST;
			break;
		}
		
		folderAdapter.currentState = selection;
		Cursor cursor = resolver.query(FeedProvider.FOLDERS_URI, null, null, new String[] { selection }, null);
		folderAdapter.setGroupCursor(cursor);
		folderAdapter.notifyDataSetChanged();	
	}

	@Override
	public boolean onGroupClick(ExpandableListView list, View group, int groupPosition, long id) {
		if (list.isGroupExpanded(groupPosition)) {
			group.findViewById(R.id.row_foldersums).setVisibility(View.VISIBLE);
		} else {
			group.findViewById(R.id.row_foldersums).setVisibility(View.INVISIBLE);
		}
		return false;
	}

	@Override
	public boolean onChildClick(ExpandableListView list, View childView, int groupPosition, int childPosition, long id) {
		final Intent intent = new Intent(getActivity(), ItemsList.class);
		Cursor childCursor = folderAdapter.getChild(groupPosition, childPosition);
		String feedId = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_ID));
		intent.putExtra(ItemsList.EXTRA_FEED, feedId);
		getActivity().startActivity(intent);
		return true;
	}

}
