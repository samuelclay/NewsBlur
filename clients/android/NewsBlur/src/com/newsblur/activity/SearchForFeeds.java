package com.newsblur.activity;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.HashSet;
import java.util.Set;

import android.app.SearchManager;
import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.LoaderManager.LoaderCallbacks;
import android.support.v4.content.Loader;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.domain.FeedResult;
import com.newsblur.fragment.AddFeedFragment;
import com.newsblur.network.SearchAsyncTaskLoader;
import com.newsblur.network.SearchLoaderResponse;

// TODO: this activity's use of the inbuilt activity search facility as well as an improper use of a loader to
//       make network requests makes it easily lose state, lack non-legacy progress indication, and generally
//       buggy. a normal layout and a proper use of sync for search results should be implemented.
public class SearchForFeeds extends NbActivity implements LoaderCallbacks<SearchLoaderResponse>, OnItemClickListener, AddFeedFragment.AddFeedProgressListener {
    
    private static final Set<String> SUPPORTED_URL_PROTOCOLS = new HashSet<String>();
    static {
        SUPPORTED_URL_PROTOCOLS.add("http");
        SUPPORTED_URL_PROTOCOLS.add("https");
    }

	private ListView resultsList;
	private Loader<SearchLoaderResponse> searchLoader;
	private FeedSearchResultAdapter adapter;

	@Override
	protected void onCreate(Bundle arg0) {
		super.onCreate(arg0);
		getActionBar().setDisplayHomeAsUpEnabled(true);
		
		setTitle(R.string.title_feed_search);
		setContentView(R.layout.activity_feed_search);
		
		TextView emptyView = (TextView) findViewById(R.id.empty_view);
		resultsList = (ListView) findViewById(R.id.feed_result_list);
		resultsList.setEmptyView(emptyView);
		resultsList.setOnItemClickListener(this);
		resultsList.setItemsCanFocus(false);
		searchLoader = getSupportLoaderManager().initLoader(0, new Bundle(), this);
		
		onSearchRequested();
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getMenuInflater();
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

            // test to see if a feed URL was passed rather than a search term
            if (tryAddByURL(query)) { return; }
			
			Bundle bundle = new Bundle();
			bundle.putString(SearchAsyncTaskLoader.SEARCH_TERM, query);
			searchLoader = getSupportLoaderManager().restartLoader(0, bundle, this);
			
			searchLoader.forceLoad();
		}
	}

    /**
     * See if the text entered in the query field was actually a URL so we can skip the
     * search step and just let users who know feed URLs directly subscribe.
     */
    private boolean tryAddByURL(String s) {
        URL u = null;
        try {
            u = new URL(s);
        } catch (MalformedURLException mue) {
            ; // this just signals that the string wasn't a URL, we will return
        }
        if (u == null) { return false; }
        if (! SUPPORTED_URL_PROTOCOLS.contains(u.getProtocol())) { return false; };
        if ((u.getHost() == null) || (u.getHost().trim().isEmpty())) { return false; }

		DialogFragment addFeedFragment = AddFeedFragment.newInstance(s, s);
		addFeedFragment.show(getSupportFragmentManager(), "dialog");
        return true;
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

    @Override
    public void addFeedStarted() {
        runOnUiThread(new Runnable() {
            public void run() {
                // TODO: this UI should offer some progress indication, since the add API call can block for several seconds
            }
        });
    }

}
