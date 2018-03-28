package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.Typeface;
import android.support.v7.widget.RecyclerView;
import android.text.TextUtils;
import android.view.ContextMenu;
import android.view.GestureDetector;
import android.view.LayoutInflater;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.MotionEvent;
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
import com.newsblur.activity.NbActivity;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.fragment.StoryIntelTrainerFragment;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.GestureAction;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryListStyle;
import com.newsblur.util.StoryUtils;
import com.newsblur.util.UIUtils;

/**
 * Story list adapter, RecyclerView style.
 */
public class StoryViewAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    public final static int VIEW_TYPE_STORY_TILE = 1;
    public final static int VIEW_TYPE_STORY_ROW = 2;
    public final static int VIEW_TYPE_FOOTER = 3;

    private final static float defaultTextSize_story_item_feedtitle = 13f;
    private final static float defaultTextSize_story_item_title = 14f;
    private final static float defaultTextSize_story_item_date = 11f;
    private final static float defaultTextSize_story_item_author = 11f;
    private final static float defaultTextSize_story_item_snip = 12f;

    private final static float READ_STORY_ALPHA = 0.35f;
    private final static int READ_STORY_ALPHA_B255 = (int) (255f * READ_STORY_ALPHA);

    private List<View> footerViews = new ArrayList<View>();
    
    protected Cursor cursor;
    private boolean showNone = false;

    private NbActivity context;
    private FeedSet fs;
    private StoryListStyle listStyle;
    private boolean ignoreReadStatus;
    private boolean ignoreIntel;
    private boolean singleFeed;
    private float textSize;
    private UserDetails user;

    public StoryViewAdapter(NbActivity context, FeedSet fs, StoryListStyle listStyle) {
        this.context = context;
        this.fs = fs;
        this.listStyle = listStyle;
        
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

    public void setStyle(StoryListStyle listStyle) {
        this.listStyle = listStyle;
    }

    public synchronized void addFooterView(View v) {
        footerViews.add(v);
    }

    @Override
    public synchronized int getItemCount() {
        return (getStoryCount() + footerViews.size());
    }

    public int getStoryCount() {
        if (showNone || isCursorBad()) {
            return 0;
        } else {
            return cursor.getCount();
        }
    }

    @Override
    public int getItemViewType(int position) {
        if (position >= getStoryCount()) return VIEW_TYPE_FOOTER;
        if (listStyle == StoryListStyle.LIST) {
            return VIEW_TYPE_STORY_ROW;
        } else {
            return VIEW_TYPE_STORY_TILE;
        }
    }

    @Override
    public synchronized long getItemId(int position) {
        if (position >= getStoryCount()) {
            return (footerViews.get(position - getStoryCount()).hashCode());
        }
        
        if (isCursorBad() || cursor.getColumnCount() == 0 || position >= cursor.getCount() || position < 0) return 0;
        cursor.moveToPosition(position);
        return cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_HASH)).hashCode();
    }

    public synchronized void swapCursor(Cursor c) {
        this.cursor = c;
        notifyDataSetChanged();
    }

    private boolean isCursorBad() {
        if (cursor == null) return true;
        if (cursor.isClosed()) return true;
        return false;
    }

    public synchronized Story getStory(int position) {
        if (isCursorBad() || cursor.getColumnCount() == 0 || position >= cursor.getCount() || position < 0) {
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
        if (viewType == VIEW_TYPE_STORY_TILE) {
            View v = LayoutInflater.from(viewGroup.getContext()).inflate(R.layout.view_story_tile, viewGroup, false);
            return new StoryTileViewHolder(v);
        } else if (viewType == VIEW_TYPE_STORY_ROW) {
            View v = LayoutInflater.from(viewGroup.getContext()).inflate(R.layout.view_story_row, viewGroup, false);
            return new StoryRowViewHolder(v);
        } else {
            View v = LayoutInflater.from(viewGroup.getContext()).inflate(R.layout.view_footer_tile, viewGroup, false);
            return new FooterViewHolder(v);
        }
    }

    public class StoryViewHolder extends RecyclerView.ViewHolder
                                 implements View.OnClickListener, 
                                            View.OnCreateContextMenuListener, 
                                            MenuItem.OnMenuItemClickListener,
                                            View.OnTouchListener {

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
        GestureDetector gestureDetector = new GestureDetector(context, new StoryViewGestureDetector(StoryViewHolder.this));
        boolean gestureR2L = false;
        boolean gestureL2R = false;
        boolean gestureDebounce = false;

        public StoryViewHolder(View view) {
            super(view);
            ButterKnife.bind(StoryViewHolder.this, view);
            view.setOnClickListener(StoryViewHolder.this);
            view.setOnCreateContextMenuListener(StoryViewHolder.this);
            view.setOnTouchListener(StoryViewHolder.this);
        }

        @Override
        public void onClick(View view) {
            // clicks like to get accidentally triggered by the system right after we detect
            // a gesture. ignore if a gesture appears to be in progress.
            if (gestureDebounce) {
                gestureDebounce = false;
                return;
            }
            if (gestureL2R || gestureR2L) return;
            UIUtils.startReadingActivity(fs, story.storyHash, context);
        }

        @Override
        public void onCreateContextMenu(ContextMenu menu, View v, ContextMenu.ContextMenuInfo menuInfo) {
            // clicks like to get accidentally triggered by the system right after we detect
            // a gesture. ignore if a gesture appears to be in progress.
            if (gestureDebounce) {
                gestureDebounce = false;
                return;
            }
            if (gestureL2R || gestureR2L) return;
            MenuInflater inflater = new MenuInflater(context);
            UIUtils.inflateStoryContextMenu(menu, inflater, context, fs, story);
            for (int i=0; i<menu.size(); i++) {
                menu.getItem(i).setOnMenuItemClickListener(StoryViewHolder.this);
            }
        }

        @Override
        public boolean onMenuItemClick(MenuItem item) {
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
                intelFrag.show(context.getSupportFragmentManager(), StoryIntelTrainerFragment.class.getName());
                return true;

            default:
                return false;
            }
        }

        @Override
        public boolean onTouch(View v, MotionEvent event) {
            // detector looks for ongoing gestures and sets our flags
            boolean result = gestureDetector.onTouchEvent(event);
            // iff a gesture possibly completed, see if any were found
            if (event.getActionMasked() == MotionEvent.ACTION_UP) {
                flushGesture();
            } else if (event.getActionMasked() == MotionEvent.ACTION_CANCEL) {
                // RecyclerViews may take event ownership to detect scrolling and never send an ACTION_UP
                // to children.  valid gestures end in a CANCEL more often than not
                flushGesture();
            }
            return result;
        }

        private void flushGesture() {
            // by default, do nothing
            GestureAction action = GestureAction.GEST_ACTION_NONE;
            if (gestureL2R) {
                action = PrefsUtils.getLeftToRightGestureAction(context);
                gestureL2R = false;
            }
            if (gestureR2L) {
                action = PrefsUtils.getRightToLeftGestureAction(context);
                gestureR2L = false;
            }
            switch (action) {
                case GEST_ACTION_MARKREAD:
                    FeedUtils.markStoryAsRead(story, context);
                    break;
                case GEST_ACTION_MARKUNREAD:
                    FeedUtils.markStoryUnread(story, context);
                    break;
                case GEST_ACTION_SAVE:
                    FeedUtils.setStorySaved(story, true, context);
                    break;
                case GEST_ACTION_UNSAVE:
                    FeedUtils.setStorySaved(story, false, context);
                    break;
                case GEST_ACTION_NONE:
                default:
            }
        }
    }

    public class StoryTileViewHolder extends StoryViewHolder {
        public StoryTileViewHolder(View view) {
            super(view);
        }
    }

    public class StoryRowViewHolder extends StoryViewHolder {
        @Bind(R.id.story_item_author) TextView storyAuthor;
        @Bind(R.id.story_item_content) TextView storySnippet;
        public StoryRowViewHolder(View view) {
            super(view);
        }
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder viewHolder, int position) {
        if (viewHolder instanceof StoryViewHolder) {
            StoryViewHolder vh = (StoryViewHolder) viewHolder;

            if (isCursorBad() || cursor.getColumnCount() == 0 || position >= cursor.getCount() || position < 0) return;
            cursor.moveToPosition(position);

            Story story = Story.fromCursor(cursor);
            vh.story = story;

            bindCommon(vh, position, story);

            if (vh instanceof StoryRowViewHolder) {
                StoryRowViewHolder vhRow = (StoryRowViewHolder) vh;
                bindRow(vhRow, position, story);
            } else {
                StoryTileViewHolder vhTile = (StoryTileViewHolder) vh;
                bindTile(vhTile, position, story);
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

    /**
     * Bind view elements that are common to tiles and rows.
     */
    private void bindCommon(StoryViewHolder vh, int position, Story story) {
        if ((vh instanceof StoryTileViewHolder) ||
            ((PrefsUtils.isShowThumbnails(context)) && (story.thumbnailUrl != null))) {
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
            vh.thumbView.setVisibility(View.VISIBLE);
        } else {
            // if in row mode and thubnail is disabled or missing, don't just hide but collapse
            vh.thumbView.setVisibility(View.GONE);
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
    }

    private void bindTile(StoryTileViewHolder vh, int position, Story story) {
    }

    private void bindRow(StoryRowViewHolder vh, int position, Story story) {
        if (PrefsUtils.isShowContentPreviews(context)) {
            vh.storySnippet.setVisibility(View.VISIBLE);
            vh.storySnippet.setText(story.shortContent);
        } else {
            vh.storySnippet.setVisibility(View.GONE);
        }

        if (TextUtils.isEmpty(story.authors)) {
            vh.storyAuthor.setText("");
        } else {
            vh.storyAuthor.setText(story.authors.toUpperCase());
        }

        vh.storyAuthor.setTextSize(textSize * defaultTextSize_story_item_author);
        vh.storySnippet.setTextSize(textSize * defaultTextSize_story_item_snip);

        if (this.ignoreReadStatus || (! story.read)) {
            vh.storyAuthor.setAlpha(1.0f);
            vh.storySnippet.setAlpha(1.0f);
            vh.storyTitleView.setTypeface(null, Typeface.BOLD);
        } else {
            vh.storyAuthor.setAlpha(READ_STORY_ALPHA);
            vh.storySnippet.setAlpha(READ_STORY_ALPHA);
            vh.storyTitleView.setTypeface(null, Typeface.NORMAL);
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

    class StoryViewGestureDetector extends GestureDetector.SimpleOnGestureListener {
        private StoryViewHolder vh;
        public StoryViewGestureDetector(StoryViewHolder vh) {
            StoryViewGestureDetector.this.vh = vh;
        }

        @Override
        public boolean onScroll(MotionEvent e1, MotionEvent e2, float distanceX, float distanceY) {
            if ((e1.getX() > 10f) &&                  // the gesture should not start too close to the left edge and
                ((e2.getX()-e1.getX()) > 50f) &&      // move horizontally to the right and
                (Math.abs(e1.getY()-e2.getY()) < 25f) // have minimal vertical travel, so we don't capture scrolling gestures
                ) {
                vh.gestureL2R = true;
                vh.gestureDebounce = true;
                return true;
            }
            if ((e1.getX() > 10f) &&                  // the gesture should not start too close to the left edge and
                ((e1.getX()-e2.getX()) > 50f) &&      // move horizontally to the left and
                (Math.abs(e1.getY()-e2.getY()) < 25f) // have minimal vertical travel, so we don't capture scrolling gestures
                ) {
                vh.gestureR2L = true;
                vh.gestureDebounce = true;
                return true;
            }
            return false;
        }
    }

}
