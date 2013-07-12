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
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;

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
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.UIUtils;

public abstract class Reading extends NbFragmentActivity implements OnPageChangeListener, SyncUpdateFragment.SyncUpdateFragmentInterface, OnSeekBarChangeListener {

	public static final String EXTRA_FEED = "feed_selected";
	public static final String EXTRA_POSITION = "feed_position";
	public static final String EXTRA_USERID = "user_id";
	public static final String EXTRA_USERNAME = "username";
	public static final String EXTRA_FOLDERNAME = "foldername";
	public static final String EXTRA_FEED_IDS = "feed_ids";
	private static final String TEXT_SIZE = "textsize";

	protected int passedPosition;
	protected int currentState;

	protected ViewPager pager;
	protected FragmentManager fragmentManager;
	protected ReadingAdapter readingAdapter;
	protected ContentResolver contentResolver;
    private APIManager apiManager;
	protected SyncUpdateFragment syncFragment;
	protected Cursor stories;

	private Set<Story> storiesToMarkAsRead;

	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(savedInstanceBundle);
		setContentView(R.layout.activity_reading);

		fragmentManager = getSupportFragmentManager();
		
        storiesToMarkAsRead = new HashSet<Story>();

		passedPosition = getIntent().getIntExtra(EXTRA_POSITION, 0);
		currentState = getIntent().getIntExtra(ItemsList.EXTRA_STATE, 0);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);
		contentResolver = getContentResolver();

        this.apiManager = new APIManager(this);

	}

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
		readingAdapter.setCurrentItem(passedPosition);
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
			Intent intent = new Intent(android.content.Intent.ACTION_SEND);
			intent.setType("text/plain");
			intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_WHEN_TASK_RESET);
			intent.putExtra(Intent.EXTRA_SUBJECT, story.title);
			final String shareString = getResources().getString(R.string.share);
			intent.putExtra(Intent.EXTRA_TEXT, String.format(shareString, new Object[] { story.title, story.permalink }));
			startActivity(Intent.createChooser(intent, "Share using"));
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

	@Override
	public void onPageScrollStateChanged(int arg0) {
	}

	@Override
	public void onPageScrolled(int arg0, float arg1, int arg2) {
	}

	@Override
	public void onPageSelected(final int position) {
	}

	@Override
	public void updateAfterSync() {
		setSupportProgressBarIndeterminateVisibility(false);
		stories.requery();
		readingAdapter.notifyDataSetChanged();
		checkStoryCount(pager.getCurrentItem());
	}

	@Override
	public void updatePartialSync() {
		stories.requery();
		readingAdapter.notifyDataSetChanged();
		checkStoryCount(pager.getCurrentItem());
	}

	public abstract void checkStoryCount(int position);

	@Override
	public void updateSyncStatus(boolean syncRunning) {
		setSupportProgressBarIndeterminateVisibility(syncRunning);
	}

	public abstract void triggerRefresh();
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




}
