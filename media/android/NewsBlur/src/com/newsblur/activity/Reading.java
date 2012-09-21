package com.newsblur.activity;

import java.util.ArrayList;

import android.content.ContentProviderOperation;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.content.OperationApplicationException;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.RemoteException;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.view.ViewPager;
import android.support.v4.view.ViewPager.OnPageChangeListener;
import android.text.TextUtils;
import android.util.Log;
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;
import com.newsblur.fragment.ReadingItemFragment;
import com.newsblur.fragment.ShareDialogFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.fragment.TextSizeDialogFragment;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

public abstract class Reading extends SherlockFragmentActivity implements OnPageChangeListener, SyncUpdateFragment.SyncUpdateFragmentInterface, OnSeekBarChangeListener {

	public static final String EXTRA_FEED = "feed_selected";
	public static final String TAG = "ReadingActivity";
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
	protected SyncUpdateFragment syncFragment;
	private ArrayList<ContentProviderOperation> operations;
	protected Cursor stories;
	
	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(savedInstanceBundle);
		setContentView(R.layout.activity_reading);

		operations = new ArrayList<ContentProviderOperation>();
		fragmentManager = getSupportFragmentManager();

		passedPosition = getIntent().getIntExtra(EXTRA_POSITION, 0);
		currentState = getIntent().getIntExtra(ItemsList.EXTRA_STATE, 0);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);
		contentResolver = getContentResolver();

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
		UserProfile user = PrefsUtils.getUserDetails(this);
		
		switch (item.getItemId()) {
		case android.R.id.home:
			finish();
			return true;
		case R.id.menu_reading_original:
			if (story != null) {
				Intent i = new Intent(Intent.ACTION_VIEW);
				i.setData(Uri.parse(story.permalink));
				startActivity(i);
			}
			return true;
		case R.id.menu_reading_sharenewsblur:
			if (story != null) {
				ReadingItemFragment currentFragment = (ReadingItemFragment) readingAdapter.instantiateItem(pager, currentItem);
				DialogFragment newFragment = ShareDialogFragment.newInstance(currentFragment, story, currentFragment.previouslySavedShareText);
				newFragment.show(getSupportFragmentManager(), "dialog");
			}
			return true;
		case R.id.menu_shared:
			Intent intent = new Intent(android.content.Intent.ACTION_SEND);
			intent.setType("text/plain");
			intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_WHEN_TASK_RESET);
			intent.putExtra(Intent.EXTRA_SUBJECT, story.title);
			final String shareString = getResources().getString(R.string.share);
			intent.putExtra(Intent.EXTRA_TEXT, String.format(shareString, new Object[] { story.title, story.permalink }));
			startActivity(Intent.createChooser(intent, "Share using"));
			return true;
		case R.id.menu_textsize:
			float currentValue = getSharedPreferences(PrefConstants.PREFERENCES, 0).getFloat(PrefConstants.PREFERENCE_TEXT_SIZE, 2.0f);
			TextSizeDialogFragment textSize = TextSizeDialogFragment.newInstance(currentValue);
			textSize.show(getSupportFragmentManager(), TEXT_SIZE);
			return true;	
			
		default:
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
	
	public abstract void checkStoryCount(int position);

	@Override
	public void updateSyncStatus(boolean syncRunning) {
		setSupportProgressBarIndeterminateVisibility(syncRunning);
	}

	public abstract void triggerRefresh();
	public abstract void triggerRefresh(int page);
	
	@Override
	protected void onPause() {
		if (isFinishing()) {
			try {
				contentResolver.applyBatch(FeedProvider.AUTHORITY, operations);
			} catch (RemoteException e) {
				Log.e(TAG, "Failed to do any updating.");
				e.printStackTrace();
			} catch (OperationApplicationException e) {
				Log.e(TAG, "Failed to do any updating.");
				e.printStackTrace();
			}
		}
		super.onPause();
	}

	protected void addStoryToMarkAsRead(Story story) {
			String[] selectionArgs; 
			ContentValues emptyValues = new ContentValues();
			emptyValues.put(DatabaseConstants.FEED_ID, story.feedId);
			
			if (story.getIntelligenceTotal() > 0) {
				selectionArgs = new String[] { DatabaseConstants.FEED_POSITIVE_COUNT, story.feedId } ; 
			} else if (story.getIntelligenceTotal() == 0) {
				selectionArgs = new String[] { DatabaseConstants.FEED_NEUTRAL_COUNT, story.feedId } ;
			} else {
				selectionArgs = new String[] { DatabaseConstants.FEED_NEGATIVE_COUNT, story.feedId } ;
			}
			operations.add(ContentProviderOperation.newUpdate(FeedProvider.FEED_COUNT_URI).withValues(emptyValues).withSelection("", selectionArgs).build());
			
			
			if (!TextUtils.isEmpty(story.socialUserId)) {
				String[] socialSelectionArgs; 
				if (story.getIntelligenceTotal() > 0) {
					socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT, story.socialUserId } ; 
				} else if (story.getIntelligenceTotal() == 0) {
					socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT, story.socialUserId } ;
				} else {
					socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT, story.socialUserId } ;
				}
				operations.add(ContentProviderOperation.newUpdate(FeedProvider.SOCIALCOUNT_URI).withValues(emptyValues).withSelection("", socialSelectionArgs).build());
			}

			Uri storyUri = FeedProvider.STORY_URI.buildUpon().appendPath(story.id).build();
			ContentValues values = new ContentValues();
			values.put(DatabaseConstants.STORY_READ, true);
			
			operations.add(ContentProviderOperation.newUpdate(storyUri).withValues(values).build());
	}
	

	@Override
	public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
		getSharedPreferences(PrefConstants.PREFERENCES, 0).edit().putFloat(PrefConstants.PREFERENCE_TEXT_SIZE, (float) progress / 2).commit();
		Intent data = new Intent(ReadingItemFragment.TEXT_SIZE_CHANGED);
		data.putExtra(ReadingItemFragment.TEXT_SIZE_VALUE, (float) progress / 2f); 
		
		sendBroadcast(data);
	}

	@Override
	public void onStartTrackingTouch(SeekBar seekBar) {
	}

	@Override
	public void onStopTrackingTouch(SeekBar seekBar) {
	}

	


}
