package com.newsblur.database;

import android.content.ContentResolver;
import android.content.Context;
import android.database.ContentObserver;
import android.database.Cursor;
import android.database.DataSetObserver;
import android.net.Uri;
import android.os.Handler;
import android.support.v4.widget.SimpleCursorAdapter.ViewBinder;
import android.util.Config;
import android.util.Log;
import android.util.SparseArray;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseExpandableListAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.domain.Folder;

@SuppressWarnings("deprecation")
public class MixedExpandableListAdapter extends BaseExpandableListAdapter{

	private Handler mHandler;
	private boolean mAutoRequery;

	private SparseArray<MyCursorHelper> mChildrenCursorHelpers;
	private MyCursorHelper folderCursorHelper;
	private ContentResolver contentResolver;
	private Context context;

	private int[] groupFrom;
	private int[] groupTo;
	private int[] childFrom;
	private int[] childTo;
	private final int childLayout;
	private final int expandedGroupLayout;
	private final int collapsedGroupLayout;
	private final LayoutInflater inflater;
	private ViewBinder viewBinder;

	public String currentState = DatabaseConstants.FOLDER_INTELLIGENCE_ALL;

	private final Cursor folderCursor;
	private final Cursor blogCursor;
	int itemCount = 1;

	public MixedExpandableListAdapter(final Context context, final Cursor folderCursor, final Cursor blogCursor, final int collapsedGroupLayout,
			int expandedGroupLayout, String[] groupFrom, int[] groupTo, int childLayout, String[] childFrom, int[] childTo) {
		this.context = context;
		this.folderCursor = folderCursor;
		this.blogCursor = blogCursor;
		this.expandedGroupLayout = expandedGroupLayout;
		this.collapsedGroupLayout = collapsedGroupLayout;
		this.childLayout = childLayout;

		inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
		contentResolver = context.getContentResolver();

		folderCursorHelper = new MyCursorHelper(folderCursor);
		mChildrenCursorHelpers = new SparseArray<MyCursorHelper>();

		//itemCount += folderCursor.getCount() + blogCursor.getCount();
		init(groupFrom, groupTo, childFrom, childTo);
	}

	private void init(final String[] groupFromNames, final int[] groupTo, final String[] childFromNames, final int[] childTo) {
		this.groupTo = groupTo;
		this.childTo = childTo;

		initGroupFromColumns(groupFromNames);

		if (getGroupCount() > 0) {
			MyCursorHelper tmpCursorHelper = getChildrenCursorHelper(0, true);
			if (tmpCursorHelper != null) {
				initChildrenFromColumns(childFromNames, tmpCursorHelper.getCursor());
				deactivateChildrenCursorHelper(0);
			}
		}
	}

	public void setViewBinder(final ViewBinder viewBinder) {
		this.viewBinder = viewBinder;
	}

	private void initFromColumns(Cursor cursor, String[] fromColumnNames, int[] fromColumns) {
		for (int i = fromColumnNames.length - 1; i >= 0; i--) {
			fromColumns[i] = cursor.getColumnIndexOrThrow(fromColumnNames[i]);
		}
	}

	private void initGroupFromColumns(String[] groupFromNames) {
		groupFrom = new int[groupFromNames.length];
		initFromColumns(folderCursorHelper.getCursor(), groupFromNames, groupFrom);
	}

	private void initChildrenFromColumns(String[] childFromNames, Cursor childCursor) {
		childFrom = new int[childFromNames.length];
		initFromColumns(childCursor, childFromNames, childFrom);
	}

	protected Cursor getChildrenCursor(Cursor folderCursor) {
		final Folder parentFolder = Folder.fromCursor(folderCursor);
		Uri uri = null;
		uri = FeedProvider.FEED_FOLDER_MAP_URI.buildUpon().appendPath(parentFolder.getName()).build();
		return contentResolver.query(uri, null, null, new String[] { currentState }, null);
	}


	@Override
	public Cursor getChild(int groupPosition, int childPosition) {
		return getChildrenCursorHelper(groupPosition, true).moveTo(childPosition);
	}

	@Override
	public long getChildId(int groupPosition, int childPosition) {
		return 0;
	}

	@Override
	public View getChildView(int groupPosition, int childPosition, boolean isLastChild, View convertView, ViewGroup parent) {
		MyCursorHelper cursorHelper = getChildrenCursorHelper(groupPosition, true);

		Cursor cursor = cursorHelper.moveTo(childPosition);
		if (cursor == null) {
			throw new IllegalStateException("this should only be called when the cursor is valid");
		}

		View v;
		if (convertView == null) {
			v = newChildView(context, cursor, isLastChild, parent);
		} else {
			v = convertView;
		}
		bindChildView(v, context, cursor, isLastChild);
		return v;
	}

	@Override
	public int getChildrenCount(int groupPosition) {
		MyCursorHelper helper = getChildrenCursorHelper(groupPosition, true);
		return (folderCursorHelper.isValid() && helper != null) ? helper.getCount() : 0;
	}

	public View newChildView(Context context, Cursor cursor, boolean isLastChild, ViewGroup parent) {
		return inflater.inflate(childLayout, parent, false);
	}

	@Override
	public Cursor getGroup(int groupPosition) {
		return folderCursorHelper.moveTo(groupPosition);
	}

	@Override
	public int getGroupCount() {
		return folderCursorHelper.getCount();
	}

	@Override
	public long getGroupId(int groupPosition) {
		return folderCursorHelper.getId(groupPosition);
	}

	public void setGroupCursor(Cursor cursor) {
		folderCursorHelper.changeCursor(cursor, false);
	}

	@Override
	public View getGroupView(int groupPosition, boolean isExpanded, View convertView, ViewGroup parent) {
		Cursor cursor = folderCursorHelper.moveTo(groupPosition);
		if (cursor == null) {
			throw new IllegalStateException("this should only be called when the cursor is valid");
		}

		View v;
		if (convertView == null) {
			v = newGroupView(context, cursor, isExpanded, parent);
		} else {
			v = convertView;
		}
		bindGroupView(v, context, cursor, isExpanded);
		return v;
	}

	private View newGroupView(Context context, Cursor cursor, boolean isExpanded, ViewGroup parent) {
		return inflater.inflate((isExpanded) ? expandedGroupLayout : collapsedGroupLayout, parent, false);
	}

	@Override
	public boolean hasStableIds() {
		return true;
	}

	@Override
	public boolean isChildSelectable(int groupPosition, int childPosition) {
		return false;
	}




	//-----------------------

	protected void bindChildView(View view, Context context, Cursor cursor, boolean isLastChild) {
		bindView(view, context, cursor, childFrom, childTo);
	}

	protected void bindGroupView(View view, Context context, Cursor cursor, boolean isExpanded) {
		bindView(view, context, cursor, groupFrom, groupTo);
	}

	private void bindView(View view, Context context, Cursor cursor, int[] from, int[] to) {
		final ViewBinder binder = viewBinder;

		for (int i = 0; i < to.length; i++) {
			View v = view.findViewById(to[i]);
			if (v != null) {
				boolean bound = false;
				if (binder != null) {
					bound = binder.setViewValue(v, cursor, from[i]);
				}

				if (!bound) {
					String text = cursor.getString(from[i]);
					if (text == null) {
						text = "";
					}
					if (v instanceof TextView) {
						((TextView) v).setText(text);
					} else if (v instanceof ImageView) {
						setViewImage((ImageView) v, text);
					} else {
						throw new IllegalStateException("SimpleCursorTreeAdapter can bind values" +
						" only to TextView and ImageView!");
					}
				}
			}
		}
	}

	synchronized void deactivateChildrenCursorHelper(int groupPosition) {
		MyCursorHelper cursorHelper = getChildrenCursorHelper(groupPosition, true);
		mChildrenCursorHelpers.remove(groupPosition);
		cursorHelper.deactivate();
	}

	synchronized MyCursorHelper getChildrenCursorHelper(int groupPosition, boolean requestCursor) {
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
		}
		super.notifyDataSetChanged();
	}
	
	public void requery() {
		folderCursorHelper.getCursor().requery();
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
					return mCursor.getLong(mRowIDColumn);
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
				// notify the observers about the new cursor
				notifyDataSetChanged(releaseCursors);
			} else {
				mRowIDColumn = -1;
				mDataValid = false;
				// notify the observers about the lack of a data set
				notifyDataSetInvalidated();
			}
		}

		void deactivate() {
			if (mCursor == null) {
				return;
			}

			mCursor.unregisterContentObserver(mContentObserver);
			mCursor.unregisterDataSetObserver(mDataSetObserver);
			mCursor.deactivate();
			mCursor = null;
		}

		boolean isValid() {
			return mDataValid && mCursor != null;
		}

		private class MyContentObserver extends ContentObserver {
			public MyContentObserver() {
				super(mHandler);
			}

			@Override
			public boolean deliverSelfNotifications() {
				return true;
			}

			@Override
			public void onChange(boolean selfChange) {
				if (mAutoRequery && mCursor != null) {
					if (Config.LOGV) Log.v("Cursor", "Auto requerying " + mCursor +
					" due to update");
					mDataValid = mCursor.requery();
				}
			}
		}

		private class MyDataSetObserver extends DataSetObserver {
			@Override
			public void onChanged() {
				mDataValid = true;
				notifyDataSetChanged();
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
