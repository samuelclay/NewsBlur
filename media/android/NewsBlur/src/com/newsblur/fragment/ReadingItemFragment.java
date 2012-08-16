package com.newsblur.fragment;

import android.content.ContentResolver;
import android.graphics.Color;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.NewsBlurApplication;
import com.newsblur.domain.Story;
import com.newsblur.network.APIManager;
import com.newsblur.network.SetupCommentSectionTask;
import com.newsblur.util.ImageLoader;

public class ReadingItemFragment extends Fragment {

	private static final String TAG = "ReadingItemFragment";
	public Story story;
	private LayoutInflater inflater;
	private APIManager apiManager;
	private ImageLoader imageLoader;
	private String feedColor;
	private String feedFade;
	private ContentResolver resolver;

	public static ReadingItemFragment newInstance(Story story, String feedFaviconColor, String feedFaviconFade) { 
		ReadingItemFragment readingFragment = new ReadingItemFragment();

		Bundle args = new Bundle();
		args.putSerializable("story", story);
		args.putString("feedColor", feedFaviconColor);
		args.putString("feedFade", feedFaviconFade);
		readingFragment.setArguments(args);

		return readingFragment;
	}


	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		imageLoader = ((NewsBlurApplication) getActivity().getApplicationContext()).getImageLoader();
		apiManager = new APIManager(getActivity());
		story = getArguments() != null ? (Story) getArguments().getSerializable("story") : null;

		resolver = getActivity().getContentResolver();
		inflater = getActivity().getLayoutInflater();
		
		feedColor = getArguments().getString("feedColor");
		feedFade = getArguments().getString("feedFade");
	}

	public View onCreateView(final LayoutInflater inflater, final ViewGroup container, final Bundle savedInstanceState) {
		this.inflater = inflater;

		View view = inflater.inflate(R.layout.fragment_readingitem, null);


		WebView web = (WebView) view.findViewById(R.id.reading_webview);
		setupWebview(web);
		setupItemMetadata(view);
		if (story.sharedUserIds.length > 0 || story.commentCount > 0 ) {
			view.findViewById(R.id.reading_shared_container).setVisibility(View.VISIBLE);
			setupItemCommentsAndShares(view);
		}

		return view;
	}

	private void setupItemCommentsAndShares(final View view) {
		new SetupCommentSectionTask(getActivity(), view, inflater, resolver, apiManager, story, imageLoader).execute();
	}


	private void setupItemMetadata(View view) {

		View borderOne = view.findViewById(R.id.row_item_favicon_borderbar_1);
		View borderTwo = view.findViewById(R.id.row_item_favicon_borderbar_2);

		if (!TextUtils.equals(feedColor, "#null") && !TextUtils.equals(feedFade, "#null")) {
			borderOne.setBackgroundColor(Color.parseColor(feedColor));
			borderTwo.setBackgroundColor(Color.parseColor(feedFade));
		} else {
			borderOne.setBackgroundColor(Color.GRAY);
			borderTwo.setBackgroundColor(Color.LTGRAY);
		}

		View sidebar = view.findViewById(R.id.row_item_sidebar);
		int storyIntelligence = story.intelligence.intelligenceAuthors + story.intelligence.intelligenceTags + story.intelligence.intelligenceFeed + story.intelligence.intelligenceTitle;
		if (storyIntelligence > 0) {
			sidebar.setBackgroundResource(R.drawable.positive_count_circle);
		} else if (storyIntelligence == 0) {
			sidebar.setBackgroundResource(R.drawable.neutral_count_circle);
		} else {
			sidebar.setBackgroundResource(R.drawable.negative_count_circle);
		}

		TextView itemTitle = (TextView) view.findViewById(R.id.reading_item_title);
		TextView itemDate = (TextView) view.findViewById(R.id.reading_item_date);
		TextView itemAuthors = (TextView) view.findViewById(R.id.reading_item_authors);

		itemDate.setText(story.shortDate);
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
		// TODO: Define a better strategy for rescaling the HTML across device screen sizes and storying this HTML as boilerplate somewhere
		builder.append("<html><head><meta name=\"viewport\" content=\"target-densitydpi=device-dpi\" /><link rel=\"stylesheet\" type=\"text/css\" href=\"reading.css\" /></head><body>");
		builder.append(story.content);
		builder.append("</body></html>");
		web.loadDataWithBaseURL("file:///android_asset/", builder.toString(), "text/html", "UTF-8", null);
	}


}
