package com.newsblur.database;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.text.TextUtils;
import android.widget.SimpleCursorTreeAdapter;

import com.newsblur.domain.Folder;

public class FolderTreeAdapter extends SimpleCursorTreeAdapter {

	ContentResolver resolver; 
	public String currentState = FeedProvider.INTELLIGENCE_ALL;
	private String TAG = "FolderTreeAdapter";
	
	public FolderTreeAdapter(Context context, Cursor cursor, int collapsedGroupLayout, String[] groupFrom, int[] groupTo, int childLayout, String[] childFrom, int[] childTo) {
		super(context, cursor, collapsedGroupLayout, groupFrom, groupTo, childLayout, childFrom, childTo);
		resolver = context.getContentResolver();
	}

	@Override
	protected Cursor getChildrenCursor(Cursor folderCursor) {
		final Folder parentFolder = Folder.fromCursor(folderCursor);
		Uri uri = null;
		if (TextUtils.isEmpty(parentFolder.getName())) {
			uri = FeedProvider.FEED_FOLDER_MAP_URI;
		} else {
			uri = FeedProvider.FEED_FOLDER_MAP_URI.buildUpon().appendPath(parentFolder.getName()).build();
		}
		return resolver.query(uri, null, null, new String[] { currentState }, null);
	}
	
}
