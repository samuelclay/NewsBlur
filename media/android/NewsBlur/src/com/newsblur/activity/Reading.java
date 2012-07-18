package com.newsblur.activity;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.view.ViewPager;
import android.util.Log;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.newsblur.R;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.ReadingAdapter;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.service.DetachableResultReceiver;
import com.newsblur.service.DetachableResultReceiver.Receiver;
import com.newsblur.service.SyncService;

public class Reading extends SherlockFragmentActivity {

	public static final String EXTRA_FEED = "feed_selected";
	public static final String TAG = "ReadingActivity";
	private ViewPager pager;
	private SyncReadingUpdaterFragment syncFragment;
	private FragmentManager fragmentManager;
	private ReadingAdapter readingAdapter;
	private String feedId;
	private final int READING_LOADER = 0x01;
	private ContentResolver contentResolver;
	private Feed feed;

	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);
		setContentView(R.layout.activity_reading);

		fragmentManager = getSupportFragmentManager();
		feedId = getIntent().getStringExtra(EXTRA_FEED);

		getSupportActionBar().setDisplayHomeAsUpEnabled(true);
		readingAdapter = new ReadingAdapter(fragmentManager, this, feedId);
		getSupportLoaderManager().initLoader(READING_LOADER , null, readingAdapter);

		contentResolver = getContentResolver();
		final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();

		feed = Feed.fromCursor(contentResolver.query(feedUri, null, null, null, null));
		setTitle(feed.title);

		syncFragment = (SyncReadingUpdaterFragment) fragmentManager.findFragmentByTag(SyncReadingUpdaterFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncReadingUpdaterFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncReadingUpdaterFragment.TAG).commit();
			triggerRefresh();
		}

		pager = (ViewPager) findViewById(R.id.reading_pager);
		pager.setAdapter(readingAdapter);
	}
	
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getSupportMenuInflater();
	    inflater.inflate(R.menu.reading, menu);
	    return true;
	}
	
	public void triggerRefresh() {
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_FEED_UPDATE);
		intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, feedId);
		startService(intent);
	}

	public void redrawUI() {
		Log.d(TAG, "Redrawing reading pager...");
		getSupportLoaderManager().restartLoader(READING_LOADER, null, readingAdapter);
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		int currentItem = pager.getCurrentItem();
		Story story = readingAdapter.getStory(currentItem);
		
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
		case R.id.menu_shared:
			Intent intent = new Intent(android.content.Intent.ACTION_SEND);
			intent.setType("text/plain");
			intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_WHEN_TASK_RESET);
			intent.putExtra(Intent.EXTRA_SUBJECT, story.title);
			final String shareString = getResources().getString(R.string.share);
			intent.putExtra(Intent.EXTRA_TEXT, String.format(shareString, new String[] { story.title, story.permalink }));
			startActivity(Intent.createChooser(intent, "Share using"));
			return true;
		default:
			return super.onOptionsItemSelected(item);	
		}
	}

	public static class SyncReadingUpdaterFragment extends Fragment implements Receiver {
		public static final String TAG = "SyncReadingFragment";
		private DetachableResultReceiver receiver;

		public SyncReadingUpdaterFragment() {
			receiver = new DetachableResultReceiver(new Handler());
			receiver.setReceiver(this);
		}

		@Override
		public void onCreate(Bundle savedInstanceState) {
			super.onCreate(savedInstanceState);
			setRetainInstance(true);
			Log.d(TAG, "Creating syncfragment");
		}

		@Override
		public void onAttach(Activity activity) {
			super.onAttach(activity);
			Log.d(TAG, "Attached");
		}

		@Override
		public void onReceiverResult(int resultCode, Bundle resultData) {
			switch (resultCode) {
			case SyncService.STATUS_FINISHED:
				Log.d(TAG, "Synchronisation finished.");
				((Reading) getActivity()).redrawUI();
				break;
			case SyncService.STATUS_RUNNING:
				Log.d(TAG, "Synchronisation running.");
				break;		
			default:
				Log.e(TAG, "Unrecognised response attempting to get reading data");
				break;
			}
		}

	}


}
