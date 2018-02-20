package com.newsblur.database;

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

    private final static float defaultTextSize_story_item_title = 14f;

    private final static float READ_STORY_ALPHA = 0.4f;
    private final static int READ_STORY_ALPHA_B255 = (int) (255f * READ_STORY_ALPHA);

    private List<View> footerViews = new ArrayList<View>();
    
    protected Cursor cursor;
    private boolean showNone = false;

    private Context context;
    private FeedSet fs;
    private boolean ignoreReadStatus;
    private boolean ignoreIntel;
    private boolean singleFeed;
    private float textSize;
    private UserDetails user;

    public StoryViewAdapter(Context context, FeedSet fs) {
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

    public synchronized void addFooterView(View v) {
        footerViews.add(v);
    }

    @Override
    public synchronized int getItemCount() {
        return (getStoryCount() + footerViews.size());
    }

    private int getStoryCount() {
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

    public class StoryViewHolder extends RecyclerView.ViewHolder
                                 implements View.OnClickListener, View.OnCreateContextMenuListener, MenuItem.OnMenuItemClickListener {

        @Bind(R.id.story_item_thumbnail) ImageView thumbView;
        @Bind(R.id.story_item_feedicon) ImageView feedIconView;
        @Bind(R.id.story_item_title) TextView storyTitleView;

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
            com.newsblur.util.Log.d(this, "CLICK: " + story.storyHash);
        }

        @Override
        public void onCreateContextMenu(ContextMenu menu, View v, ContextMenu.ContextMenuInfo menuInfo) {
            com.newsblur.util.Log.d(this, "INFLATE: " + story.storyHash);
            MenuInflater inflater = new MenuInflater(context);
            UIUtils.inflateStoryContextMenu(menu, inflater, context, fs, story);
            for (int i=0; i<menu.size(); i++) {
                menu.getItem(i).setOnMenuItemClickListener(StoryViewHolder.this);
            }
        }

        @Override
        public boolean onMenuItemClick (MenuItem item) {
            com.newsblur.util.Log.d(this, "MENU ITEM CLICK: " + story.storyHash);
            return true;
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
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup viewGroup, int viewType) {
        if (viewType == VIEW_TYPE_STORY) {
            View v = LayoutInflater.from(viewGroup.getContext()).inflate(R.layout.view_story_tile, viewGroup, false);
            return new StoryViewHolder(v);
        } else {
            View v = LayoutInflater.from(viewGroup.getContext()).inflate(R.layout.view_footer_tile, viewGroup, false);
            return new FooterViewHolder(v);
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
            //com.newsblur.util.Log.d(this, "BINDING: " + story.storyHash);

            // when first created, tiles' views tend to not yet have their dimensions calculated, but
            // upon being recycled they will often have a known size, which lets us give a max size to
            // the image loader, which in turn can massively optimise loading.  the image loader will
            // reject nonsene values
            int thumbSizeGuess = vh.thumbView.getMeasuredHeight();

            if (!TextUtils.equals(story.thumbnailUrl, vh.lastThumbUrl)) {
                vh.lastThumbUrl = story.thumbnailUrl;
                vh.thumbView.setImageDrawable(null);
            }
            vh.thumbLoader = FeedUtils.thumbnailLoader.displayImage(story.thumbnailUrl, vh.thumbView, 0, true, thumbSizeGuess);
            vh.storyTitleView.setText(UIUtils.fromHtml(story.title));

            // lists with mixed feeds get added info, but single feeds do not
            if (!singleFeed) {
                String faviconUrl = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_URL));
                FeedUtils.iconLoader.displayImage(faviconUrl, vh.feedIconView, 0, false);
            } else {
                vh.feedIconView.setVisibility(View.GONE);
            }

            // dynamic text sizing
            vh.storyTitleView.setTextSize(textSize * defaultTextSize_story_item_title);
            
            // read/unread fading
            if (this.ignoreReadStatus || (! story.read)) {
                vh.thumbView.setImageAlpha(255);
                vh.feedIconView.setImageAlpha(255);
                vh.storyTitleView.setAlpha(1.0f);
                vh.storyTitleView.setTypeface(null, Typeface.BOLD);
            } else {
                vh.thumbView.setImageAlpha(READ_STORY_ALPHA_B255);
                vh.feedIconView.setImageAlpha(READ_STORY_ALPHA_B255);
                vh.storyTitleView.setAlpha(READ_STORY_ALPHA);
                vh.storyTitleView.setTypeface(null, Typeface.NORMAL);
            }

            /*
            boolean shared = false;
            findshareloop: for (String userId : story.sharedUserIds) {
                if (TextUtils.equals(userId, user.id)) {
                    shared = true;
                    break findshareloop;
                }
            }
            */
        } else {
            FooterViewHolder vh = (FooterViewHolder) viewHolder;
            vh.innerView.removeAllViews();
            View targetFooter = footerViews.get(position - getStoryCount());
            ViewParent oldFooterHolder = targetFooter.getParent();
            if (oldFooterHolder instanceof ViewGroup) ((ViewGroup) oldFooterHolder).removeAllViews();
            vh.innerView.addView(targetFooter);
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
