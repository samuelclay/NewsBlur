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
import com.newsblur.R;
import com.newsblur.activity.Main;
import com.newsblur.domain.Story;
import com.newsblur.fragment.ReadingItemFragment;
import com.newsblur.fragment.ShareDialogFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.fragment.TextSizeDialogFragment;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.StoryTextResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.view.NonfocusScrollview.ScrollChangeListener;

public abstract class Reading extends NbFragmentActivity implements OnPageChangeListener, SyncUpdateFragment.SyncUpdateFragmentInterface, OnSeekBarChangeListener, ScrollChangeListener, FeedUtils.ActionCompletionListener {

	public static final String EXTRA_FEED = "feed_selected";
	public static final String EXTRA_POSITION = "feed_position";
	public static final String EXTRA_USERID = "user_id";
	public static final String EXTRA_USERNAME = "username";
	public static final String EXTRA_FOLDERNAME = "foldername";
	public static final String EXTRA_FEED_IDS = "feed_ids";
	private static final String TEXT_SIZE = "textsize";

    private static final int OVERLAY_RANGE_TOP_DP = 45;
    private static final int OVERLAY_RANGE_BOT_DP = 60;

    /** The minimum screen width (in DP) needed to show all the overlay controls. */
    private static final int OVERLAY_MIN_WIDTH_DP = 355;

    /** The longest time (in seconds) the UI will wait for API pages to load while
        searching for the next unread story. */
    private static final long UNREAD_SEARCH_LOAD_WAIT_SECONDS = 30;

    private final Object UNREAD_SEARCH_MUTEX = new Object();
    private CountDownLatch unreadSearchLatch;

	protected int passedPosition;
	protected int currentState;

	protected ViewPager pager;
    protected Button overlayLeft, overlayRight;
    protected ProgressBar overlayProgress, overlayProgressRight, overlayProgressLeft;
    protected Button overlayText, overlaySend;
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

    // A list of stories we have marked as read during this reading session. Needed to help keep track of unread
    // counts since it would be too costly to query and update the DB on every page change.
    private Set<Story> storiesAlreadySeen;

    private float overlayRangeTopPx;
    private float overlayRangeBotPx;

    private List<Story> pageHistory;

    private Boolean textMode = false;

	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);

		setContentView(R.layout.activity_reading);
        this.overlayLeft = (Button) findViewById(R.id.reading_overlay_left);
        this.overlayRight = (Button) findViewById(R.id.reading_overlay_right);
        this.overlayProgress = (ProgressBar) findViewById(R.id.reading_overlay_progress);
        this.overlayProgressRight = (ProgressBar) findViewById(R.id.reading_overlay_progress_right);
        this.overlayProgressLeft = (ProgressBar) findViewById(R.id.reading_overlay_progress_left);
        this.overlayText = (Button) findViewById(R.id.reading_overlay_text);
        this.overlaySend = (Button) findViewById(R.id.reading_overlay_send);

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

        this.pageHistory = new ArrayList<Story>();

        enableProgressCircle(overlayProgressLeft, false);
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
        // setCurrentItem sometimes fails to pass the first page to the callback, so call it manually
        // for the first one.
        this.onPageSelected(passedPosition); 

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
    public boolean onPrepareOptionsMenu(Menu menu) {
        super.onPrepareOptionsMenu(menu);
        Story story = readingAdapter.getStory(pager.getCurrentItem());
        menu.findItem(R.id.menu_reading_save).setTitle(story.starred ? R.string.menu_unsave_story : R.string.menu_save_story);
        return true;
    }

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		int currentItem = pager.getCurrentItem();
		Story story = readingAdapter.getStory(currentItem);

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
				DialogFragment newFragment = ShareDialogFragment.newInstance(getReadingFragment(), story, getReadingFragment().previouslySavedShareText);
				newFragment.show(getSupportFragmentManager(), "dialog");
			}
			return true;
		} else if (item.getItemId() == R.id.menu_shared) {
			FeedUtils.shareStory(story, this);
			return true;
		} else if (item.getItemId() == R.id.menu_textsize) {
			TextSizeDialogFragment textSize = TextSizeDialogFragment.newInstance(PrefsUtils.getTextSize(this));
			textSize.show(getSupportFragmentManager(), TEXT_SIZE);
			return true;
		} else if (item.getItemId() == R.id.menu_reading_save) {
            if (story.starred) {
			    FeedUtils.unsaveStory(story, Reading.this, apiManager, this);
            } else {
                FeedUtils.saveStory(story, Reading.this, apiManager, this);
            }
			return true;
        } else if (item.getItemId() == R.id.menu_reading_markunread) {
            this.markStoryUnread(story);
            return true;
		} else {
			return super.onOptionsItemSelected(item);
		}
	}

    @Override
    public void actionCompleteCallback() {
        stories.requery();
        ReadingItemFragment fragment = getReadingFragment();
        fragment.updateStory(readingAdapter.getStory(pager.getCurrentItem()));
        fragment.updateSaveButton();
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
		Story story = readingAdapter.getStory(position);
        if (story != null) {
            synchronized (this.pageHistory) {
                // if the history is just starting out or the last entry in it isn't this page, add this page
                if ((this.pageHistory.size() < 1) || (!story.equals(this.pageHistory.get(this.pageHistory.size()-1)))) {
                    this.pageHistory.add(story);
                }
            }
			addStoryToMarkAsRead(story);
			checkStoryCount(position);
		}
        this.enableOverlays();
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
        UIUtils.setViewAlpha(this.overlayProgressLeft, a);
        UIUtils.setViewAlpha(this.overlayProgressRight, a);
        UIUtils.setViewAlpha(this.overlayText, a);
        UIUtils.setViewAlpha(this.overlaySend, a);
    }

    /**
     * Check and correct the display status of the overlays.  Call this any time
     * an event happens that might change our list position.
     */
    private void enableOverlays() {
        // check to see if the device even has room for all the overlays, moving some to overflow if not
        int widthPX = findViewById(android.R.id.content).getMeasuredWidth();
        if (widthPX != 0) {
            float widthDP = UIUtils.px2dp(this, widthPX);
            if ( widthDP < OVERLAY_MIN_WIDTH_DP ){
                this.overlaySend.setVisibility(View.GONE);
            } else {
                this.overlaySend.setVisibility(View.VISIBLE);
            }
        }

        this.overlayLeft.setEnabled(this.getLastReadPosition(false) != -1);
        this.overlayRight.setText((this.currentUnreadCount > 0) ? R.string.overlay_next : R.string.overlay_done);
        this.overlayRight.setBackgroundResource((this.currentUnreadCount > 0) ? R.drawable.selector_overlay_bg_right : R.drawable.selector_overlay_bg_right_done);

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

        // make sure we start in story mode and the ui reflects it
        synchronized (textMode) {
            enableStoryMode();
        }

        this.setOverlayAlpha(1.0f);
    }

    public void onWindowFocusChanged(boolean hasFocus) {
        // this callback is a good API-level-independent way to tell when the root view size/layout changes
        super.onWindowFocusChanged(hasFocus);
        enableOverlays();
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
        // if the pager is at or near the number of stories loaded, check for more unless we know we are at the end of the list
		if (((position + 2) >= stories.getCount()) && !noMoreApiPages && !requestedPage) {
			currentApiPage += 1;
			requestedPage = true;
			triggerRefresh(currentApiPage);
		}
	}

	@Override
	public void updateSyncStatus(final boolean syncRunning) {
        enableProgressCircle(overlayProgressRight, syncRunning);
	}

    private void enableProgressCircle(final ProgressBar view, final boolean enabled) {
        runOnUiThread(new Runnable() {
            public void run() {
                if (enabled) {
                    view.setProgress(0);
                    view.setVisibility(View.VISIBLE);
                } else {
                    view.setProgress(100);
                    view.setVisibility(View.GONE);
                }
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
	    PrefsUtils.setTextSize(this, (float) progress /  AppConstants.FONT_SIZE_INCREMENT_FACTOR);
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
            }.execute();
            //}.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
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
            boolean error = false;
            unreadSearch:while (!unreadFound) {

                Story story = readingAdapter.getStory(candidate);

                if (story == null) {
                    if (this.noMoreApiPages) {
                        // this is odd. if there were no unreads, how was the button even enabled?
                        Log.e(this.getClass().getName(), "Ran out of stories while looking for unreads.");
                        break unreadSearch;
                    } 
                } else {
                    if ((candidate == pager.getCurrentItem()) || (story.read) || (this.storiesAlreadySeen.contains(story))) {
                        candidate++;
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
                        break unreadSearch;
                    }
                } catch (InterruptedException ie) {
                    Log.e(this.getClass().getName(), "Interrupted waiting for next API page while looking for unreads.");
                    break unreadSearch;
                }

            }
            if (error) {
                runOnUiThread(new Runnable() {
                    public void run() {
                        Toast.makeText(Reading.this, R.string.toast_unread_search_error, Toast.LENGTH_LONG).show();
                    }
                });
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
        int targetPosition = this.getLastReadPosition(true);
        if (targetPosition != -1) {
            pager.setCurrentItem(targetPosition, true);
        } else {
            Log.e(this.getClass().getName(), "reading history contained item not found in cursor.");
        }
    }

    /**
     * Get the pager position of the last story read during this activity or -1 if there is nothing
     * in the history.
     *
     * @param trimHistory optionally trim the history of the currently displayed page iff the
     *        back button has been pressed.
     */
    private int getLastReadPosition(boolean trimHistory) {
        synchronized (this.pageHistory) {
            // the last item is always the currently shown page, do not count it
            if (this.pageHistory.size() < 2) {
                return -1;
            }
            Story targetStory = this.pageHistory.get(this.pageHistory.size()-2);
            int targetPosition = this.readingAdapter.getPosition(targetStory);
            if (trimHistory && (targetPosition != -1)) {
                this.pageHistory.remove(this.pageHistory.size()-1);
            }
            return targetPosition;
        }
    }

    /**
     * Click handler for the progress indicator on the righthand overlay nav button.
     */
    public void overlayCount(View v) {
        String unreadText = getString((this.currentUnreadCount == 1) ? R.string.overlay_count_toast_1 : R.string.overlay_count_toast_N);
        Toast.makeText(this, String.format(unreadText, this.currentUnreadCount), Toast.LENGTH_SHORT).show();
    }

    public void overlaySend(View v) {
		Story story = readingAdapter.getStory(pager.getCurrentItem());
        FeedUtils.shareStory(story, this);
    }

    public void overlayText(View v) {
        synchronized (textMode) {
            // if we were already in text mode, switch back to story mode
            if (textMode) {
                enableStoryMode();
            } else {
                enableTextMode();
            }
        }
    }

    private void enableTextMode() {
        final Story story = readingAdapter.getStory(pager.getCurrentItem());
        if (story != null) {
            new AsyncTask<Void, Void, StoryTextResponse>() {
                @Override
                protected void onPreExecute() {
                    enableProgressCircle(overlayProgressLeft, true);
                }
                @Override
                protected StoryTextResponse doInBackground(Void... arg) {
                    return apiManager.getStoryText(story.feedId, story.id);
                }
                @Override
                protected void onPostExecute(StoryTextResponse result) {
                    ReadingItemFragment item = getReadingFragment();
                    if ((item != null) && (result != null) && (result.originalText != null)) {
                        item.setCustomWebview(result.originalText);
                    }
                    enableProgressCircle(overlayProgressLeft, false);
                }
            }.execute();
        }

        this.overlayText.setBackgroundResource(R.drawable.selector_overlay_bg_story);
        this.overlayText.setText(R.string.overlay_story);
        this.textMode = true;
    }

    private void enableStoryMode() {    
        ReadingItemFragment item = getReadingFragment();
        if (item != null) item.setDefaultWebview();

        this.overlayText.setBackgroundResource(R.drawable.selector_overlay_bg_text);
        this.overlayText.setText(R.string.overlay_text);
        this.textMode = false;
    }

    private ReadingItemFragment getReadingFragment() {
        Object o = readingAdapter.instantiateItem(pager, pager.getCurrentItem());
        if (o instanceof ReadingItemFragment) {
            return (ReadingItemFragment) o;
        } else {
            return null;
        }
    }

}
