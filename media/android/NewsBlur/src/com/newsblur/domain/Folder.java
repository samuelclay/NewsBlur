package com.newsblur.domain;

import android.content.ContentValues;

import com.newsblur.database.DatabaseConstants;

public class Folder {
	
	public final ContentValues values = new ContentValues();

	public void setId(final String id) {
		values.put(DatabaseConstants.FOLDER_ID, id);
	}
	
	public void setName(final String name) {
		values.put(DatabaseConstants.FOLDER_NAME, name);
	}
	
	
}
