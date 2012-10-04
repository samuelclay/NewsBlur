package com.newsblur.activity;

import java.util.ArrayList;

import android.app.SearchManager;
import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.LoaderManager.LoaderCallbacks;
import android.support.v4.content.Loader;
import android.util.Log;
import android.view.View;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ListView;
import android.widget.TextView;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.domain.FeedResult;
import com.newsblur.fragment.AddFeedFragment;
import com.newsblur.network.SearchAsyncTaskLoader;

public class SearchForFeeds extends SherlockFragmentActivity implements LoaderCallbacks<ArrayList<FeedResult>>, OnItemClickListener {
	private static final int LOADER_TWITTER_SEARCH = 0x01;
	private Menu menu;
	private ListView resultsList;
	private Loader<ArrayList<FeedResult>> searchLoader;
	private FeedSearchResultAdapter adapter;

	@Override
	protected void onCreate(Bundle arg0) {
		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(arg0);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);
		
		setTitle(R.string.title_feed_search);
		setContentView(R.layout.activity_feed_search);
		
		TextView emptyView = (TextView) findViewById(R.id.empty_view);
		resultsList = (ListView) findViewById(R.id.feed_result_list);
		resultsList.setEmptyView(emptyView);
		resultsList.setOnItemClickListener(this);
		resultsList.setItemsCanFocus(false);
		searchLoader = getSupportLoaderManager().initLoader(LOADER_TWITTER_SEARCH, new Bundle(), this);
		
		onSearchRequested();
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getSupportMenuInflater();
		inflater.inflate(R.menu.search, menu);
		this.menu = menu;
		return true;
	}

	@Override
	protected void onNewIntent(Intent intent) {
		setIntent(intent);
		handleIntent(intent);
	}

	private void handleIntent(Intent intent) {
		if (Intent.ACTION_SEARCH.equals(intent.getAction())) {
			String query = intent.getStringExtra(SearchManager.QUERY);
			setSupportProgressBarIndeterminateVisibility(true);
			
			Bundle bundle = new Bundle();
			bundle.putString(SearchAsyncTaskLoader.SEARCH_TERM, query);
			searchLoader = getSupportLoaderManager().restartLoader(LOADER_TWITTER_SEARCH, bundle, this);
			
			searchLoader.forceLoad();
		}
	}


	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {

		case R.id.menu_search:
			onSearchRequested();
			return true;	

		case android.R.id.home:
			finish();
			return true;

		}
		return super.onOptionsItemSelected(item);
	}

	@Override
	public Loader<ArrayList<FeedResult>> onCreateLoader(int loaderId, Bundle bundle) {
		String searchTerm = bundle.getString(SearchAsyncTaskLoader.SEARCH_TERM);
		return new SearchAsyncTaskLoader(this, searchTerm);
	}

	@Override
	public void onLoadFinished(Loader<ArrayList<FeedResult>> loader, ArrayList<FeedResult> results) {
		adapter = new FeedSearchResultAdapter(this, 0, 0, results);
		resultsList.setAdapter(adapter);
		setSupportProgressBarIndeterminateVisibility(false);
	}

	@Override
	public void onLoaderReset(Loader<ArrayList<FeedResult>> loader) {
		
	}

	@Override
	public void onItemClick(AdapterView<?> arg0, View view, int position, long id) {
		FeedResult result = adapter.getItem(position);
		DialogFragment addFeedFragment = AddFeedFragment.newInstance(result.url, result.label);
		addFeedFragment.show(getSupportFragmentManager(), "dialog");
	}

}
