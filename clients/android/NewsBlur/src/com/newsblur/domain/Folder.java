package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;
import android.text.TextUtils;

import com.newsblur.database.DatabaseConstants;

public class Folder {
	
	public final ContentValues values = new ContentValues();

	public void setId(final String id) {
		values.put(DatabaseConstants.FOLDER_ID, id);
	}
	
	public void setName(final String name) {
		values.put(DatabaseConstants.FOLDER_NAME, name);
	}
	
	public String getId() {
		return values.getAsString(DatabaseConstants.FOLDER_ID);
	}
	
	public String getName() {
		return values.getAsString(DatabaseConstants.FOLDER_NAME);
	}

	public static Folder fromCursor(Cursor folderCursor) {
		final Folder folder = new Folder();
		folder.setId(folderCursor.getString(folderCursor.getColumnIndex(DatabaseConstants.FOLDER_ID)));
		folder.setName(folderCursor.getString(folderCursor.getColumnIndex(DatabaseConstants.FOLDER_NAME)));
		return folder;
	}
	
	@Override
	public boolean equals(Object otherFolder) {
		return TextUtils.equals(((Folder) otherFolder).getId(), getId());
	}
	
}
