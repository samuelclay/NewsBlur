package com.newsblur.activity;

import android.app.SearchManager;
import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.LoaderManager.LoaderCallbacks;
import android.support.v4.content.Loader;
import android.view.View;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.domain.FeedResult;
import com.newsblur.fragment.AddFeedFragment;
import com.newsblur.network.SearchAsyncTaskLoader;
import com.newsblur.network.SearchLoaderResponse;

public class SearchForFeeds extends NbFragmentActivity implements LoaderCallbacks<SearchLoaderResponse>, OnItemClickListener {
	private static final int LOADER_TWITTER_SEARCH = 0x01;
	private ListView resultsList;
	private Loader<SearchLoaderResponse> searchLoader;
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
		if (item.getItemId() == R.id.menu_search) {
			onSearchRequested();
			return true;
		} else if (item.getItemId() == android.R.id.home) {
			finish();
			return true;
		}
		return super.onOptionsItemSelected(item);
	}

	@Override
	public Loader<SearchLoaderResponse> onCreateLoader(int loaderId, Bundle bundle) {
		String searchTerm = bundle.getString(SearchAsyncTaskLoader.SEARCH_TERM);
		return new SearchAsyncTaskLoader(this, searchTerm);
	}

	@Override
	public void onLoadFinished(Loader<SearchLoaderResponse> loader, SearchLoaderResponse results) {
		setSupportProgressBarIndeterminateVisibility(false);
		if(!results.hasError()) {
			adapter = new FeedSearchResultAdapter(this, 0, 0, results.getResults());
			resultsList.setAdapter(adapter);
		} else {
			String message = results.getErrorMessage() == null ? "Error" : results.getErrorMessage();
			Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
		}
	}

	@Override
	public void onLoaderReset(Loader<SearchLoaderResponse> loader) {
		
	}

	@Override
	public void onItemClick(AdapterView<?> arg0, View view, int position, long id) {
		FeedResult result = adapter.getItem(position);
		DialogFragment addFeedFragment = AddFeedFragment.newInstance(result.url, result.label);
		addFeedFragment.show(getSupportFragmentManager(), "dialog");
	}

}
