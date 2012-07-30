package com.newsblur.activity;

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
import android.text.TextUtils;
import android.view.View;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.newsblur.R;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.ReadingAdapter;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.fragment.ShareDialogFragment;
import com.newsblur.util.UIUtils;

public class Reading extends SherlockFragmentActivity {

	public static final String EXTRA_FEED = "feed_selected";
	public static final String TAG = "ReadingActivity";
	public static final String EXTRA_POSITION = "feed_position";
	private ViewPager pager;
	private FragmentManager fragmentManager;
	private ReadingAdapter readingAdapter;
	private String feedId;
	private final int READING_LOADER = 0x01;
	private ContentResolver contentResolver;
	private Feed feed;
	private int passedPosition;

	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);
		setContentView(R.layout.activity_reading);

		fragmentManager = getSupportFragmentManager();
		feedId = getIntent().getStringExtra(EXTRA_FEED);
		passedPosition = getIntent().getIntExtra(EXTRA_POSITION, 0);

		getSupportActionBar().setDisplayHomeAsUpEnabled(true);
		
		contentResolver = getContentResolver();
		Uri storiesURI = FeedProvider.STORIES_URI.buildUpon().appendPath(feedId).build();
		Cursor stories = contentResolver.query(storiesURI, null, null, null, null);
		readingAdapter = new ReadingAdapter(fragmentManager, this, feedId, stories);
		
		final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
		feed = Feed.fromCursor(contentResolver.query(feedUri, null, null, null, null));
		setTitle(feed.title);

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

		getSupportLoaderManager().initLoader(READING_LOADER , null, readingAdapter);

		pager = (ViewPager) findViewById(R.id.reading_pager);
		pager.setPageMargin(UIUtils.convertDPsToPixels(getApplicationContext(), 1));
		pager.setPageMarginDrawable(R.drawable.divider_light);
		
		pager.setAdapter(readingAdapter);
		pager.setCurrentItem(passedPosition);
		
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

}
