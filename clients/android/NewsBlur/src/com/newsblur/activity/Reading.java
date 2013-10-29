package com.newsblur.activity;

import java.util.HashSet;
import java.util.Set;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.view.ViewPager;
import android.support.v4.view.ViewPager.OnPageChangeListener;
import android.view.View;
import android.widget.Button;
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;
import android.widget.TextView;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.fragment.ReadingItemFragment;
import com.newsblur.fragment.ShareDialogFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.fragment.TextSizeDialogFragment;
import com.newsblur.network.APIManager;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.util.ViewUtils;
import com.newsblur.view.NonfocusScrollview.ScrollChangeListener;

public abstract class Reading extends NbFragmentActivity implements OnPageChangeListener, SyncUpdateFragment.SyncUpdateFragmentInterface, OnSeekBarChangeListener, ScrollChangeListener {

	public static final String EXTRA_FEED = "feed_selected";
	public static final String EXTRA_POSITION = "feed_position";
	public static final String EXTRA_USERID = "user_id";
	public static final String EXTRA_USERNAME = "username";
	public static final String EXTRA_FOLDERNAME = "foldername";
	public static final String EXTRA_FEED_IDS = "feed_ids";
	private static final String TEXT_SIZE = "textsize";

    private static final int OVERLAY_RANGE_TOP_DP = 50;
    private static final int OVERLAY_RANGE_BOT_DP = 60;

	protected int passedPosition;
	protected int currentState;

	protected ViewPager pager;
    protected Button overlayLeft, overlayRight;
    protected TextView overlayCount;
	protected FragmentManager fragmentManager;
	protected ReadingAdapter readingAdapter;
	protected ContentResolver contentResolver;
    private APIManager apiManager;
	protected SyncUpdateFragment syncFragment;
	protected Cursor stories;
    private boolean noMoreApiPages;
    protected volatile boolean requestedPage; // set high iff a syncservice request for stories is already in flight
    private int currentApiPage = 0;
	private Set<Story> storiesToMarkAsRead;

    // subclasses may set this to a nonzero value to enable the unread count overlay
    protected int unreadCount = 0;

    // keep a local cache of stories we have viewed within this activity cycle.  We need
    // this to track unread counts since it would be too costly to query and update the DB
    // on every page change.
    private Set<Story> storiesAlreadySeen;


    private float overlayRangeTopPx;
    private float overlayRangeBotPx;

	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(savedInstanceBundle);

		setContentView(R.layout.activity_reading);
        this.overlayLeft = (Button) findViewById(R.id.reading_overlay_left);
        this.overlayRight = (Button) findViewById(R.id.reading_overlay_right);
        this.overlayCount = (TextView) findViewById(R.id.reading_overlay_count);

		fragmentManager = getSupportFragmentManager();
		
        storiesToMarkAsRead = new HashSet<Story>();
        storiesAlreadySeen = new HashSet<Story>();

		passedPosition = getIntent().getIntExtra(EXTRA_POSITION, 0);
		currentState = getIntent().getIntExtra(ItemsList.EXTRA_STATE, 0);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);
		contentResolver = getContentResolver();

        this.apiManager = new APIManager(this);

        // this value is expensive to compute but doesn't change during a single runtime
        this.overlayRangeTopPx = (float) UIUtils.convertDPsToPixels(this, OVERLAY_RANGE_TOP_DP);
        this.overlayRangeBotPx = (float) UIUtils.convertDPsToPixels(this, OVERLAY_RANGE_BOT_DP);

        // the unread count overlay defaults to neutral colour.  set it to positive if we are in focus mode
        if (this.currentState == AppConstants.STATE_BEST) {
            ViewUtils.setViewBackground(this.overlayCount, R.drawable.positive_count_rect);
        }

	}

    /**
     * Sets up the local pager widget.  Should be called from onCreate() after both the cursor and
     * adapter are created.
     */
	protected void setupPager() {
		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncUpdateFragment.TAG).commit();
		}

		pager = (ViewPager) findViewById(R.id.reading_pager);
		pager.setPageMargin(UIUtils.convertDPsToPixels(getApplicationContext(), 1));
		pager.setPageMarginDrawable(R.drawable.divider_light);
		pager.setOnPageChangeListener(this);

		pager.setAdapter(readingAdapter);
		pager.setCurrentItem(passedPosition);
        this.enableOverlays();
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getSupportMenuInflater();
		inflater.inflate(R.menu.reading, menu);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		int currentItem = pager.getCurrentItem();
		Story story = readingAdapter.getStory(currentItem);
		UserDetails user = PrefsUtils.getUserDetails(this);

		if (item.getItemId() == android.R.id.home) {
			finish();
			return true;
		} else if (item.getItemId() == R.id.menu_reading_original) {
			if (story != null) {
				Intent i = new Intent(Intent.ACTION_VIEW);
				i.setData(Uri.parse(story.permalink));
				startActivity(i);
			}
			return true;
		} else if (item.getItemId() == R.id.menu_reading_sharenewsblur) {
			if (story != null) {
				ReadingItemFragment currentFragment = (ReadingItemFragment) readingAdapter.instantiateItem(pager, currentItem);
				DialogFragment newFragment = ShareDialogFragment.newInstance(currentFragment, story, currentFragment.previouslySavedShareText);
				newFragment.show(getSupportFragmentManager(), "dialog");
			}
			return true;
		} else if (item.getItemId() == R.id.menu_shared) {
			FeedUtils.shareStory(story, this);
			return true;
		} else if (item.getItemId() == R.id.menu_textsize) {
			float currentValue = getSharedPreferences(PrefConstants.PREFERENCES, 0).getFloat(PrefConstants.PREFERENCE_TEXT_SIZE, 0.5f);
			TextSizeDialogFragment textSize = TextSizeDialogFragment.newInstance(currentValue);
			textSize.show(getSupportFragmentManager(), TEXT_SIZE);
			return true;
		} else if (item.getItemId() == R.id.menu_reading_save) {
			FeedUtils.saveStory(story, Reading.this, apiManager);
			return true;
        } else if (item.getItemId() == R.id.menu_reading_markunread) {
            this.markStoryUnread(story);
            return true;
		} else {
			return super.onOptionsItemSelected(item);
		}
	}

    // interface OnPageChangeListener

	@Override
	public void onPageScrollStateChanged(int arg0) {
	}

	@Override
	public void onPageScrolled(int arg0, float arg1, int arg2) {
	}

	@Override
	public void onPageSelected(int position) {
        this.enableOverlays();

		if (readingAdapter.getStory(position) != null) {
			addStoryToMarkAsRead(readingAdapter.getStory(position));
			checkStoryCount(position);
		}
	}

    // interface ScrollChangeListener

    @Override
    public void scrollChanged(int hPos, int vPos, int currentWidth, int currentHeight) {
        int scrollMax = currentHeight - findViewById(android.R.id.content).getMeasuredHeight();
        int posFromBot = (scrollMax - vPos);

        float newAlpha = 0.0f;
        if ((vPos < this.overlayRangeTopPx) && (posFromBot < this.overlayRangeBotPx)) {
            // if we have a super-tiny scroll window such that we never leave either top or bottom,
            // just leave us at full alpha.
            newAlpha = 1.0f;
        } else if (vPos < this.overlayRangeTopPx) {
            float delta = this.overlayRangeTopPx - ((float) vPos);
            newAlpha = delta / this.overlayRangeTopPx;
        } else if (posFromBot < this.overlayRangeBotPx) {
            float delta = this.overlayRangeBotPx - ((float) posFromBot);
            newAlpha = delta / this.overlayRangeBotPx;
        }
        
        this.setOverlayAlpha(newAlpha);
    }

    private void setOverlayAlpha(float a) {
        UIUtils.setViewAlpha(this.overlayLeft, a);
        UIUtils.setViewAlpha(this.overlayRight, a);

        if (this.unreadCount > 0) {
            UIUtils.setViewAlpha(this.overlayCount, a);
        } else {
            UIUtils.setViewAlpha(this.overlayCount, 0.0f);
        }
    }

    /**
     * Check and correct the display status of the overlays.  Call this any time
     * an event happens that might change out list position.
     */
    private void enableOverlays() {
        int page = this.pager.getCurrentItem();
        this.overlayLeft.setEnabled(page > 0);
        this.overlayRight.setEnabled(page < (this.readingAdapter.getCount()-1));
        this.overlayRight.setText((page < (this.readingAdapter.getCount()-1)) ? R.string.overlay_next : R.string.overlay_done);

        this.overlayCount.setText(Integer.toString(this.unreadCount));
        this.setOverlayAlpha(1.0f);
    }

	@Override
	public void updateAfterSync() {
        this.requestedPage = false;
		setSupportProgressBarIndeterminateVisibility(false);
		stories.requery();
		readingAdapter.notifyDataSetChanged();
        this.enableOverlays();
        checkStoryCount(pager.getCurrentItem());
	}

	@Override
	public void updatePartialSync() {
		stories.requery();
		readingAdapter.notifyDataSetChanged();
        this.enableOverlays();
        checkStoryCount(pager.getCurrentItem());
	}

    /**
     * Lets us know that there are no more pages of stories to load, ever, and will cause
     * us to stop requesting them.
     */
	@Override
	public void setNothingMoreToUpdate() {
		this.noMoreApiPages = true;
	}

	private void checkStoryCount(int position) {
        // if the pager is at or near the number of stories loaded, check for more unless we know we are at the end of the list
		if (((position + 1) >= stories.getCount()) && !noMoreApiPages && !requestedPage) {
			currentApiPage += 1;
			requestedPage = true;
			triggerRefresh(currentApiPage);
		}
	}

	@Override
	public void updateSyncStatus(boolean syncRunning) {
		setSupportProgressBarIndeterminateVisibility(syncRunning);
	}

	public abstract void triggerRefresh(int page);

    @Override
    protected void onPause() {
        flushStoriesMarkedRead();
        super.onPause();
    }

    /** 
     * Log a story as having been read. The local DB and remote server will be updated
     * batch-wise when the activity pauses.
     */
    protected void addStoryToMarkAsRead(Story story) {
        if (story == null) return;
        if (story.read) return;
        synchronized (this.storiesToMarkAsRead) {
            this.storiesToMarkAsRead.add(story);
        }
        // flush immediately if the batch reaches a sufficient size
        if (this.storiesToMarkAsRead.size() >= AppConstants.MAX_MARK_READ_BATCH) {
            flushStoriesMarkedRead();
        }
        if (this.storiesAlreadySeen.add(story)) {
            // only decrement the cached story count if the story wasn't already read
            this.unreadCount--;
        }
        this.enableOverlays();
    }

    private void flushStoriesMarkedRead() {
        synchronized(this.storiesToMarkAsRead) {
            if (this.storiesToMarkAsRead.size() > 0) {
                FeedUtils.markStoriesAsRead(this.storiesToMarkAsRead, this);
                this.storiesToMarkAsRead.clear();
            }
        }
    }

    private void markStoryUnread(Story story) {

        // first, ensure the story isn't queued up to be marked as read
        this.storiesToMarkAsRead.remove(story);

        // next, call the API to un-mark it as read, just in case we missed the batch
        // operation, or it was read long before now.
        FeedUtils.markStoryUnread(story, Reading.this, this.apiManager);

        this.unreadCount++;
        this.storiesAlreadySeen.remove(story);

        this.enableOverlays();
    }

	@Override
	public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
		getSharedPreferences(PrefConstants.PREFERENCES, 0).edit().putFloat(PrefConstants.PREFERENCE_TEXT_SIZE, (float) progress /  AppConstants.FONT_SIZE_INCREMENT_FACTOR).commit();
		Intent data = new Intent(ReadingItemFragment.TEXT_SIZE_CHANGED);
		data.putExtra(ReadingItemFragment.TEXT_SIZE_VALUE, (float) progress / AppConstants.FONT_SIZE_INCREMENT_FACTOR); 
		sendBroadcast(data);
	}

	@Override
	public void onStartTrackingTouch(SeekBar seekBar) {
	}

	@Override
	public void onStopTrackingTouch(SeekBar seekBar) {
	}

    public void overlayRight(View v) {
        pager.setCurrentItem(pager.getCurrentItem()+1, true);
    }

    public void overlayLeft(View v) {
        pager.setCurrentItem(pager.getCurrentItem()-1, true);
    }

}
