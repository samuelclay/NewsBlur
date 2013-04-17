package com.newsblur.database;

import java.util.Map;
import java.util.HashMap;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.ContentObserver;
import android.database.Cursor;
import android.database.DataSetObserver;
import android.net.Uri;
import android.os.Handler;
import android.support.v4.widget.SimpleCursorAdapter.ViewBinder;
import android.text.TextUtils;
import android.util.Log;
import android.util.SparseArray;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.BaseExpandableListAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.AllSharedStoriesItemsList;
import com.newsblur.activity.AllStoriesItemsList;
import com.newsblur.domain.Folder;
import com.newsblur.util.AppConstants;

public class MixedExpandableListAdapter extends BaseExpandableListAdapter{

	// Child-type & Group-type IDs must be less than their respective type-counts, even though they're never implicitly mentioned as linked
	private final int FOLDER = 0;
	private final int BLOG = 0;
	private final int FEED = 1;
	private final int ALL_STORIES = 1;
	private final int ALL_SHARED_STORIES = 2;

	private SparseArray<MyCursorHelper> mChildrenCursorHelpers;
	private MyCursorHelper folderCursorHelper, blogCursorHelper;
	private ContentResolver contentResolver;
	private Context context;

    private Map<Integer,Integer> groupColumnMap;
    private Map<Integer,Integer> childColumnMap;
    private Map<Integer,Integer> blogColumnMap;

	private final LayoutInflater inflater;
	private ViewBinder groupViewBinder;
	private ViewBinder blogViewBinder;

	public int currentState = AppConstants.STATE_SOME;
	private Cursor allStoriesCountCursor, sharedStoriesCountCursor;

	public MixedExpandableListAdapter(final Context context, final Cursor folderCursor, final Cursor blogCursor, final Cursor countCursor, final Cursor sharedCountCursor) {

		this.context = context;
		this.allStoriesCountCursor = countCursor;
		this.sharedStoriesCountCursor = sharedCountCursor;

		inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
		contentResolver = context.getContentResolver();

		folderCursorHelper = new MyCursorHelper(folderCursor);
		blogCursorHelper = new MyCursorHelper(blogCursor);

		mChildrenCursorHelpers = new SparseArray<MyCursorHelper>();

		initColumnMaps();
	}

	/**
     * Load and store mappings from runtime DB column indicies to resource IDs needed by this class.
     *
     * TODO: this whole business with the mappings has a smell to it - figure out why.
     */
    private void initColumnMaps() {

        this.groupColumnMap = new HashMap<Integer,Integer>();
        Cursor folderCursor = folderCursorHelper.getCursor();
        this.groupColumnMap.put(folderCursor.getColumnIndexOrThrow(DatabaseConstants.FOLDER_NAME), R.id.row_foldername);
        this.groupColumnMap.put(folderCursor.getColumnIndexOrThrow(DatabaseConstants.SUM_POS), R.id.row_foldersumpos);
        this.groupColumnMap.put(folderCursor.getColumnIndexOrThrow(DatabaseConstants.SUM_NEUT), R.id.row_foldersumneu);

        this.blogColumnMap = new HashMap<Integer,Integer>();
        Cursor blogCursor = blogCursorHelper.getCursor();
        this.blogColumnMap.put(blogCursor.getColumnIndexOrThrow(DatabaseConstants.SOCIAL_FEED_TITLE), R.id.row_socialfeed_name);
        this.blogColumnMap.put(blogCursor.getColumnIndexOrThrow(DatabaseConstants.SOCIAL_FEED_ICON), R.id.row_socialfeed_icon);
        this.blogColumnMap.put(blogCursor.getColumnIndexOrThrow(DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT), R.id.row_socialsumneu);
        this.blogColumnMap.put(blogCursor.getColumnIndexOrThrow(DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT), R.id.row_socialsumpos);
        
        // child cursors are lazily initialized.  temporarily try to init the first one and use it, as
        // all of them have the same column layout.  If there is not first folder, there is nothing we
        // can do yet.  Leave the map null and we'll lazily init it later when the DB is up and going.
        if (folderCursor.moveToPosition(0)) {
            this.childColumnMap = new HashMap<Integer,Integer>();
            Cursor childCursor = getChildrenCursor(folderCursor);
            this.childColumnMap.put(childCursor.getColumnIndexOrThrow(DatabaseConstants.FEED_TITLE), R.id.row_feedname);
            this.childColumnMap.put(childCursor.getColumnIndexOrThrow(DatabaseConstants.FEED_FAVICON_URL), R.id.row_feedfavicon);
            this.childColumnMap.put(childCursor.getColumnIndexOrThrow(DatabaseConstants.FEED_NEUTRAL_COUNT), R.id.row_feedneutral);
            this.childColumnMap.put(childCursor.getColumnIndexOrThrow(DatabaseConstants.FEED_POSITIVE_COUNT), R.id.row_feedpositive);
            // close the temp cursor
            childCursor.close();
        } else {
            Log.w(this.getClass().getName(), "deferring init. of column mappings for child views");
        }

	}

	public void setViewBinders(final ViewBinder groupViewBinder, final ViewBinder blogViewBinder) {
		this.groupViewBinder = groupViewBinder;
		this.blogViewBinder = blogViewBinder;
	}

	private Cursor getChildrenCursor(Cursor folderCursor) {
		final Folder parentFolder = Folder.fromCursor(folderCursor);
		Uri uri = FeedProvider.FEED_FOLDER_MAP_URI.buildUpon().appendPath(parentFolder.getName()).build();
		return contentResolver.query(uri, null, null, new String[] { FeedProvider.getFolderSelectionFromState(currentState) }, null);
	}

	@Override
	public int getGroupType(int groupPosition) {
		if (groupPosition == 0) {
			return ALL_SHARED_STORIES;
		} else if (groupPosition == 1) {
			return ALL_STORIES;
		} else {
			return FOLDER;
		}
	}

    @Override
	public int getChildType(int groupPosition, int childPosition) {
		if (groupPosition == 0) {
			return BLOG;
		} else {
			return FEED;
		}
	}

	@Override
	public int getGroupTypeCount() {
		return 3;
	}

	@Override
	public int getChildTypeCount() {
		return 2;
	}

	@Override
	public Cursor getChild(int groupPosition, int childPosition) {
		if (groupPosition == 0) {
			blogCursorHelper.moveTo(childPosition);
			return blogCursorHelper.getCursor();
		} else {
			groupPosition = groupPosition - 2;
			return getChildrenCursorHelper(groupPosition).moveTo(childPosition);
		}
	}

	@Override
    public long getChildId(int groupPosition, int childPosition) {
		if (groupPosition == 0) {
			return blogCursorHelper.getId(childPosition);
		} else {
			MyCursorHelper childrenCursorHelper = getChildrenCursorHelper(groupPosition - 2);
			return childrenCursorHelper.getId(childPosition);
		}
	}

	@Override
	public View getChildView(int groupPosition, int childPosition, boolean isLastChild, View convertView, ViewGroup parent) {
		View v;
		if (groupPosition == 0) {
			blogCursorHelper.moveTo(childPosition);
			if (convertView == null) {
				v = newBlogView(context, blogCursorHelper.getCursor(), parent);
			} else {
				v = convertView;
			}
			bindBlogView(v, context, blogCursorHelper.getCursor());
		} else {
			groupPosition = groupPosition - 2;

			MyCursorHelper cursorHelper = getChildrenCursorHelper(groupPosition);

			Cursor cursor = cursorHelper.moveTo(childPosition);
			if (cursor == null) {
				throw new IllegalStateException("This should only be called when the cursor is valid");
			}
			if (convertView == null) {
				v = newChildView(context, cursor, isLastChild, parent);
			} else {
				v = convertView;
			}
			bindChildView(v, context, cursor, isLastChild);
		}
		return v;
	}

	@Override
	public int getChildrenCount(int groupPosition) {
		if (groupPosition == 0) {
			return blogCursorHelper.getCount();
		} else {
			groupPosition = groupPosition - 2;
			MyCursorHelper helper = getChildrenCursorHelper(groupPosition);
			return (folderCursorHelper.isValid() && helper != null) ? helper.getCount() : 0;
		}
	}

	public View newChildView(Context context, Cursor cursor, boolean isLastChild, ViewGroup parent) {
		return inflater.inflate(R.layout.row_feed, parent, false);
	}

	@Override
	public Cursor getGroup(int groupPosition) {
		return folderCursorHelper.moveTo(groupPosition - 2);
	}

	public Cursor getBlogCursor(int childPosition) {
		return blogCursorHelper.moveTo(childPosition);
	}

	public boolean isExpandable(int groupPosition) {
        // TODO: non-expandability of the All Stories folder is what gives it special
        //  behaviour. 
        return (groupPosition == 0 || groupPosition > 1);
	}

	@Override
	public int getGroupCount() {
		return (folderCursorHelper.getCount() + 2);
	}

	@Override
	public long getGroupId(int groupPosition) {
		if (groupPosition >= 2) {
			return folderCursorHelper.getId(groupPosition-2);
		} else {
			return Long.MAX_VALUE - groupPosition;
		}
	}
	
	public String getGroupName(int groupPosition) {
		if (groupPosition == 0) {
			return "[ALL_SHARED_STORIES]";
		} else if(groupPosition == 1) {
			return "[ALL_STORIES]";
		} else {
			Cursor cursor = folderCursorHelper.getCursor();
			cursor.moveToPosition(groupPosition-2);
			// Is folder name really always unique?
			return cursor.getString(cursor.getColumnIndex("folder_name"));
		}
	}

	public void setGroupCursor(Cursor cursor) {
		folderCursorHelper.changeCursor(cursor, false);
	}

	public void setBlogCursor(Cursor blogCursor) {
		blogCursorHelper.changeCursor(blogCursor, false);
	}

	public void setCountCursor(Cursor countCursor) {
		this.allStoriesCountCursor = countCursor;
	}

	@Override
	public View getGroupView(int groupPosition, boolean isExpanded, View convertView, ViewGroup parent) {
		Cursor cursor = null;
		View v;
		if (groupPosition == 0) {
			cursor = sharedStoriesCountCursor;
			v =  inflater.inflate(R.layout.row_all_shared_stories, null, false);
			sharedStoriesCountCursor.moveToFirst();
			((TextView) v.findViewById(R.id.row_everythingtext)).setOnClickListener(new OnClickListener() {
				@Override
				public void onClick(View v) {
					Intent i = new Intent(context, AllSharedStoriesItemsList.class);
					i.putExtra(AllStoriesItemsList.EXTRA_STATE, currentState);
					((Activity) context).startActivityForResult(i, Activity.RESULT_OK);
				}
			});
			String neutCount = sharedStoriesCountCursor.getString(sharedStoriesCountCursor.getColumnIndex(DatabaseConstants.SUM_NEUT));
			if (currentState == AppConstants.STATE_BEST || TextUtils.isEmpty(neutCount) || TextUtils.equals(neutCount, "0")) {
				v.findViewById(R.id.row_foldersumneu).setVisibility(View.GONE);
			} else {
				v.findViewById(R.id.row_foldersumneu).setVisibility(View.VISIBLE);
				((TextView) v.findViewById(R.id.row_foldersumneu)).setText(neutCount);	
			}
			
			String posCount = sharedStoriesCountCursor.getString(sharedStoriesCountCursor.getColumnIndex(DatabaseConstants.SUM_POS));
			if (TextUtils.isEmpty(posCount) || TextUtils.equals(posCount, "0")) {
				v.findViewById(R.id.row_foldersumpos).setVisibility(View.GONE);
			} else {
				v.findViewById(R.id.row_foldersumpos).setVisibility(View.VISIBLE);
				((TextView) v.findViewById(R.id.row_foldersumpos)).setText(posCount);
			}
			
			v.findViewById(R.id.row_foldersums).setVisibility(isExpanded ? View.INVISIBLE : View.VISIBLE);
			((ImageView) v.findViewById(R.id.row_folder_indicator)).setImageResource(isExpanded ? R.drawable.indicator_expanded : R.drawable.indicator_collapsed);
		} else if (groupPosition == 1) {
			cursor = allStoriesCountCursor;
			v =  inflater.inflate(R.layout.row_all_stories, null, false);
			allStoriesCountCursor.moveToFirst();
			switch (currentState) {
				case AppConstants.STATE_BEST:
					v.findViewById(R.id.row_foldersumneu).setVisibility(View.INVISIBLE);
					((TextView) v.findViewById(R.id.row_foldersumpos)).setText(allStoriesCountCursor.getString(allStoriesCountCursor.getColumnIndex(DatabaseConstants.SUM_POS)));
					break;
				default:	
					((TextView) v.findViewById(R.id.row_foldersumneu)).setText(allStoriesCountCursor.getString(allStoriesCountCursor.getColumnIndex(DatabaseConstants.SUM_NEUT)));
					((TextView) v.findViewById(R.id.row_foldersumpos)).setText(allStoriesCountCursor.getString(allStoriesCountCursor.getColumnIndex(DatabaseConstants.SUM_POS)));
					break;
			}
 			
		} else {
			cursor = folderCursorHelper.moveTo(groupPosition - 2);
			if (convertView == null) {
				v = newGroupView(context, cursor, isExpanded, parent);
			} else {
				v = convertView;
			}
			bindGroupView(v, context, cursor, isExpanded);
		}

		if (cursor == null) {
			throw new IllegalStateException("this should only be called when the cursor is valid");
		}

		return v;
	}

	private View newGroupView(Context context, Cursor cursor, boolean isExpanded, ViewGroup parent) {
		return inflater.inflate((isExpanded) ? R.layout.row_folder_collapsed : R.layout.row_folder_collapsed, parent, false);
	}

	private View newBlogView(Context context, Cursor cursor, ViewGroup parent) {
		return inflater.inflate(R.layout.row_socialfeed, parent, false);
	}

	@Override
	public boolean hasStableIds() {
		return true;
	}

	@Override
	public boolean isChildSelectable(int groupPosition, int childPosition) {
		return true;
	}

	protected void bindChildView(View view, Context context, Cursor cursor, boolean isLastChild) {
        if (this.childColumnMap == null) {
            // work-around: if the adapter was created before we had a DB, it may have been
            // incompletely initialized.  Re-do it!
            initColumnMaps();
        }
		bindView(view, context, cursor, this.childColumnMap, groupViewBinder);
	}

	protected void bindGroupView(View view, Context context, Cursor cursor, boolean isExpanded) {
		bindView(view, context, cursor, this.groupColumnMap, groupViewBinder);
		view.findViewById(R.id.row_foldersums).setVisibility(isExpanded ? View.INVISIBLE : View.VISIBLE);
		((ImageView) view.findViewById(R.id.row_folder_icon)).setImageResource(isExpanded ? R.drawable.folder_open : R.drawable.folder_closed);
		((ImageView) view.findViewById(R.id.row_folder_indicator)).setImageResource(isExpanded ? R.drawable.indicator_expanded : R.drawable.indicator_collapsed);
	}

	protected void bindBlogView(View view, Context context, Cursor cursor) {
		bindView(view, context, cursor, this.blogColumnMap, blogViewBinder);
	}

	private void bindView(View view, Context context, Cursor cursor, Map<Integer,Integer> columnMap, ViewBinder viewbinder) {
		final ViewBinder binder = viewbinder;
        for (Map.Entry<Integer,Integer> column : columnMap.entrySet()) {
            // column.key is a DB column name, column.value is a resourceID
			View v = view.findViewById(column.getValue());
			if (v != null) {
				boolean bound = false;
				if (binder != null) {
					bound = binder.setViewValue(v, cursor, column.getKey());
				}

				if (!bound) {
					String text = cursor.getString(column.getKey());
					if (text == null) {
						text = "";
					}
					if (v instanceof TextView) {
						((TextView) v).setText(text);
					} else if (v instanceof ImageView) {
						setViewImage((ImageView) v, text);
					} else {
						throw new IllegalStateException("SimpleCursorTreeAdapter can bind values only to TextView and ImageView!");
					}
				}
			}
		}
	}

	private synchronized void deactivateChildrenCursorHelper(int groupPosition) {
		MyCursorHelper cursorHelper = getChildrenCursorHelper(groupPosition);
		mChildrenCursorHelpers.remove(groupPosition);
		cursorHelper.deactivate();
	}

	private synchronized MyCursorHelper getChildrenCursorHelper( int groupPosition ) {

		MyCursorHelper cursorHelper = mChildrenCursorHelpers.get(groupPosition);

		if (cursorHelper == null) {
			if (folderCursorHelper.moveTo(groupPosition) == null) return null;

			final Cursor cursor = getChildrenCursor(folderCursorHelper.getCursor());
			cursorHelper = new MyCursorHelper(cursor);
			mChildrenCursorHelpers.put(groupPosition, cursorHelper);
		}

		return cursorHelper;
	}

	private synchronized void releaseCursorHelpers() {
		for (int pos = mChildrenCursorHelpers.size() - 1; pos >= 0; pos--) {
			mChildrenCursorHelpers.valueAt(pos).deactivate();
		}
		mChildrenCursorHelpers.clear();
	}

	@Override
	public void notifyDataSetChanged() {
		notifyDataSetChanged(true);
	}

	public void notifyDataSetChanged(boolean releaseCursors) {
		if (releaseCursors) {
			releaseCursorHelpers();
			if (allStoriesCountCursor != null) {
				allStoriesCountCursor.deactivate();
			}
		}
		super.notifyDataSetChanged();
	}

    // TODO: the requery() method on cursors is deprecated.  This class needs a way
    //  to re-create all cursors via the original means used to make them.
	public void requery() {
		notifyDataSetInvalidated();
		folderCursorHelper.getCursor().requery();
		blogCursorHelper.getCursor().requery();
		allStoriesCountCursor.requery();
		sharedStoriesCountCursor.requery();
	}

	@Override
	public void notifyDataSetInvalidated() {
		releaseCursorHelpers();
		super.notifyDataSetInvalidated();
	}

	class MyCursorHelper {
		private Cursor mCursor;
		private boolean mDataValid;
		private int mRowIDColumn;
		private MyContentObserver mContentObserver;
		private MyDataSetObserver mDataSetObserver;

		MyCursorHelper(Cursor cursor) {
			final boolean cursorPresent = cursor != null;
			mCursor = cursor;
			mDataValid = cursorPresent;
			mRowIDColumn = cursorPresent ? cursor.getColumnIndex("_id") : -1;
			mContentObserver = new MyContentObserver();
			mDataSetObserver = new MyDataSetObserver();
			if (cursorPresent) {
				cursor.registerContentObserver(mContentObserver);
				cursor.registerDataSetObserver(mDataSetObserver);
			}
		}

		Cursor getCursor() {
			return mCursor;
		}

		int getCount() {
			if (mDataValid && mCursor != null) {
				return mCursor.getCount();
			} else {
				return 0;
			}
		}

		long getId(int position) {
			if (mDataValid && mCursor != null) {
				if (mCursor.moveToPosition(position)) {
					Long id =  mCursor.getLong(mRowIDColumn);
					return id;
				} else {
					return 0;
				}
			} else {
				return 0;
			}
		}

		Cursor moveTo(int position) {
			if (mDataValid && (mCursor != null) && mCursor.moveToPosition(position)) {
				return mCursor;
			} else {
				return null;
			}
		}

		void changeCursor(Cursor cursor, boolean releaseCursors) {
			if (cursor == mCursor) return;

			deactivate();
			mCursor = cursor;
			if (cursor != null) {
				cursor.registerContentObserver(mContentObserver);
				cursor.registerDataSetObserver(mDataSetObserver);
				mRowIDColumn = cursor.getColumnIndex("_id");
				mDataValid = true;
				notifyDataSetChanged(releaseCursors);
			} else {
				mRowIDColumn = -1;
				mDataValid = false;
				notifyDataSetInvalidated();
			}
		}

		void deactivate() {
			if (mCursor == null) {
				return;
			}

			mCursor.unregisterContentObserver(mContentObserver);
			mCursor.unregisterDataSetObserver(mDataSetObserver);
			mCursor.close();
			mCursor.deactivate();
			mCursor = null;
		}

		boolean isValid() {
			return mDataValid && mCursor != null;
		}

        // TODO: the cursors don't seem to do anything on content change. why
        //  was this added in the first place?
		private class MyContentObserver extends ContentObserver {
			public MyContentObserver() {
				super(null);
			}

			@Override
			public boolean deliverSelfNotifications() {
				return true;
			}

			@Override
			public void onChange(boolean selfChange) {
			}
		}

		private class MyDataSetObserver extends DataSetObserver {
			@Override
			public void onChanged() {
				mDataValid = true;
				notifyDataSetInvalidated();
			}

			@Override
			public void onInvalidated() {
				mDataValid = false;
				notifyDataSetInvalidated();
			}
		}
	}

	protected void setViewImage(ImageView v, String value) {
		try {
			v.setImageResource(Integer.parseInt(value));
		} catch (NumberFormatException nfe) {
			v.setImageURI(Uri.parse(value));
		}
	}

}
