package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;
import android.text.TextUtils;

import java.util.Collection;
import java.util.Comparator;
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
		folder.parents = DatabaseConstants.unflattenStringList(c.getString(c.getColumnIndex(DatabaseConstants.FOLDER_PARENT_NAMES)));
		folder.children = DatabaseConstants.unflattenStringList(c.getString(c.getColumnIndex(DatabaseConstants.FOLDER_CHILDREN_NAMES)));
        folder.feedIds = DatabaseConstants.unflattenStringList(c.getString(c.getColumnIndex(DatabaseConstants.FOLDER_FEED_IDS)));
		return folder;
	}

	public ContentValues getValues() {
		ContentValues values = new ContentValues();
		values.put(DatabaseConstants.FOLDER_NAME, name);
		values.put(DatabaseConstants.FOLDER_PARENT_NAMES, DatabaseConstants.flattenStringList(parents));
		values.put(DatabaseConstants.FOLDER_CHILDREN_NAMES, DatabaseConstants.flattenStringList(children));
        values.put(DatabaseConstants.FOLDER_FEED_IDS, DatabaseConstants.flattenStringList(feedIds));
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
        return builder.toString().toUpperCase();
    }

    public String toString() {
        return flatName();
    }

    public void removeOrphanFeedIds(Collection<String> orphanFeedIds) {
        feedIds.removeAll(orphanFeedIds);
    }
	
	@Override
	public boolean equals(Object otherFolder) {
		return TextUtils.equals(((Folder) otherFolder).name, name);
	}

    @Override
    public int hashCode() {
        return name.hashCode();
    }
	
    public final static Comparator<String> FolderNameComparator = new Comparator<String>() {
        @Override
        public int compare(String s1, String s2) {
            return compareFolderNames(s1, s2);
        }
    };

    public final static Comparator<Folder> FolderComparator = new Comparator<Folder>() {
        @Override
        public int compare(Folder f1, Folder f2) {
            return compareFolderNames(f1.name, f2.name);
        }
    };

    /**
     * Custom sorting for folders. Handles the special case to keep the root
     * folder on top, and also the expectation that *despite locale*, folders
     * starting with an underscore should show up on top.
     */
    private static int compareFolderNames(String s1, String s2) {
        if (TextUtils.equals(s1, s2)) return 0;
        if (s1.equals(AppConstants.ROOT_FOLDER)) return -1;
        if (s2.equals(AppConstants.ROOT_FOLDER)) return 1;
        if (s1.startsWith("_")) return -1;
        if (s2.startsWith("_")) return 1;
        return String.CASE_INSENSITIVE_ORDER.compare(s1, s2);
    }


}
