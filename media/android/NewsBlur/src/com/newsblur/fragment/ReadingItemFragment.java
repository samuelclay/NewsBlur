package com.newsblur.fragment;

import android.content.BroadcastReceiver;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.support.v7.widget.GridLayout;
import android.text.TextUtils;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.NewsBlurApplication;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.network.APIManager;
import com.newsblur.network.SetupCommentSectionTask;
import com.newsblur.service.DetachableResultReceiver;
import com.newsblur.service.DetachableResultReceiver.Receiver;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefConstants;
import com.newsblur.view.NewsblurWebview;

public class ReadingItemFragment extends Fragment {

	private static final String TAG = "ReadingItemFragment";
	public static final String TEXT_SIZE_CHANGED = "textSizeChanged";
	public static final String TEXT_SIZE_VALUE = "textSizeChangeValue";
	public Story story;
	private LayoutInflater inflater;
	private APIManager apiManager;
	private ImageLoader imageLoader;
	private String feedColor;
	private Classifier classifier;
	private String feedFade;
	private ContentResolver resolver;
	private NewsblurWebview web;
	private BroadcastReceiver receiver;

	public static ReadingItemFragment newInstance(Story story, String feedFaviconColor, String feedFaviconFade, Classifier classifier) { 
		ReadingItemFragment readingFragment = new ReadingItemFragment();

		Bundle args = new Bundle();
		args.putSerializable("story", story);
		args.putString("feedColor", feedFaviconColor);
		args.putString("feedFade", feedFaviconFade);
		args.putSerializable("classifier", classifier);
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

		classifier = (Classifier) getArguments().getSerializable("classifier");
		
		receiver = new TextSizeReceiver();
		getActivity().registerReceiver(receiver, new IntentFilter(TEXT_SIZE_CHANGED));
	}
	
	@Override
	public void onDestroy() {
		getActivity().unregisterReceiver(receiver);
		super.onDestroy();
	}

	public View onCreateView(final LayoutInflater inflater, final ViewGroup container, final Bundle savedInstanceState) {
		this.inflater = inflater;

		View view = inflater.inflate(R.layout.fragment_readingitem, null);

		web = (NewsblurWebview) view.findViewById(R.id.reading_webview);
		setupWebview(web);
		setupItemMetadata(view);
		if (story.sharedUserIds.length > 0 || story.commentCount > 0 ) {
			view.findViewById(R.id.reading_shared_container).setVisibility(View.VISIBLE);
			setupItemCommentsAndShares(view);
		}

		return view;
	}

	public void changeTextSize(float newTextSize) {
		if (web != null) {
			web.setTextSize(newTextSize);
		}
	}

	private void setupItemCommentsAndShares(final View view) {
		new SetupCommentSectionTask(getActivity(), view, getFragmentManager(), inflater, resolver, apiManager, story, imageLoader).execute();
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

		if (story.getIntelligenceTotal() > 0) {
			sidebar.setBackgroundResource(R.drawable.positive_count_circle);
		} else if (story.getIntelligenceTotal() == 0) {
			sidebar.setBackgroundResource(R.drawable.neutral_count_circle);
		} else {
			sidebar.setBackgroundResource(R.drawable.negative_count_circle);
		}

		TextView itemTitle = (TextView) view.findViewById(R.id.reading_item_title);
		TextView itemDate = (TextView) view.findViewById(R.id.reading_item_date);
		TextView itemAuthors = (TextView) view.findViewById(R.id.reading_item_authors);

		itemDate.setText(story.shortDate);
		itemTitle.setText(story.title);
		itemAuthors.setText(story.authors.toUpperCase());

		itemTitle.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				Intent i = new Intent(Intent.ACTION_VIEW);
				i.setData(Uri.parse(story.permalink));
				startActivity(i);
			}
		});

		setupTags(view);
	}


	private void setupTags(View view) {
		GridLayout tagContainer = (GridLayout) view.findViewById(R.id.reading_item_tags);

		if (story.tags != null || story.tags.length > 0) {
			tagContainer.setVisibility(View.VISIBLE);
			for (final String tag : story.tags) {
				View v = inflater.inflate(R.layout.tag_view, null);
				GridLayout.LayoutParams params = new GridLayout.LayoutParams();
				params.columnSpec = GridLayout.spec(1, 1);
				TextView tagText = (TextView) v.findViewById(R.id.tag_text);
				tagText.setText(tag);

				if (classifier != null && classifier.tags.containsKey(tag)) {
					switch (classifier.tags.get(tag)) {
					case Classifier.LIKE:
						tagText.setBackgroundResource(R.drawable.tag_background_positive);
						break;
					case Classifier.DISLIKE:
						tagText.setBackgroundResource(R.drawable.tag_background_negative);
						break;
					}
				}

				v.setOnClickListener(new OnClickListener() {
					@Override
					public void onClick(View view) {
						ClassifierDialogFragment classifierFragment = ClassifierDialogFragment.newInstance(story.feedId, classifier, tag, Classifier.TAG);
						classifierFragment.show(ReadingItemFragment.this.getFragmentManager(), "dialog");
					}
				});

				tagContainer.addView(v);
			}
		}
	}

	private void setupWebview(NewsblurWebview web) {
		final SharedPreferences preferences = getActivity().getSharedPreferences(PrefConstants.PREFERENCES, 0);
		float currentSize = preferences.getFloat(PrefConstants.PREFERENCE_TEXT_SIZE, 1.0f);
		
		StringBuilder builder = new StringBuilder();
		builder.append("<html><head><meta name=\"viewport\" content=\"target-densitydpi=device-dpi\" />");
		builder.append("<style style=\"text/css\">");
		builder.append(String.format("body { font-size: %s em; } ", Float.toString(currentSize)));
		builder.append("</style>");
		builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"reading.css\" /></head><body>");
		builder.append(story.content);
		builder.append("</body></html>");
		web.loadDataWithBaseURL("file:///android_asset/", builder.toString(), "text/html", "UTF-8", null);
		
	}

	private class TextSizeReceiver extends BroadcastReceiver {
		@Override
		public void onReceive(Context context, Intent intent) {
			web.setTextSize(intent.getFloatExtra(TEXT_SIZE_VALUE, 1.0f));
		}   
	}

}
