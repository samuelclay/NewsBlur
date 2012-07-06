package com.newsblur.database;

import com.newsblur.domain.Folder;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.text.TextUtils;
import android.widget.SimpleCursorTreeAdapter;

public class FolderTreeAdapter extends SimpleCursorTreeAdapter {

	ContentResolver resolver; 
	
	public FolderTreeAdapter(Context context, Cursor cursor, int collapsedGroupLayout, int expandedGroupLayout, String[] groupFrom, int[] groupTo, int childLayout, String[] childFrom, int[] childTo) {
		super(context, cursor, collapsedGroupLayout, expandedGroupLayout, groupFrom, groupTo, childLayout, childFrom, childTo);
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
		return resolver.query(uri, null, null, null, null);
	}
	
}
