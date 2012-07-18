package com.newsblur.fragment;

import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.util.ImageLoader;

public class ReadingItemFragment extends Fragment {

	final Story story;
	private ImageLoader imageLoader;
	
	public ReadingItemFragment() {
		story = null;
	}
	
	public ReadingItemFragment(final Story story) {
		this.story = story;
	}
	
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View view = inflater.inflate(R.layout.fragment_readingitem, null);
		
		WebView web = (WebView) view.findViewById(R.id.reading_webview);
		imageLoader = new ImageLoader(getActivity());	
		setupWebview(web);
		setupItemMetadata(view);
		
		return view;
	}

	private void setupItemMetadata(View view) {
		TextView itemTitle = (TextView) view.findViewById(R.id.reading_item_title);
		TextView itemDate = (TextView) view.findViewById(R.id.reading_item_date);
		TextView itemAuthors = (TextView) view.findViewById(R.id.reading_item_authors);
		TextView itemCommentCount = (TextView) view.findViewById(R.id.reading_item_comment_count);
		
		itemDate.setText(story.date);
		itemTitle.setText(story.title);
		itemAuthors.setText(story.authors);
		itemCommentCount.setText(story.commentCount == null ? "0" : story.commentCount.toString());
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
		web.setScrollBarStyle(WebView.SCROLLBARS_OUTSIDE_OVERLAY);
		StringBuilder builder = new StringBuilder();
		// TODO: Define a better strategy for rescaling the HTML across device screen sizes and storying this HTML as boilderplate somewhere
		builder.append("<html><head><meta name=\"viewport\" content=\"target-densitydpi=device-dpi\" /><link rel=\"stylesheet\" type=\"text/css\" href=\"reading.css\" /></head><body>");
		builder.append(story.content);
		builder.append("</body></html>");
		web.loadDataWithBaseURL("file:///android_asset/", builder.toString(), "text/html", "UTF-8", null);
	}

	
}
