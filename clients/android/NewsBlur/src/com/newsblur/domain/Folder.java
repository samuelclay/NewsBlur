package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;
import android.text.TextUtils;

import java.util.ArrayList;
import java.util.List;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.util.AppConstants;

public class Folder {
	
    /** Actual unique name of the folder. */
	public String name;
    /** List, drilling down from root to this folder of containing folders. NOTE: this is a path! */
    public List<String> parents;
    /** Set of any children folders contained in this folder. NOTE: this is a one-to-many set! */
    public List<String> children;
    /** Set of any feeds contained in this folder. */
    public List<String> feedIds;

	public static Folder fromCursor(Cursor c) {
		if (c.isBeforeFirst()) {
			c.moveToFirst();
		}
		Folder folder = new Folder();
		folder.name = c.getString(c.getColumnIndex(DatabaseConstants.FOLDER_NAME));
        String parents = c.getString(c.getColumnIndex(DatabaseConstants.FOLDER_PARENT_NAMES));
		folder.parents = new ArrayList<String>();
        for (String name : TextUtils.split(parents, ",")) { folder.parents.add(name);}
        String children = c.getString(c.getColumnIndex(DatabaseConstants.FOLDER_CHILDREN_NAMES));
		folder.children = new ArrayList<String>();
        for (String name : TextUtils.split(children, ",")) { folder.children.add(name);}
        String feeds = c.getString(c.getColumnIndex(DatabaseConstants.FOLDER_FEED_IDS));
        folder.feedIds = new ArrayList<String>();
        for (String id : TextUtils.split(feeds, ",")) { folder.feedIds.add(id);}
		return folder;
	}

	public ContentValues getValues() {
		ContentValues values = new ContentValues();
		values.put(DatabaseConstants.FOLDER_NAME, name);
		values.put(DatabaseConstants.FOLDER_PARENT_NAMES, TextUtils.join(",", parents));
		values.put(DatabaseConstants.FOLDER_CHILDREN_NAMES, TextUtils.join(",", children));
        values.put(DatabaseConstants.FOLDER_FEED_IDS, TextUtils.join(",", feedIds));
		return values;
	}

    public String flatName() {
        StringBuilder builder = new StringBuilder();
        for (String parentName : parents) {
            if (parentName.equals(AppConstants.ROOT_FOLDER)) continue;
            builder.append(parentName);
            builder.append(" - ");
        }
        builder.append(name);
        return builder.toString();
    }
	
	@Override
	public boolean equals(Object otherFolder) {
		return TextUtils.equals(((Folder) otherFolder).name, name);
	}

    @Override
    public int hashCode() {
        return name.hashCode();
    }
	
}
