package com.newsblur.activity;

import java.util.HashSet;
import java.util.Set;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.view.ViewPager;
import android.support.v4.view.ViewPager.OnPageChangeListener;
import android.text.TextUtils;
import android.view.View;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.database.MarkStoryAsReadIntenallyTask;
import com.newsblur.database.ReadingAdapter;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.fragment.ShareDialogFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.util.UIUtils;

public abstract class Reading extends SherlockFragmentActivity implements OnPageChangeListener, SyncUpdateFragment.SyncUpdateFragmentInterface {

	public static final String EXTRA_FEED = "feed_selected";
	public static final String TAG = "ReadingActivity";
	public static final String EXTRA_POSITION = "feed_position";
	public static final String EXTRA_USERID = "user_id";
	public static final String EXTRA_USERNAME = "username";

	protected int passedPosition;
	protected int currentState;
	protected String feedId;
	
	private ViewPager pager;
	private FragmentManager fragmentManager;
	protected ReadingAdapter readingAdapter;
	protected ContentResolver contentResolver;
	protected SyncUpdateFragment syncFragment;

	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(savedInstanceBundle);
		setContentView(R.layout.activity_reading);

		fragmentManager = getSupportFragmentManager();
		
		passedPosition = getIntent().getIntExtra(EXTRA_POSITION, 0);
		currentState = getIntent().getIntExtra(ItemsList.EXTRA_STATE, 0);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);
		contentResolver = getContentResolver();
		
		setResult(RESULT_OK);
	}

	protected void setupPager(Cursor stories) {
		readingAdapter = new ReadingAdapter(fragmentManager, this, stories);

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
	}
	
	protected void createFloatingHeader(final Feed feed) {
		View view = findViewById(R.id.reading_floatbar);
		GradientDrawable gradient;
		int borderColor = Color.BLACK;
		if (!TextUtils.equals(feed.faviconColour, "#null") && !TextUtils.equals(feed.faviconFade, "#null")) {
			gradient = new GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, new int[] { Color.parseColor(feed.faviconColour), Color.parseColor(feed.faviconFade)});
			borderColor = Color.parseColor(feed.faviconBorder);
		} else {
			gradient = new GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, new int[] { Color.DKGRAY, Color.LTGRAY });
		}
		Drawable[] layers = new Drawable[2];
		layers[0] = gradient;
		layers[1] = getResources().getDrawable(R.drawable.shiny_plastic);
		view.setBackgroundDrawable(new LayerDrawable(layers));

		findViewById(R.id.reading_divider).setBackgroundColor(borderColor);
		findViewById(R.id.reading_divider_bottom).setBackgroundColor(borderColor);
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
				DialogFragment newFragment = ShareDialogFragment.newInstance(story.id, story.title, feedId, null);
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
		new MarkStoryAsReadIntenallyTask(contentResolver).execute(readingAdapter.getStory(position));
	}

	@Override
	public void updateAfterSync() {
		setSupportProgressBarIndeterminateVisibility(false);
	}

	@Override
	public void updateSyncStatus(boolean syncRunning) {
		setSupportProgressBarIndeterminateVisibility(syncRunning);
	}

}
