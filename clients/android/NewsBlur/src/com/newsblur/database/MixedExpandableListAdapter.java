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

    private enum GroupType { ALL_SHARED_STORIES, ALL_STORIES, FOLDER, SAVED_STORIES }
    private enum ChildType { BLOG, FEED }

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
	private Cursor allStoriesCountCursor, sharedStoriesCountCursor, savedStoriesCountCursor;

	public MixedExpandableListAdapter(final Context context, final Cursor folderCursor, final Cursor blogCursor, final Cursor countCursor, final Cursor sharedCountCursor, final Cursor savedStoriesCountCursor) {

		this.context = context;
		this.allStoriesCountCursor = countCursor;
		this.sharedStoriesCountCursor = sharedCountCursor;
        this.savedStoriesCountCursor = savedStoriesCountCursor;

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
		return contentResolver.query(uri, null, null, new String[] { DatabaseConstants.getFeedSelectionFromState(currentState) }, null);
	}

    /*
     * This next four methods are used by the framework to decide which views can
     * be recycled when calling getChildView and getGroupView.
     */

	@Override
	public int getGroupType(int groupPosition) {
		if (groupPosition == 0) {
			return GroupType.ALL_SHARED_STORIES.ordinal();
		} else if (isFolderRoot(groupPosition)) {
            return GroupType.ALL_STORIES.ordinal();
        } else if (isRowSavedStories(groupPosition)) {
            return GroupType.SAVED_STORIES.ordinal();
        } else {
			return GroupType.FOLDER.ordinal();
		}
	}

    @Override
	public int getChildType(int groupPosition, int childPosition) {
		if (groupPosition == 0) {
			return ChildType.BLOG.ordinal();
		} else {
			return ChildType.FEED.ordinal();
		}
	}

	@Override
	public int getGroupTypeCount() {
		return GroupType.values().length;
	}

	@Override
	public int getChildTypeCount() {
		return ChildType.values().length;
	}

	@Override
	public Cursor getChild(int groupPosition, int childPosition) {
		if (groupPosition == 0) {
			blogCursorHelper.moveTo(childPosition);
			return blogCursorHelper.getCursor();
        } else {
			groupPosition = groupPosition - 1;
			return getChildrenCursorHelper(groupPosition).moveTo(childPosition);
		}
	}

	@Override
    public long getChildId(int groupPosition, int childPosition) {
		if (groupPosition == 0) {
			return blogCursorHelper.getId(childPosition);
		} else {
			MyCursorHelper childrenCursorHelper = getChildrenCursorHelper(groupPosition - 1);
			return childrenCursorHelper.getId(childPosition);
		}
	}

	@Override
	public View getChildView(int groupPosition, int childPosition, boolean isLastChild, View convertView, ViewGroup parent) {
		View v;
		if (groupPosition == 0) {
			blogCursorHelper.moveTo(childPosition);
			if (convertView == null) {
                v = inflater.inflate(R.layout.row_socialfeed, parent, false);
			} else {
				v = convertView;
			}
			bindBlogView(v, context, blogCursorHelper.getCursor());
		} else {
			groupPosition = groupPosition - 1;
			MyCursorHelper cursorHelper = getChildrenCursorHelper(groupPosition);
			Cursor cursor = cursorHelper.moveTo(childPosition);
			if (cursor == null) {
				throw new IllegalStateException("This should only be called when the cursor is valid");
			}
			if (convertView == null) {
				v = inflater.inflate(R.layout.row_feed, parent, false);
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
        } else if (isRowSavedStories(groupPosition)) {
            return 0; // this row never has children
		} else {
			groupPosition = groupPosition - 1;
			MyCursorHelper helper = getChildrenCursorHelper(groupPosition);
			return (folderCursorHelper.isValid() && helper != null) ? helper.getCount() : 0;
		}
	}

	@Override
	public Cursor getGroup(int groupPosition) {
		return folderCursorHelper.moveTo(groupPosition - 1);
	}

	public Cursor getBlogCursor(int childPosition) {
		return blogCursorHelper.moveTo(childPosition);
	}

	@Override
	public int getGroupCount() {
        // in addition to the real folders returned by the /reader/feeds API, there are virtual folders
        // for social feeds and saved stories
		return (folderCursorHelper.getCount() + 2);
	}

	@Override
	public long getGroupId(int groupPosition) {
		if (groupPosition == 0) {
            // the social folder doesn't have an ID, so just give it a really huge one
            return Long.MAX_VALUE;
        } else if (isRowSavedStories(groupPosition)) {
            // neither does the saved stories row, give it another
            return (Long.MAX_VALUE-1);
        } else {
			return folderCursorHelper.getId(groupPosition-1);
		}
	}
	
	public String getGroupName(int groupPosition) {
        // these "names" aren't actually what is used to render the row, but are used
        // internally for tracking row identity to save preferences
		if (groupPosition == 0) {
			return "[ALL_SHARED_STORIES]";
		} else if (isRowSavedStories(groupPosition)) {
            return "[SAVED_STORIES]";
        } else {
			Cursor cursor = folderCursorHelper.getCursor();
			cursor.moveToPosition(groupPosition-1);
			return cursor.getString(cursor.getColumnIndex("folder_name"));
		}
	}

    /**
     * Determines if the folder at the specified position is the special "root" folder.  This
     * folder is returned by the API in a special way and the APIManager ensures it gets a
     * specific name in the DB so we can find it.
     */
    public boolean isFolderRoot(int groupPosition) {
        return ( getGroupName(groupPosition).equals(AppConstants.ROOT_FOLDER) );
    }

    /**
     * Determines if the row at the specified position is the special "saved" folder. This
     * row doesn't actually correspond to a row in the DB, much like the social row, but
     * it is located at the bottom of the set rather than the top.
     */
    public boolean isRowSavedStories(int groupPosition) {
        return ( groupPosition > folderCursorHelper.getCursor().getCount() );
    }

	public void setGroupCursor(Cursor cursor) {
		folderCursorHelper.changeCursor(cursor);
	}

	public void setBlogCursor(Cursor blogCursor) {
		blogCursorHelper.changeCursor(blogCursor);
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
		} else if (isFolderRoot(groupPosition)) {
            // the special "root" folder gets a unique layout and behaviour
			cursor = allStoriesCountCursor;
			v =  inflater.inflate(R.layout.row_all_stories, null, false);
			allStoriesCountCursor.moveToFirst();
			switch (currentState) {
				case AppConstants.STATE_BEST:
					v.findViewById(R.id.row_foldersumneu).setVisibility(View.GONE);
					v.findViewById(R.id.row_foldersumpos).setVisibility(View.VISIBLE);
					((TextView) v.findViewById(R.id.row_foldersumpos)).setText(allStoriesCountCursor.getString(allStoriesCountCursor.getColumnIndex(DatabaseConstants.SUM_POS)));
					break;
				default:
					v.findViewById(R.id.row_foldersumneu).setVisibility(View.VISIBLE);
                    if (TextUtils.equals("0", allStoriesCountCursor.getString(allStoriesCountCursor.getColumnIndex(DatabaseConstants.SUM_POS)))) {
                        v.findViewById(R.id.row_foldersumpos).setVisibility(View.GONE);
                    } else {
                        v.findViewById(R.id.row_foldersumpos).setVisibility(View.VISIBLE);
                    }
					((TextView) v.findViewById(R.id.row_foldersumneu)).setText(allStoriesCountCursor.getString(allStoriesCountCursor.getColumnIndex(DatabaseConstants.SUM_NEUT)));
					((TextView) v.findViewById(R.id.row_foldersumpos)).setText(allStoriesCountCursor.getString(allStoriesCountCursor.getColumnIndex(DatabaseConstants.SUM_POS)));
					break;
			}
        } else if (isRowSavedStories(groupPosition)) {
            if (convertView != null) {
                // row never changes, re-use it it exists
                v = convertView;
            } else {
                v = inflater.inflate(R.layout.row_saved_stories, null, false);
            }
            savedStoriesCountCursor.moveToFirst();
            String savedStoriesCount = "0";
            if (savedStoriesCountCursor.getCount() > 0) {
                savedStoriesCount = savedStoriesCountCursor.getString(savedStoriesCountCursor.getColumnIndex(DatabaseConstants.STARRED_STORY_COUNT_COUNT));
            }
            ((TextView) v.findViewById(R.id.row_foldersum)).setText(savedStoriesCount);
		} else {
			cursor = folderCursorHelper.moveTo(groupPosition - 1);
			if (convertView == null) {
                // TODO: this code suggests that there was to be an alternate layout for collapsed folders, but it uses the same one either way?
				v = inflater.inflate((isExpanded) ? R.layout.row_folder_collapsed : R.layout.row_folder_collapsed, parent, false);
			} else {
				v = convertView;
			}
			bindGroupView(v, context, cursor, isExpanded);
		}

		return v;
	}

	@Override
	public boolean hasStableIds() {
		return true;
	}

	@Override
	public boolean isChildSelectable(int groupPosition, int childPosition) {
		return true;
	}

	private void bindChildView(View view, Context context, Cursor cursor, boolean isLastChild) {
        if (this.childColumnMap == null) {
            // work-around: if the adapter was created before we had a DB, it may have been
            // incompletely initialized.  Re-do it!
            initColumnMaps();
        }
		bindView(view, context, cursor, this.childColumnMap, groupViewBinder);
	}

	private void bindGroupView(View view, Context context, Cursor cursor, boolean isExpanded) {
		bindView(view, context, cursor, this.groupColumnMap, groupViewBinder);
		view.findViewById(R.id.row_foldersums).setVisibility(isExpanded ? View.INVISIBLE : View.VISIBLE);
        ImageView folderIconView = ((ImageView) view.findViewById(R.id.row_folder_icon));
        if ( folderIconView != null ) {
		    folderIconView.setImageResource(isExpanded ? R.drawable.g_icn_folder : R.drawable.g_icn_folder_rss);
        }
        ImageView folderIndicatorView = ((ImageView) view.findViewById(R.id.row_folder_indicator));
        if ( folderIndicatorView != null ) {
		    folderIndicatorView.setImageResource(isExpanded ? R.drawable.indicator_expanded : R.drawable.indicator_collapsed);
        }
	}

	private void bindBlogView(View view, Context context, Cursor cursor) {
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

	// This is synchronized with the process of resetting cursors, since it uses
    // lazy init.
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

	@Override
	public void notifyDataSetChanged() {
        // TODO: it probably isn't necessary to fully requery on every dataset change. a more
        // granular set of refresh options might significantly speed up rendering on slow devices
	    this.requery();
		super.notifyDataSetChanged();
	}

    @Override
    public void notifyDataSetInvalidated() {
        super.notifyDataSetInvalidated();
        this.requery();
    }

    // TODO: the requery() method on cursors is deprecated.  This class needs a way
    //  to re-create all cursors via the original means used to make them.
	private synchronized void requery() {
		folderCursorHelper.getCursor().requery();
		blogCursorHelper.getCursor().requery();
		allStoriesCountCursor.requery();
		sharedStoriesCountCursor.requery();
        savedStoriesCountCursor.requery();
		// no, SparseArrays really aren't Interable!
        for (int i = 0; i < mChildrenCursorHelpers.size(); i++) {
			mChildrenCursorHelpers.valueAt(i).deactivate();
		}
		mChildrenCursorHelpers.clear();
	}

	class MyCursorHelper {
		private Cursor mCursor;
		private boolean mDataValid;
		private int mRowIDColumn;

		MyCursorHelper(Cursor cursor) {
			final boolean cursorPresent = cursor != null;
			mCursor = cursor;
			mDataValid = cursorPresent;
			mRowIDColumn = cursorPresent ? cursor.getColumnIndex("_id") : -1;
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

		void changeCursor(Cursor cursor) {
			if (cursor == mCursor) return;

			deactivate();
			mCursor = cursor;
			if (cursor != null) {
				mRowIDColumn = cursor.getColumnIndex("_id");
				mDataValid = true;
				notifyDataSetChanged();
			} else {
				mRowIDColumn = -1;
				mDataValid = false;
				notifyDataSetChanged();
			}
		}

		void deactivate() {
			if (mCursor == null) {
				return;
			}
			mCursor.close();
			mCursor.deactivate();
			mCursor = null;
		}

		boolean isValid() {
			return mDataValid && mCursor != null;
		}

	}

	private void setViewImage(ImageView v, String value) {
		try {
			v.setImageResource(Integer.parseInt(value));
		} catch (NumberFormatException nfe) {
			v.setImageURI(Uri.parse(value));
		}
	}

}
