package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;
import androidx.annotation.Nullable;
import android.text.TextUtils;

import java.util.Collection;
import java.util.Comparator;
import java.util.List;
import java.util.ArrayList;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.util.AppConstants;

public class Folder {

    /** Leaf title. Folder.java uses flatName() for identity, never this title alone. */
	public String name;
    /** List, drilling down from root to this folder of containing folders. NOTE: this is a path! */
    public List<String> parents = new ArrayList<>();
    /** Set of any children folders contained in this folder. NOTE: this is a one-to-many set! */
    public List<String> children = new ArrayList<>();
    /** Set of any feeds contained in this folder. */
    public List<String> feedIds = new ArrayList<>();

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
        values.put(DatabaseConstants.FOLDER_PATH, flatName());
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
            builder.append(" ▸ ");
        }
        builder.append(name);
        return builder.toString();
    }

    public String toString() {
        return flatName();
    }

    public int depth() {
        int depth = 0;
        for (String parent : parents) if (!AppConstants.ROOT_FOLDER.equals(parent)) depth++;
        return depth;
    }

    public String childPath(String childName) {
        return AppConstants.ROOT_FOLDER.equals(name) ? childName : flatName() + " ▸ " + childName;
    }

    public String parentPath() {
        List<String> path = new ArrayList<>(parents);
        path.remove(AppConstants.ROOT_FOLDER);
        return path.isEmpty() ? AppConstants.ROOT_FOLDER : String.join(" ▸ ", path);
    }

    public void removeOrphanFeedIds(Collection<String> orphanFeedIds) {
        feedIds.removeAll(orphanFeedIds);
    }

    @Nullable
    public String getFirstParentName() {
        String folderParentName = null;
        if (!parents.isEmpty()) {
            folderParentName = parents.get(parents.size() - 1);
        }
        return folderParentName;
    }
	
	@Override
	public boolean equals(Object otherFolder) {
        if (! (otherFolder instanceof Folder)) return false;
		return flatName().equals(((Folder) otherFolder).flatName());
	}

    @Override
    public int hashCode() {
        return flatName().hashCode();
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
            List<String> p1 = new ArrayList<>(f1.parents);
            List<String> p2 = new ArrayList<>(f2.parents);
            p1.remove(AppConstants.ROOT_FOLDER);
            p2.remove(AppConstants.ROOT_FOLDER);
            p1.add(f1.name);
            p2.add(f2.name);
            for (int i = 0; i < Math.min(p1.size(), p2.size()); i++) {
                int result = compareFolderNames(p1.get(i), p2.get(i));
                if (result != 0) return result;
            }
            return Integer.compare(p1.size(), p2.size());
        }
    };

    /**
     * Custom sorting for folders. Handles the special case to keep the root
     * folder on top, and also the expectation that *despite locale*, folders
     * starting with an underscore should show up on top.
     */
    public static int compareFolderNames(String s1, String s2) {
        if (s1.equals(s2)) return 0;
        if (s1.equals(AppConstants.ROOT_FOLDER)) return -1;
        if (s2.equals(AppConstants.ROOT_FOLDER)) return 1;
        if (s1.startsWith("_") != s2.startsWith("_")) return s1.startsWith("_") ? -1 : 1;
        int result = String.CASE_INSENSITIVE_ORDER.compare(s1, s2);
        return result == 0 ? s1.compareTo(s2) : result;
    }


}
