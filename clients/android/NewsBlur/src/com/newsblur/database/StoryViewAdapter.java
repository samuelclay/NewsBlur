package com.newsblur.database;

import android.app.Activity;
import android.content.Context;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.Typeface;
import android.support.v7.widget.RecyclerView;
import android.text.TextUtils;
import android.view.ContextMenu;
import android.view.LayoutInflater;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.SimpleCursorAdapter;

import butterknife.Bind;
import butterknife.ButterKnife;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.fragment.StoryIntelTrainerFragment;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryUtils;
import com.newsblur.util.UIUtils;

/**
 * Story list adapter, RecyclerView style.
 */
public class StoryViewAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    public final static int VIEW_TYPE_STORY = 1;
    public final static int VIEW_TYPE_FOOTER = 2;

    private final static float defaultTextSize_story_item_feedtitle = 13f;
    private final static float defaultTextSize_story_item_title = 14f;
    private final static float defaultTextSize_story_item_date = 12f;

    private final static float READ_STORY_ALPHA = 0.35f;
    private final static int READ_STORY_ALPHA_B255 = (int) (255f * READ_STORY_ALPHA);

    private List<View> footerViews = new ArrayList<View>();
    
    protected Cursor cursor;
    private boolean showNone = false;

    private Activity context;
    private FeedSet fs;
    private boolean ignoreReadStatus;
    private boolean ignoreIntel;
    private boolean singleFeed;
    private float textSize;
    private UserDetails user;

    public StoryViewAdapter(Activity context, FeedSet fs) {
        this.context = context;
        this.fs = fs;
        
        if (fs.isGlobalShared())   {ignoreReadStatus = false; ignoreIntel = true; singleFeed = false;}
        if (fs.isAllSocial())      {ignoreReadStatus = false; ignoreIntel = false; singleFeed = false;}
        if (fs.isAllNormal())      {ignoreReadStatus = false; ignoreIntel = false; singleFeed = false;}
        if (fs.isInfrequent())     {ignoreReadStatus = false; ignoreIntel = false; singleFeed = false;}
        if (fs.isSingleSocial())   {ignoreReadStatus = false; ignoreIntel = false; singleFeed = false;}
        if (fs.isFolder())         {ignoreReadStatus = fs.isFilterSaved(); ignoreIntel = fs.isFilterSaved(); singleFeed = false;}
        if (fs.isSingleNormal())   {ignoreReadStatus = fs.isFilterSaved(); ignoreIntel = fs.isFilterSaved(); singleFeed = true;}
        if (fs.isAllRead())        {ignoreReadStatus = false; ignoreIntel = true; singleFeed = false;}
        if (fs.isAllSaved())       {ignoreReadStatus = true; ignoreIntel = true; singleFeed = false;}
        if (fs.isSingleSavedTag()) {ignoreReadStatus = true; ignoreIntel = true; singleFeed = false;}

        textSize = PrefsUtils.getListTextSize(context);

        user = PrefsUtils.getUserDetails(context);

        setHasStableIds(true);
    }

    public void updateFeedSet(FeedSet fs) {
        this.fs = fs;
    }

    public synchronized void addFooterView(View v) {
        footerViews.add(v);
    }

    @Override
    public synchronized int getItemCount() {
        return (getStoryCount() + footerViews.size());
    }

    public int getStoryCount() {
        if (showNone || (cursor == null)) {
            return 0;
        } else {
            return cursor.getCount();
        }
    }

    @Override
    public int getItemViewType(int position) {
        if (position >= getStoryCount()) return VIEW_TYPE_FOOTER;
        return VIEW_TYPE_STORY;
    }

    @Override
    public synchronized long getItemId(int position) {
        if (position >= getStoryCount()) {
            return (footerViews.get(position - getStoryCount()).hashCode());
        }
        
        if (cursor == null || cursor.isClosed() || cursor.getColumnCount() == 0 || position >= cursor.getCount() || position < 0) return 0;
        cursor.moveToPosition(position);
        return cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_HASH)).hashCode();
    }

    public synchronized boolean isCursorValid() {
        if (cursor == null) return true;
        if (cursor.isClosed()) return false;
        return true;
    }

    public synchronized void swapCursor(Cursor c) {
        this.cursor = c;
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
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup viewGroup, int viewType) {
        if (viewType == VIEW_TYPE_STORY) {
            View v = LayoutInflater.from(viewGroup.getContext()).inflate(R.layout.view_story_tile, viewGroup, false);
            return new StoryViewHolder(v);
        } else {
            View v = LayoutInflater.from(viewGroup.getContext()).inflate(R.layout.view_footer_tile, viewGroup, false);
            return new FooterViewHolder(v);
        }
    }

    public class StoryViewHolder extends RecyclerView.ViewHolder
                                 implements View.OnClickListener, View.OnCreateContextMenuListener, MenuItem.OnMenuItemClickListener {

        @Bind(R.id.story_item_favicon_borderbar_1) View leftBarOne;
        @Bind(R.id.story_item_favicon_borderbar_2) View leftBarTwo;
        @Bind(R.id.story_item_inteldot) ImageView intelDot;
        @Bind(R.id.story_item_thumbnail) ImageView thumbView;
        @Bind(R.id.story_item_feedicon) ImageView feedIconView;
        @Bind(R.id.story_item_feedtitle) TextView feedTitleView;
        @Bind(R.id.story_item_title) TextView storyTitleView;
        @Bind(R.id.story_item_date) TextView storyDate;
        @Bind(R.id.story_item_saved_icon) View savedView;
        @Bind(R.id.story_item_shared_icon) View sharedView;

        Story story;
        ImageLoader.PhotoToLoad thumbLoader;
        String lastThumbUrl;

        public StoryViewHolder(View view) {
            super(view);
            ButterKnife.bind(StoryViewHolder.this, view);
            view.setOnClickListener(StoryViewHolder.this);
            view.setOnCreateContextMenuListener(StoryViewHolder.this);
        }

        @Override
        public void onClick(View view) {
            UIUtils.startReadingActivity(fs, story.storyHash, context);
        }

        @Override
        public void onCreateContextMenu(ContextMenu menu, View v, ContextMenu.ContextMenuInfo menuInfo) {
            MenuInflater inflater = new MenuInflater(context);
            UIUtils.inflateStoryContextMenu(menu, inflater, context, fs, story);
            for (int i=0; i<menu.size(); i++) {
                menu.getItem(i).setOnMenuItemClickListener(StoryViewHolder.this);
            }
        }

        @Override
        public boolean onMenuItemClick (MenuItem item) {
            switch (item.getItemId()) {
            case R.id.menu_mark_story_as_read:
                FeedUtils.markStoryAsRead(story, context);
                return true;

            case R.id.menu_mark_story_as_unread:
                FeedUtils.markStoryUnread(story, context);
                return true;

            case R.id.menu_mark_older_stories_as_read:
                FeedUtils.markRead(context, fs, story.timestamp, null, R.array.mark_older_read_options, false);
                return true;

            case R.id.menu_mark_newer_stories_as_read:
                FeedUtils.markRead(context, fs, null, story.timestamp, R.array.mark_newer_read_options, false);
                return true;

            case R.id.menu_send_story:
                FeedUtils.sendStoryBrief(story, context);
                return true;

            case R.id.menu_send_story_full:
                FeedUtils.sendStoryFull(story, context);
                return true;

            case R.id.menu_save_story:
                FeedUtils.setStorySaved(story, true, context);
                return true;

            case R.id.menu_unsave_story:
                FeedUtils.setStorySaved(story, false, context);
                return true;

            case R.id.menu_intel:
                if (story.feedId.equals("0")) return true; // cannot train on feedless stories
                StoryIntelTrainerFragment intelFrag = StoryIntelTrainerFragment.newInstance(story, fs);
                intelFrag.show(context.getFragmentManager(), StoryIntelTrainerFragment.class.getName());
                return true;

            default:
                return false;
            }
        }
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder viewHolder, int position) {
        if (viewHolder instanceof StoryViewHolder) {
            StoryViewHolder vh = (StoryViewHolder) viewHolder;

            if (cursor == null || cursor.isClosed() || cursor.getColumnCount() == 0 || position >= cursor.getCount() || position < 0) return;
            cursor.moveToPosition(position);

            Story story = Story.fromCursor(cursor);
            vh.story = story;

            // when first created, tiles' views tend to not yet have their dimensions calculated, but
            // upon being recycled they will often have a known size, which lets us give a max size to
            // the image loader, which in turn can massively optimise loading.  the image loader will
            // reject nonsene values
            int thumbSizeGuess = vh.thumbView.getMeasuredHeight();
            // there is a not-unlikely chance that the recycler will re-use a tile for a story with the
            // same thumbnail.  only load it if it is different.
            if (!TextUtils.equals(story.thumbnailUrl, vh.lastThumbUrl)) {
                // the view will display a stale, recycled thumb before the new one loads if the old is not cleared
                vh.thumbView.setImageDrawable(null);
                vh.lastThumbUrl = story.thumbnailUrl;
                vh.thumbLoader = FeedUtils.thumbnailLoader.displayImage(story.thumbnailUrl, vh.thumbView, 0, true, thumbSizeGuess, true);
            }

            String feedColor = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOR));
            String feedFade = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_FADE));
            vh.leftBarOne.setBackgroundColor(UIUtils.decodeColourValue(feedColor, Color.GRAY));
            vh.leftBarTwo.setBackgroundColor(UIUtils.decodeColourValue(feedFade, Color.LTGRAY));

            if (! ignoreIntel) {
                int score = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_TOTAL));
                if (score > 0) {
                    vh.intelDot.setImageResource(R.drawable.g_icn_focus);
                } else if (score == 0) {
                    vh.intelDot.setImageResource(R.drawable.g_icn_unread);
                } else {
                    vh.intelDot.setImageResource(R.drawable.g_icn_hidden);
                }
            } else {
                vh.intelDot.setImageResource(android.R.color.transparent);
            }

            vh.storyTitleView.setText(UIUtils.fromHtml(story.title));
            vh.storyDate.setText(StoryUtils.formatShortDate(context, new Date(story.timestamp)));

            // lists with mixed feeds get added info, but single feeds do not
            if (!singleFeed) {
                String faviconUrl = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_URL));
                FeedUtils.iconLoader.displayImage(faviconUrl, vh.feedIconView, 0, false);
                vh.feedTitleView.setText(cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_TITLE)));
                vh.feedIconView.setVisibility(View.VISIBLE);
                vh.feedTitleView.setVisibility(View.VISIBLE);
            } else {
                vh.feedIconView.setVisibility(View.GONE);
                vh.feedTitleView.setVisibility(View.GONE);
            }

            if (vh.story.starred) {
                vh.savedView.setVisibility(View.VISIBLE);
            } else {
                vh.savedView.setVisibility(View.GONE);
            }

            boolean shared = false;
            findshareloop: for (String userId : story.sharedUserIds) {
                if (TextUtils.equals(userId, user.id)) {
                    shared = true;
                    break findshareloop;
                }
            }
            if (shared) {
                vh.sharedView.setVisibility(View.VISIBLE);
            } else {
                vh.sharedView.setVisibility(View.GONE);
            }

            // dynamic text sizing
            vh.feedTitleView.setTextSize(textSize * defaultTextSize_story_item_feedtitle);
            vh.storyTitleView.setTextSize(textSize * defaultTextSize_story_item_title);
            vh.storyDate.setTextSize(textSize * defaultTextSize_story_item_date);
            
            // read/unread fading
            if (this.ignoreReadStatus || (! story.read)) {
                vh.leftBarOne.getBackground().setAlpha(255);
                vh.leftBarTwo.getBackground().setAlpha(255);
                vh.intelDot.setImageAlpha(255);
                vh.thumbView.setImageAlpha(255);
                vh.feedIconView.setImageAlpha(255);
                vh.feedTitleView.setAlpha(1.0f);
                vh.storyTitleView.setAlpha(1.0f);
                vh.storyDate.setAlpha(1.0f);
            } else {
                vh.leftBarOne.getBackground().setAlpha(READ_STORY_ALPHA_B255);
                vh.leftBarTwo.getBackground().setAlpha(READ_STORY_ALPHA_B255);
                vh.intelDot.setImageAlpha(READ_STORY_ALPHA_B255);
                vh.thumbView.setImageAlpha(READ_STORY_ALPHA_B255);
                vh.feedIconView.setImageAlpha(READ_STORY_ALPHA_B255);
                vh.feedTitleView.setAlpha(READ_STORY_ALPHA);
                vh.storyTitleView.setAlpha(READ_STORY_ALPHA);
                vh.storyDate.setAlpha(READ_STORY_ALPHA);
            }

        } else {
            FooterViewHolder vh = (FooterViewHolder) viewHolder;
            vh.innerView.removeAllViews();
            View targetFooter = footerViews.get(position - getStoryCount());
            ViewParent oldFooterHolder = targetFooter.getParent();
            if (oldFooterHolder instanceof ViewGroup) ((ViewGroup) oldFooterHolder).removeAllViews();
            vh.innerView.addView(targetFooter);
        }

    }

    public class FooterViewHolder extends RecyclerView.ViewHolder {

        @Bind(R.id.footer_view_inner) FrameLayout innerView;

        public FooterViewHolder(View view) {
            super(view);
            ButterKnife.bind(FooterViewHolder.this, view);
        }
    }

    @Override
    public void onViewRecycled(RecyclerView.ViewHolder viewHolder) {
        if (viewHolder instanceof StoryViewHolder) {
            StoryViewHolder vh = (StoryViewHolder) viewHolder;
            if (vh.thumbLoader != null) vh.thumbLoader.cancel = true;
        }
        if (viewHolder instanceof FooterViewHolder) {
            FooterViewHolder vh = (FooterViewHolder) viewHolder;
            vh.innerView.removeAllViews();
        }
    }

}
