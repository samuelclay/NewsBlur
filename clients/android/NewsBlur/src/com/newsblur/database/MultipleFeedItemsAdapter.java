package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.Typeface;
import android.text.TextUtils;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.Story;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ThemeUtils;
import com.newsblur.util.UIUtils;

public class MultipleFeedItemsAdapter extends StoryItemsAdapter {

	private int storyContentUnread, storyAuthorUnread, storyContentRead, storyAuthorRead, storyDateUnread, storyDateRead;
    private boolean ignoreReadStatus;

	public MultipleFeedItemsAdapter(Context context, int layout, Cursor c, String[] from, int[] to, boolean ignoreReadStatus) {
		super(context, layout, c, from, to);

        storyContentUnread = ThemeUtils.getStoryContentUnreadColor(context);
        storyContentRead = ThemeUtils.getStoryContentReadColor(context);
        storyAuthorUnread = ThemeUtils.getStoryAuthorUnreadColor(context);
        storyAuthorRead = ThemeUtils.getStoryAuthorReadColor(context);
        storyDateUnread = ThemeUtils.getStoryDateUnreadColor(context);
        storyDateRead = ThemeUtils.getStoryDateReadColor(context);

        this.ignoreReadStatus = ignoreReadStatus;
	}

    public MultipleFeedItemsAdapter(Context context, int layout, Cursor c, String[] from, int[] to) {
        this(context, layout, c, from, to, false);
    }

	@Override
	public void bindView(final View v, Context context, Cursor cursor) {
        super.bindView(v, context, cursor);
        
		View borderOne = v.findViewById(R.id.row_item_favicon_borderbar_1);
		View borderTwo = v.findViewById(R.id.row_item_favicon_borderbar_2);

		String feedColor = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_BORDER));
        String feedFade = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOR));

		String faviconUrl = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_URL));
		FeedUtils.imageLoader.displayImage(faviconUrl, ((ImageView) v.findViewById(R.id.row_item_feedicon)), false);

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

			((TextView) v.findViewById(R.id.row_item_author)).setTextColor(storyAuthorUnread);
			((TextView) v.findViewById(R.id.row_item_date)).setTextColor(storyDateUnread);
            ((TextView) v.findViewById(R.id.row_item_content)).setTextColor(storyContentUnread);
			
			((TextView) v.findViewById(R.id.row_item_feedtitle)).setTypeface(null, Typeface.BOLD);
			((TextView) v.findViewById(R.id.row_item_date)).setTypeface(null, Typeface.BOLD);
			((TextView) v.findViewById(R.id.row_item_author)).setTypeface(null, Typeface.BOLD);
			((TextView) v.findViewById(R.id.row_item_title)).setTypeface(null, Typeface.BOLD);

			UIUtils.setImageViewAlpha(((ImageView) v.findViewById(R.id.row_item_feedicon)), 255);
			borderOne.getBackground().setAlpha(255);
			borderTwo.getBackground().setAlpha(255);
		} else {
            v.findViewById(R.id.row_item_title).setAlpha(0.5f);
            v.findViewById(R.id.row_item_feedtitle).setAlpha(0.5f);

			((TextView) v.findViewById(R.id.row_item_author)).setTextColor(storyAuthorRead);
			((TextView) v.findViewById(R.id.row_item_date)).setTextColor(storyDateRead);
            ((TextView) v.findViewById(R.id.row_item_content)).setTextColor(storyContentRead);
			
			((TextView) v.findViewById(R.id.row_item_feedtitle)).setTypeface(null, Typeface.NORMAL);
			((TextView) v.findViewById(R.id.row_item_date)).setTypeface(null, Typeface.NORMAL);
			((TextView) v.findViewById(R.id.row_item_author)).setTypeface(null, Typeface.NORMAL);
            ((TextView) v.findViewById(R.id.row_item_title)).setTypeface(null, Typeface.NORMAL);
            ((TextView) v.findViewById(R.id.row_item_content)).setTypeface(null, Typeface.NORMAL);

			UIUtils.setImageViewAlpha(((ImageView) v.findViewById(R.id.row_item_feedicon)), 96);
			borderOne.getBackground().setAlpha(96);
			borderTwo.getBackground().setAlpha(96);
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
	
}
