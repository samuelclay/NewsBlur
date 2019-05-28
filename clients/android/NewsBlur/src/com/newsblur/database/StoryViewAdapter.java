package com.newsblur.database;

import android.database.Cursor;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Parcelable;
import android.support.v7.widget.RecyclerView;
import android.support.v7.util.DiffUtil;
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
import android.widget.RelativeLayout;
import android.widget.TextView;

import butterknife.Bind;
import butterknife.ButterKnife;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.fragment.ItemSetFragment;
import com.newsblur.fragment.StoryIntelTrainerFragment;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.GestureAction;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryListStyle;
import com.newsblur.util.StoryUtils;
import com.newsblur.util.ThumbnailStyle;
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
    
    // the cursor from which we pull story objects. should not be used except by the thaw/diff worker
    private Cursor cursor;
    // the live list of stories being used by the adapter
    private List<Story> stories = new ArrayList<Story>(0);

    private Parcelable oldScrollState;

    private final ExecutorService executorService;

    private NbActivity context;
    private ItemSetFragment fragment;
    private FeedSet fs;
    private StoryListStyle listStyle;
    private boolean ignoreReadStatus;
    private boolean ignoreIntel;
    private boolean singleFeed;
    private float textSize;
    private UserDetails user;

    public StoryViewAdapter(NbActivity context, ItemSetFragment fragment, FeedSet fs, StoryListStyle listStyle) {
        this.context = context;
        this.fragment = fragment;
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

        executorService = Executors.newFixedThreadPool(1);

        setHasStableIds(true);
    }

    public void updateFeedSet(FeedSet fs) {
        this.fs = fs;
    }

    public void setStyle(StoryListStyle listStyle) {
        this.listStyle = listStyle;
    }

    public void addFooterView(View v) {
        footerViews.add(v);
    }

    @Override
    public int getItemCount() {
        return (getStoryCount() + footerViews.size());
    }

    public int getStoryCount() {
        return stories.size();
    }

    /**
     * get the number of stories we very likely have, even if they haven't
     * been thawed yet, for callers that absolutely must know the size
     * of our dataset (such as for calculating when to fetch more stories)
     */
    public int getRawStoryCount() {
        if (cursor == null) return 0;
        if (cursor.isClosed()) return 0;
        int count = 0;
        try {
            count = cursor.getCount();
        } catch (Exception e) {
            // rather than worry about sync locking for cursor changes, just fail. a
            // closing cursor may as well not be loaded.
        }
        return count;
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
    public long getItemId(int position) {
        if (position >= getStoryCount()) {
            return (footerViews.get(position - getStoryCount()).hashCode());
        }
        
        if (position >= stories.size() || position < 0) return 0;
        return stories.get(position).storyHash.hashCode();
    }

    public void swapCursor(final Cursor c, final RecyclerView rv, Parcelable oldScrollState) {
        // cache the identity of the most recent cursor so async batches can check to
        // see if they are stale
        cursor = c;
        // if the caller wants to restore a scroll state, hold onto it for when we update
        // the dataset and use that state at the right moment
        if (oldScrollState != null) {
            this.oldScrollState = oldScrollState;
        }
        // process the cursor into objects and update the View async
        Runnable r = new Runnable() {
            @Override
            public void run() {
                thawDiffUpdate(c, rv);
            }
        };
        executorService.submit(r);
    }

    /**
     * Attempt to thaw a new set of stories from the cursor most recently
     * seen when the that cycle started.
     */
    private void thawDiffUpdate(final Cursor c, final RecyclerView rv) {
        if (c != cursor) return;

        // thawed stories
        final List<Story> newStories;
        int indexOfLastUnread = -1;
        // attempt to thaw as gracefully as possible despite the fact that the loader
        // framework could close our cursor at any moment.  if this happens, it is fine,
        // as a new one will be provided and another cycle will start.  just return.
        try {
            if (c == null) {
                newStories = new ArrayList<Story>(0);
            } else {
                if (c.isClosed()) return;
                newStories = new ArrayList<Story>(c.getCount());
                c.moveToPosition(-1);
                while (c.moveToNext()) {
                    if (c.isClosed()) return;
                    Story s = Story.fromCursor(c);
                    s.bindExternValues(c);
                    newStories.add(s);
                    if (! s.read) indexOfLastUnread = c.getPosition();
                }
            }
        } catch (Exception e) {
            com.newsblur.util.Log.e(this, "error thawing story list: " + e.getMessage(), e);
            return;
        }

        // generate the RecyclerView diff
        final DiffUtil.DiffResult diff = DiffUtil.calculateDiff(new StoryListDiffer(newStories), false);

        if (c != cursor) return;

        fragment.storyThawCompleted(indexOfLastUnread);

        rv.post(new Runnable() {
            @Override
            public void run() {
                if (c != cursor) return;

                // many versions of RecyclerView like to auto-scroll to inserted elements which is
                // not at all what we want.  the current scroll position is one of the things frozen
                // in instance state, so keep it and re-apply after deltas to preserve position
                Parcelable scrollState = rv.getLayoutManager().onSaveInstanceState();
                synchronized (StoryViewAdapter.this) {
                    stories = newStories;
                    diff.dispatchUpdatesTo(StoryViewAdapter.this);
                    // the one exception to restoring state is if we were passed an old state to restore
                    // along with the cursor
                    if (oldScrollState != null) {
                        rv.getLayoutManager().onRestoreInstanceState(oldScrollState);
                        oldScrollState = null;
                    } else {
                        rv.getLayoutManager().onRestoreInstanceState(scrollState);
                    }
                }
            }
        });
    }

    private class StoryListDiffer extends DiffUtil.Callback {
        private List<Story> newStories;
        public StoryListDiffer(List<Story> newStories) {
            StoryListDiffer.this.newStories = newStories;
        }
        public boolean areContentsTheSame(int oldItemPosition, int newItemPosition) {
            return newStories.get(newItemPosition).isChanged(stories.get(oldItemPosition));
        }
        public boolean areItemsTheSame(int oldItemPosition, int newItemPosition) {
            return newStories.get(newItemPosition).storyHash.equals(stories.get(oldItemPosition).storyHash);
        }
        public int getNewListSize() {
            return newStories.size();
        }
        public int getOldListSize() {
            return stories.size();
        }
    }

    public synchronized Story getStory(int position) {
        if (position >= stories.size() || position < 0) {
            return null;
        } else {
            return stories.get(position);
        }
    }

    public void setTextSize(float textSize) {
        this.textSize = textSize;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup viewGroup, int viewType) {
        // NB: the non-temporary calls to setLayerType() dramatically speed up list movement, but
        // are only safe because we perform fairly advanced delta updates. if any changes to invalidation
        // logic are made, check the list with hardare layer profiling to ensure we aren't over-invalidating
        if (viewType == VIEW_TYPE_STORY_TILE) {
            View v = LayoutInflater.from(viewGroup.getContext()).inflate(R.layout.view_story_tile, viewGroup, false);
            v.setLayerType(View.LAYER_TYPE_HARDWARE, null);
            return new StoryTileViewHolder(v);
        } else if (viewType == VIEW_TYPE_STORY_ROW) {
            View v = LayoutInflater.from(viewGroup.getContext()).inflate(R.layout.view_story_row, viewGroup, false);
            v.setLayerType(View.LAYER_TYPE_HARDWARE, null);
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

            if (position >= stories.size() || position < 0) return;

            Story story = stories.get(position);
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

            // footers often move aboslute position, but views can only have one parent. since the RV doesn't
            // necessarily remove from the old pos before adding to the new, we have to add a check here.
            // however, modifying other views out of order causes requestLayout to be called from within a
            // layout pass, which causes warnings.
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
            ((PrefsUtils.getThumbnailStyle(context)  != ThumbnailStyle.OFF) && (story.thumbnailUrl != null))) {
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


        vh.leftBarOne.setBackgroundColor(UIUtils.decodeColourValue(story.extern_feedColor, Color.GRAY));
        vh.leftBarTwo.setBackgroundColor(UIUtils.decodeColourValue(story.extern_feedFade, Color.LTGRAY));

        if (! ignoreIntel) {
            int score = story.extern_intelTotalScore;
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
            FeedUtils.iconLoader.displayImage(story.extern_faviconUrl, vh.feedIconView, 0, false);
            vh.feedTitleView.setText(story.extern_feedTitle);
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

        ThumbnailStyle thumbnailStyle = PrefsUtils.getThumbnailStyle(context);
        int sizeRes = thumbnailStyle == ThumbnailStyle.SMALL ? R.dimen.thumbnails_small_size : R.dimen.thumbnails_size;
        int sizeDp = context.getResources().getDimensionPixelSize(sizeRes);

        RelativeLayout.LayoutParams params = (RelativeLayout.LayoutParams) vh.thumbView.getLayoutParams();
        if (params.height != sizeDp) {
            params.height = sizeDp;
            params.width = sizeDp;
        }

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

    public void notifyAllItemsChanged() {
        notifyItemRangeChanged(0, getItemCount());
    }

}
