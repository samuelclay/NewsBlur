package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.Typeface;
import android.text.TextUtils;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.SimpleCursorAdapter;

import java.util.Date;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryUtils;
import com.newsblur.util.UIUtils;

/**
 * Story list adapter. Uses SimpleCursorAdapter behaviour for text elements and custom
 * bindings to handle images and visual tweaks like read stories being de-emphasized.
 */
public class StoryItemsAdapter extends SimpleCursorAdapter {
    
    private final static float defaultTextSize_row_item_title = 14f;
    private final static float defaultTextSize_row_item_feedtitle = 13f;
    private final static float defaultTextSize_row_item_date = 11f;
    private final static float defaultTextSize_row_item_author = 11f;
    private final static float defaultTextSize_row_item_content = 12f;

    private final static String[] COL_NAME_MAPPINGS = new String[] {
        DatabaseConstants.STORY_TITLE, 
        DatabaseConstants.STORY_SHORT_CONTENT, 
        DatabaseConstants.STORY_AUTHORS, 
        DatabaseConstants.STORY_TIMESTAMP, 
        DatabaseConstants.STORY_INTELLIGENCE_TOTAL, 
    };
    private final static int[] RES_ID_MAPPINGS = new int[] {
        R.id.row_item_title, 
        R.id.row_item_content, 
        R.id.row_item_author, 
        R.id.row_item_date, 
        R.id.row_item_inteldot, 
    };

    private final static float READ_STORY_ALPHA = 0.4f;
    private final static int READ_STORY_ALPHA_B255 = (int) (255f * READ_STORY_ALPHA);

	protected Cursor cursor;
    private boolean showNone = false;

    private final Context context;
    private boolean ignoreReadStatus;
    private boolean ignoreIntel;
    private boolean singleFeed;
    private float textSize;
	private UserDetails user;

	public StoryItemsAdapter(Context context, Cursor c, boolean ignoreReadStatus, boolean ignoreIntel, boolean singleFeed) {
		super(context, R.layout.row_story, c, COL_NAME_MAPPINGS, RES_ID_MAPPINGS, 0);

        cursor = c;

        this.context = context;

        this.ignoreReadStatus = ignoreReadStatus;
        this.ignoreIntel = ignoreIntel;
        this.singleFeed = singleFeed;

        textSize = PrefsUtils.getListTextSize(context);

		user = PrefsUtils.getUserDetails(context);

        this.setViewBinder(new StoryItemViewBinder());
	}

	@Override
	public synchronized int getCount() {
        if (showNone) return 0;
		return cursor.getCount();
	}

    public synchronized boolean isStale() {
        return cursor.isClosed();
    }

	@Override
	public synchronized Cursor swapCursor(Cursor c) {
		this.cursor = c;
		return super.swapCursor(c);
	}

    public synchronized void setShowNone(boolean showNone) {
        this.showNone = showNone;
    }

	public synchronized Story getStory(int position) {
		if (cursor == null || cursor.isClosed() || cursor.getColumnCount() == 0 || position >= cursor.getCount() || position < 0) {
			return null;
		} else {
            cursor.moveToPosition(position);
            return Story.fromCursor(cursor);
        }
    }

    public void setTextSize(float textSize) {
        this.textSize = textSize;
    }

    @Override
    public synchronized long getItemId(int position) {
        if (cursor == null || cursor.isClosed() || cursor.getColumnCount() == 0 || position >= cursor.getCount() || position < 0) return 0;
        try {
            return super.getItemId(position);
        } catch (IllegalStateException ise) {
            // despite all the checks above, this can still async fail if the curor is closed by the loader outside of our control
            return 0;
        }
    }

    @Override
    public synchronized View getView(int position, View convertView, ViewGroup parent) {
        if (cursor == null || cursor.isClosed() || cursor.getColumnCount() == 0 || position >= cursor.getCount() || position < 0) return new View(context);
        try {
            return super.getView(position, convertView, parent);
        } catch (IllegalStateException ise) {
            // despite all the checks above, this can still async fail if the curor is closed by the loader outside of our control
            return new View(context);
        }
    }

	@Override
	public synchronized void bindView(View v, Context context, Cursor cursor) {
        // see if this is a valid view for us to bind
        if (v.findViewById(R.id.row_item_title) == null) {
            com.newsblur.util.Log.w(this, "asked to bind wrong type of view");
            return;
        }
        super.bindView(v, context, cursor);

        TextView itemTitle = (TextView) v.findViewById(R.id.row_item_title);
        TextView itemFeedTitle = (TextView) v.findViewById(R.id.row_item_feedtitle);
        TextView itemAuthor = (TextView) v.findViewById(R.id.row_item_author);
        TextView itemDate = (TextView) v.findViewById(R.id.row_item_date);
        TextView itemContent = (TextView) v.findViewById(R.id.row_item_content);

        // lists with mixed feeds get added info, but single feeds do not
        if (!singleFeed) {
            String faviconUrl = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_URL));
            FeedUtils.iconLoader.displayImage(faviconUrl, ((ImageView) v.findViewById(R.id.row_item_feedicon)), 0, false);
            ((TextView) v.findViewById(R.id.row_item_feedtitle)).setText(cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_TITLE)));
        } else {
            v.findViewById(R.id.row_item_feedicon).setVisibility(View.GONE);
            v.findViewById(R.id.row_item_feedtitle).setVisibility(View.GONE);
        }

        // leftbar colour
		View borderOne = v.findViewById(R.id.row_item_favicon_borderbar_1);
		View borderTwo = v.findViewById(R.id.row_item_favicon_borderbar_2);
        String feedColor = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOR));
        String feedFade = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_FADE));
        int feedColorVal = Color.GRAY;
        int feedFadeVal = Color.LTGRAY;
        if ((feedColor == null) ||
            (feedFade == null) ||
            TextUtils.equals(feedColor, "null") ||
            TextUtils.equals(feedFade, "null")) {
            // feed didn't supply color info, leave at default grey
        } else {
            try {
                feedColorVal = Color.parseColor("#" + feedColor);
                feedFadeVal = Color.parseColor("#" + feedFade);
            } catch (NumberFormatException nfe) {
                com.newsblur.util.Log.e(this, "feed supplied bad color info: " + nfe.getMessage());
            }
        }
        borderOne.setBackgroundColor(feedColorVal);
        borderTwo.setBackgroundColor(feedFadeVal);

        // dynamic text sizing
        itemTitle.setTextSize(textSize * defaultTextSize_row_item_title);
        itemFeedTitle.setTextSize(textSize * defaultTextSize_row_item_feedtitle);
        itemAuthor.setTextSize(textSize * defaultTextSize_row_item_author);
        itemDate.setTextSize(textSize * defaultTextSize_row_item_date);
        itemContent.setTextSize(textSize * defaultTextSize_row_item_content);
		
        // read/unread fading
        Story story = Story.fromCursor(cursor);
		if (this.ignoreReadStatus || (! story.read)) {
            itemTitle.setAlpha(1.0f);
			itemFeedTitle.setAlpha(1.0f);
            itemAuthor.setAlpha(1.0f);
            itemDate.setAlpha(1.0f);
            itemContent.setAlpha(1.0f);

			itemTitle.setTypeface(null, Typeface.BOLD);

			((ImageView) v.findViewById(R.id.row_item_feedicon)).setImageAlpha(255);
			((ImageView) v.findViewById(R.id.row_item_inteldot)).setImageAlpha(255);
			((ImageView) v.findViewById(R.id.row_item_thumbnail)).setImageAlpha(255);
			borderOne.getBackground().setAlpha(255);
			borderTwo.getBackground().setAlpha(255);
		} else {
            itemTitle.setAlpha(READ_STORY_ALPHA);
            itemFeedTitle.setAlpha(READ_STORY_ALPHA);
            itemAuthor.setAlpha(READ_STORY_ALPHA);
            itemDate.setAlpha(READ_STORY_ALPHA);
            itemContent.setAlpha(READ_STORY_ALPHA);

            itemTitle.setTypeface(null, Typeface.NORMAL);

			((ImageView) v.findViewById(R.id.row_item_feedicon)).setImageAlpha(READ_STORY_ALPHA_B255);
			((ImageView) v.findViewById(R.id.row_item_inteldot)).setImageAlpha(READ_STORY_ALPHA_B255);
			((ImageView) v.findViewById(R.id.row_item_thumbnail)).setImageAlpha(READ_STORY_ALPHA_B255);
			borderOne.getBackground().setAlpha(READ_STORY_ALPHA_B255);
			borderTwo.getBackground().setAlpha(READ_STORY_ALPHA_B255);
		}

        if (story.starred) {
            v.findViewById(R.id.row_item_saved_icon).setVisibility(View.VISIBLE);
        } else {
            v.findViewById(R.id.row_item_saved_icon).setVisibility(View.GONE);
        }

        boolean shared = false;
		findshareloop: for (String userId : story.sharedUserIds) {
			if (TextUtils.equals(userId, user.id)) {
				shared = true;
                break findshareloop;
			}
		}
        if (shared) {
            v.findViewById(R.id.row_item_shared_icon).setVisibility(View.VISIBLE);
        } else {
            v.findViewById(R.id.row_item_shared_icon).setVisibility(View.GONE);
        }

        if (!PrefsUtils.isShowContentPreviews(context)) {
            itemContent.setVisibility(View.GONE);
        }


        ImageView thumbnailView = ((ImageView) v.findViewById(R.id.row_item_thumbnail));
        if (PrefsUtils.isShowThumbnails(context)) {
            if (story.thumbnailUrl != null ) {
                thumbnailView.setVisibility(View.VISIBLE);
                if (!FeedUtils.thumbnailLoader.isUrlMapped(thumbnailView, story.thumbnailUrl)) {
                    thumbnailView.setImageDrawable(null);
                    FeedUtils.thumbnailLoader.displayImage(story.thumbnailUrl, thumbnailView, 0, true, 400, true);
                }
            } else {
                // to GONE rather than INVIS makes start titles misalign on the right side, but this is by design
                thumbnailView.setVisibility(View.GONE);
            }
        } else {
            thumbnailView.setVisibility(View.GONE);
        }
	}

    class StoryItemViewBinder implements ViewBinder {

        @Override
        public boolean setViewValue(View view, Cursor cursor, int columnIndex) {
            // some devices keep binding after the loadermanager swaps. fail fast.
            if (cursor.isClosed()) return true;
            try {
                String columnName = cursor.getColumnName(columnIndex);
                if (TextUtils.equals(columnName, DatabaseConstants.STORY_AUTHORS)) {
                    if (TextUtils.isEmpty(cursor.getString(columnIndex))) {
                        view.setVisibility(View.GONE);
                    } else {
                        view.setVisibility(View.VISIBLE);
                        ((TextView) view).setText(cursor.getString(columnIndex).toUpperCase());
                    }
                    return true;
                } else if (TextUtils.equals(columnName, DatabaseConstants.STORY_INTELLIGENCE_TOTAL)) {
                    if (! ignoreIntel) {
                        int score = cursor.getInt(columnIndex);
                        if (score > 0) {
                            ((ImageView) view).setImageResource(R.drawable.g_icn_focus);
                        } else if (score == 0) {
                            ((ImageView) view).setImageResource(R.drawable.g_icn_unread);
                        } else {
                            ((ImageView) view).setImageResource(R.drawable.g_icn_hidden);
                        }
                    } else {
                        ((ImageView) view).setImageResource(android.R.color.transparent);
                    }
                    return true;
                } else if (TextUtils.equals(columnName, DatabaseConstants.STORY_TITLE)) {
                    ((TextView) view).setText(UIUtils.fromHtml(cursor.getString(columnIndex)));
                    return true;
                } else if (TextUtils.equals(columnName, DatabaseConstants.STORY_TIMESTAMP)) {
                    ((TextView) view).setText(StoryUtils.formatShortDate(context, new Date(cursor.getLong(columnIndex))));
                    return true;
                }
            } catch (android.database.StaleDataException sdex) {
                com.newsblur.util.Log.d(getClass().getName(), "view bound after loader reset");
                return true;
            }
            
            return false;
        }

    }

}

