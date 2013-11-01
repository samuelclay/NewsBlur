package com.newsblur.activity;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.view.ViewPager;
import android.support.v4.view.ViewPager.OnPageChangeListener;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;
import android.widget.Toast;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.activity.Main;
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

    private static final int OVERLAY_RANGE_TOP_DP = 45;
    private static final int OVERLAY_RANGE_BOT_DP = 60;

    /** The longest time (in seconds) the UI will wait for API pages to load while
        searching for the next unread story. */
    private static final long UNREAD_SEARCH_LOAD_WAIT_SECONDS = 30;

    private final Object UNREAD_SEARCH_MUTEX = new Object();
    private CountDownLatch unreadSearchLatch;

	protected int passedPosition;
	protected int currentState;

	protected ViewPager pager;
    protected Button overlayLeft, overlayRight;
    protected ProgressBar overlayProgress;
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

    // unread counts for the circular progress overlay. set to nonzero to activate the progress indicator overlay
    protected int startingUnreadCount = 0;
    protected int currentUnreadCount = 0;

    // a list of stories we have viewed within this activity cycle.  We need this to power the "back"
    // overlay nav button, and also to help keep track of unread counts since it would be too costly
    // to query and update the DB on every page change.
    private List<Story> storiesAlreadySeen;


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
        this.overlayProgress = (ProgressBar) findViewById(R.id.reading_overlay_progress);

		fragmentManager = getSupportFragmentManager();
		
        storiesToMarkAsRead = new HashSet<Story>();
        storiesAlreadySeen = new ArrayList<Story>();

		passedPosition = getIntent().getIntExtra(EXTRA_POSITION, 0);
		currentState = getIntent().getIntExtra(ItemsList.EXTRA_STATE, 0);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);
		contentResolver = getContentResolver();

        this.apiManager = new APIManager(this);

        // this value is expensive to compute but doesn't change during a single runtime
        this.overlayRangeTopPx = (float) UIUtils.convertDPsToPixels(this, OVERLAY_RANGE_TOP_DP);
        this.overlayRangeBotPx = (float) UIUtils.convertDPsToPixels(this, OVERLAY_RANGE_BOT_DP);

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
        UIUtils.setViewAlpha(this.overlayProgress, a);
    }

    /**
     * Check and correct the display status of the overlays.  Call this any time
     * an event happens that might change out list position.
     */
    private void enableOverlays() {
        this.overlayLeft.setEnabled(true);
        this.overlayRight.setText((this.currentUnreadCount > 0) ? R.string.overlay_next : R.string.overlay_done);
        this.overlayRight.setBackgroundResource((this.currentUnreadCount > 0) ? R.drawable.selector_overlay_bg_right : R.drawable.overlay_right_done);

        if (this.startingUnreadCount == 0 ) {
            // sessions with no unreads just show a full progress bar
            this.overlayProgress.setMax(1);
            this.overlayProgress.setProgress(1);
        } else {
            int unreadProgress = this.startingUnreadCount - this.currentUnreadCount;
            this.overlayProgress.setMax(this.startingUnreadCount);
            this.overlayProgress.setProgress(unreadProgress);
        }
        this.overlayProgress.invalidate();

        this.setOverlayAlpha(1.0f);
    }

	@Override
	public void updateAfterSync() {
        this.requestedPage = false;
		updateSyncStatus(false);
		stories.requery();
		readingAdapter.notifyDataSetChanged();
        this.enableOverlays();
        checkStoryCount(pager.getCurrentItem());
        if (this.unreadSearchLatch != null) {
            this.unreadSearchLatch.countDown();
        }
	}

	@Override
	public void updatePartialSync() {
		stories.requery();
		readingAdapter.notifyDataSetChanged();
        this.enableOverlays();
        checkStoryCount(pager.getCurrentItem());
        if (this.unreadSearchLatch != null) {
            this.unreadSearchLatch.countDown();
        }
	}

    /**
     * Lets us know that there are no more pages of stories to load, ever, and will cause
     * us to stop requesting them.
     */
	@Override
	public void setNothingMoreToUpdate() {
		this.noMoreApiPages = true;
        if (this.unreadSearchLatch !=null) {
            this.unreadSearchLatch.countDown();
        }
	}

	/**
     * While navigating the story list and at the specified position, see if it is possible
     * and desirable to start loading more stories in the background.  Note that if a load
     * is triggered, this method will be called again by the callback to ensure another
     * load is not needed and all latches are tripped.
     */
    private void checkStoryCount(int position) {
        Log.d(this.getClass().getName(), String.format("position: %d, total: %d, request running: %b, no more: %b", position, stories.getCount(), requestedPage, noMoreApiPages));
        // if the pager is at or near the number of stories loaded, check for more unless we know we are at the end of the list
		if (((position + 2) >= stories.getCount()) && !noMoreApiPages && !requestedPage) {
			currentApiPage += 1;
			requestedPage = true;
			triggerRefresh(currentApiPage);
		}
	}

	@Override
	public void updateSyncStatus(final boolean syncRunning) {
        runOnUiThread(new Runnable() {
            public void run() {
                setSupportProgressBarIndeterminateVisibility(syncRunning);
            }
        });
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
        if (!this.storiesAlreadySeen.contains(story)) {
            // only decrement the cached story count if the story wasn't already read
            this.storiesAlreadySeen.add(story);
            this.currentUnreadCount--;
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

        this.currentUnreadCount++;
        this.storiesAlreadySeen.remove(story);

        this.enableOverlays();
    }

    // NB: this callback is for the text size slider
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

    /**
     * Click handler for the righthand overlay nav button.
     */
    public void overlayRight(View v) {
        if (this.currentUnreadCount == 0) {
            // if there are no unread stories, go back to the feed list
            Intent i = new Intent(this, Main.class);
            i.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
            startActivity(i);
        } else {
            // if there are unreads, go to the next one
            new AsyncTask<Void, Void, Void>() {
                @Override
                protected Void doInBackground(Void... params) {
                    nextUnread();
                    return null;
                }
            }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
        }
    }

    /**
     * Search our set of stories for the next unread one.  This requires some heavy
     * cooperation with the way stories are automatically loaded in the background
     * as we walk through the list.
     */
    private void nextUnread() {
        synchronized (UNREAD_SEARCH_MUTEX) {
            int candidate = 0;
            boolean unreadFound = false;
            unreadSearch:while (!unreadFound) {
                Log.d(this.getClass().getName(), "candidate: " + candidate);
                
                Story story = readingAdapter.getStory(candidate);

                if (story == null) {
                    if (this.noMoreApiPages) {
                        // this is odd. if there were no unreads, how was the button even enabled?
                        Log.e(this.getClass().getName(), "Ran out of stories while looking for unreads.");
                        Toast.makeText(this, R.string.toast_unread_search_error, Toast.LENGTH_LONG).show();
                        break unreadSearch;
                    } else {
                        Log.d(this.getClass().getName(), "Waiting for stories to load.");
                    }
                } else {
                    Log.d(this.getClass().getName(), String.format("story.id: %s, story.read: %b", story.storyHash, story.read));
                    if ((candidate == pager.getCurrentItem()) || (story.read) || (this.storiesAlreadySeen.contains(story))) {
                        candidate++;
                        Log.d(this.getClass().getName(), "Passing read story.");
                        continue unreadSearch;
                    } else {
                        unreadFound = true;
                        break unreadSearch;
                    }
                }

                // if we didn't find a story trigger a check to see if there are any more to search before proceeding
                this.unreadSearchLatch = new CountDownLatch(1);
                this.checkStoryCount(candidate+1);
                try {
                    boolean unlatched = this.unreadSearchLatch.await(UNREAD_SEARCH_LOAD_WAIT_SECONDS, TimeUnit.SECONDS);
                    if (unlatched) {
                        continue unreadSearch;
                    } else {
                        Log.e(this.getClass().getName(), "Timed out waiting for next API page while looking for unreads.");
                        Toast.makeText(this, R.string.toast_unread_search_error, Toast.LENGTH_LONG).show();
                        break unreadSearch;
                    }
                } catch (InterruptedException ie) {
                    Log.e(this.getClass().getName(), "Interrupted waiting for next API page while looking for unreads.");
                    Toast.makeText(this, R.string.toast_unread_search_error, Toast.LENGTH_LONG).show();
                    break unreadSearch;
                }

            }
            if (unreadFound) {
                final int page = candidate;
                runOnUiThread(new Runnable() {
                    public void run() {
                        pager.setCurrentItem(page, true);
                    }
                });
            }
        }
    }

    /**
     * Click handler for the lefthand overlay nav button.
     */
    public void overlayLeft(View v) {
        pager.setCurrentItem(pager.getCurrentItem()-1, true);
    }

    /**
     * Click handler for the progress indicator on the righthand overlay nav button.
     */
    public void overlayCount(View v) {
        String unreadText = getString((this.currentUnreadCount == 1) ? R.string.overlay_count_toast_1 : R.string.overlay_count_toast_N);
        Toast.makeText(this, String.format(unreadText, this.currentUnreadCount), Toast.LENGTH_SHORT).show();
    }

}
