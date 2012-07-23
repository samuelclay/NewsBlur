package com.newsblur.fragment;

import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.support.v7.widget.GridLayout;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.Story;

public class ReadingItemFragment extends Fragment {

	Story story;
	LayoutInflater inflater;
	
	public static ReadingItemFragment newInstance(Story story) { 
		ReadingItemFragment readingFragment = new ReadingItemFragment();
		
		// Supply num input as an argument.
        Bundle args = new Bundle();
        args.putSerializable("story", story);
        readingFragment.setArguments(args);
        
        return readingFragment;
	}
	
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		story = getArguments() != null ? (Story) getArguments().getSerializable("story") : null;
	}
	
	public View onCreateView(final LayoutInflater inflater, final ViewGroup container, final Bundle savedInstanceState) {
		this.inflater = inflater;
		
		View view = inflater.inflate(R.layout.fragment_readingitem, null);
		WebView web = (WebView) view.findViewById(R.id.reading_webview);
		setupWebview(web);
		setupItemMetadata(view);
		
		return view;
	}

	private void setupItemMetadata(View view) {
		TextView itemTitle = (TextView) view.findViewById(R.id.reading_item_title);
		TextView itemDate = (TextView) view.findViewById(R.id.reading_item_date);
		TextView itemAuthors = (TextView) view.findViewById(R.id.reading_item_authors);
		GridLayout tagContainer = (GridLayout) view.findViewById(R.id.reading_item_tags);
		
		if (story.tags != null || story.tags.length > 0) {
			tagContainer.setVisibility(View.VISIBLE);
			for (String tag : story.tags) {
				View v = inflater.inflate(R.layout.tag_view, null);
				TextView tagText = (TextView) v.findViewById(R.id.tag_text);
				tagText.setText(tag);
				tagContainer.addView(v);
			}
		}
		
		itemDate.setText(story.date);
		itemTitle.setText(story.title);
		itemAuthors.setText(story.authors);
	}

	private void setupWebview(WebView web) {
		web.getSettings().setLoadWithOverviewMode(true);
		web.getSettings().setCacheMode(WebSettings.LOAD_CACHE_ELSE_NETWORK);
		web.getSettings().setDomStorageEnabled(true);
		web.getSettings().setSupportZoom(true);
		web.getSettings().setAppCacheMaxSize(1024*1024*8);
		web.getSettings().setAppCachePath("/data/data/com.newsblur/cache");
		web.getSettings().setAllowFileAccess(true);
		web.getSettings().setAppCacheEnabled(true);
		web.setVerticalScrollBarEnabled(false);
		web.setHorizontalScrollBarEnabled(false);
		
		StringBuilder builder = new StringBuilder();
		// TODO: Define a better strategy for rescaling the HTML across device screen sizes and storying this HTML as boilderplate somewhere
		builder.append("<html><head><meta name=\"viewport\" content=\"target-densitydpi=device-dpi\" /><link rel=\"stylesheet\" type=\"text/css\" href=\"reading.css\" /></head><body>");
		builder.append(story.content);
		builder.append("</body></html>");
		web.loadDataWithBaseURL("file:///android_asset/", builder.toString(), "text/html", "UTF-8", null);
	}

	
}
