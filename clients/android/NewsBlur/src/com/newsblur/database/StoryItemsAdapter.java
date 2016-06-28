package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.Typeface;
import android.text.Html;
import android.text.TextUtils;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.SimpleCursorAdapter;

import java.util.Date;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.domain.Story;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryUtils;

/**
 * Story list adapter. Uses SimpleCursorAdapter behaviour for text elements and custom
 * bindings to handle images and visual tweaks like read stories being de-emphasized.
 */
public class StoryItemsAdapter extends SimpleCursorAdapter {

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

    private final Context context;
    private boolean ignoreReadStatus;
    private boolean ignoreIntel;
    private boolean singleFeed;

	public StoryItemsAdapter(Context context, Cursor c, boolean ignoreReadStatus, boolean ignoreIntel, boolean singleFeed) {
		super(context, R.layout.row_story, c, COL_NAME_MAPPINGS, RES_ID_MAPPINGS, 0);

        cursor = c;

        this.context = context;

        this.ignoreReadStatus = ignoreReadStatus;
        this.ignoreIntel = ignoreIntel;
        this.singleFeed = singleFeed;

        this.setViewBinder(new StoryItemViewBinder());
	}

	@Override
	public int getCount() {
		return cursor.getCount();
	}

	@Override
	public Cursor swapCursor(Cursor c) {
		this.cursor = c;
		return super.swapCursor(c);
	}

	public Story getStory(int position) {
        cursor.moveToPosition(position);
        return Story.fromCursor(cursor);
    }

	@Override
	public void bindView(View v, Context context, Cursor cursor) {
        super.bindView(v, context, cursor);

        // lists with mixed feeds get added info, but single feeds do not
        if (!singleFeed) {
            String faviconUrl = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_URL));
            FeedUtils.imageLoader.displayImage(faviconUrl, ((ImageView) v.findViewById(R.id.row_item_feedicon)), false);
            ((TextView) v.findViewById(R.id.row_item_feedtitle)).setText(cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_TITLE)));
        } else {
            v.findViewById(R.id.row_item_feedicon).setVisibility(View.GONE);
            v.findViewById(R.id.row_item_feedtitle).setVisibility(View.GONE);
        }

        // leftbar colour
		View borderOne = v.findViewById(R.id.row_item_favicon_borderbar_1);
		View borderTwo = v.findViewById(R.id.row_item_favicon_borderbar_2);
        String feedColor = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_BORDER));
        String feedFade = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOR));
        if (!TextUtils.equals(feedColor, "#null") && !TextUtils.equals(feedFade, "#null")) {
            borderOne.setBackgroundColor(Color.parseColor(feedColor));
            borderTwo.setBackgroundColor(Color.parseColor(feedFade));
        } else {
            borderOne.setBackgroundColor(Color.GRAY);
            borderTwo.setBackgroundColor(Color.LTGRAY);
        }
		
        Story story = Story.fromCursor(cursor);

		if (this.ignoreReadStatus || (! story.read)) {
            v.findViewById(R.id.row_item_title).setAlpha(1.0f);
			v.findViewById(R.id.row_item_feedtitle).setAlpha(1.0f);
            v.findViewById(R.id.row_item_author).setAlpha(1.0f);
            v.findViewById(R.id.row_item_date).setAlpha(1.0f);
            v.findViewById(R.id.row_item_content).setAlpha(1.0f);

			((TextView) v.findViewById(R.id.row_item_title)).setTypeface(null, Typeface.BOLD);

			((ImageView) v.findViewById(R.id.row_item_feedicon)).setImageAlpha(255);
			((ImageView) v.findViewById(R.id.row_item_inteldot)).setImageAlpha(255);
			borderOne.getBackground().setAlpha(255);
			borderTwo.getBackground().setAlpha(255);
		} else {
            v.findViewById(R.id.row_item_title).setAlpha(READ_STORY_ALPHA);
            v.findViewById(R.id.row_item_feedtitle).setAlpha(READ_STORY_ALPHA);
            v.findViewById(R.id.row_item_author).setAlpha(READ_STORY_ALPHA);
            v.findViewById(R.id.row_item_date).setAlpha(READ_STORY_ALPHA);
            v.findViewById(R.id.row_item_content).setAlpha(READ_STORY_ALPHA);

            ((TextView) v.findViewById(R.id.row_item_title)).setTypeface(null, Typeface.NORMAL);

			((ImageView) v.findViewById(R.id.row_item_feedicon)).setImageAlpha(READ_STORY_ALPHA_B255);
			((ImageView) v.findViewById(R.id.row_item_inteldot)).setImageAlpha(READ_STORY_ALPHA_B255);
			borderOne.getBackground().setAlpha(READ_STORY_ALPHA_B255);
			borderTwo.getBackground().setAlpha(READ_STORY_ALPHA_B255);
		}

        if (story.starred) {
            v.findViewById(R.id.row_item_saved_icon).setVisibility(View.VISIBLE);
        } else {
            v.findViewById(R.id.row_item_saved_icon).setVisibility(View.GONE);
        }

        if (!PrefsUtils.isShowContentPreviews(context)) {
            v.findViewById(R.id.row_item_content).setVisibility(View.GONE);
        }
	}

    class StoryItemViewBinder implements ViewBinder {

        @Override
        public boolean setViewValue(View view, Cursor cursor, int columnIndex) {
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
                ((TextView) view).setText(Html.fromHtml(cursor.getString(columnIndex)));
                return true;
            } else if (TextUtils.equals(columnName, DatabaseConstants.STORY_TIMESTAMP)) {
                ((TextView) view).setText(StoryUtils.formatShortDate(context, new Date(cursor.getLong(columnIndex))));
                return true;
            }
            
            return false;
        }

    }

}

