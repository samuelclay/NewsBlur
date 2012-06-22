package com.newsblur.domain;

import com.newsblur.database.Constants;

import android.content.ContentValues;

public class Folder {
	
	public final ContentValues values = new ContentValues();

	public void setName(final String name) {
		values.put(Constants.FOLDER_NAME, name);
	}

	public void setId(final String id) {
		values.put(Constants.FOLDER_ID, id);
	}
}
