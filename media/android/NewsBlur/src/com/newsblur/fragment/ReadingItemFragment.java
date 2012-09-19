package com.newsblur.fragment;

import android.content.BroadcastReceiver;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.TransitionDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.Fragment;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.GridView;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.NewsBlurApplication;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;
import com.newsblur.network.APIManager;
import com.newsblur.network.SetupCommentSectionTask;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtil;
import com.newsblur.util.UIUtils;
import com.newsblur.view.NewsblurWebview;
import com.newsblur.view.TagAdapter;

public class ReadingItemFragment extends Fragment implements ClassifierDialogFragment.TagUpdateCallback, ShareDialogFragment.SharedCallbackDialog {

	private static final long serialVersionUID = -5737027559180364671L;
	private static final String TAG = "ReadingItemFragment";
	public static final String TEXT_SIZE_CHANGED = "textSizeChanged";
	public static final String TEXT_SIZE_VALUE = "textSizeChangeValue";
	public Story story;
	private LayoutInflater inflater;
	private APIManager apiManager;
	private ImageLoader imageLoader;
	private String feedColor, feedTitle, feedFade;
	private Classifier classifier;
	private ContentResolver resolver;
	private NewsblurWebview web;
	private BroadcastReceiver receiver;
	private TextView itemAuthors;
	private TextView itemFeed;
	private TagAdapter tagAdapter;
	private GridView tagContainer;
	private View view;
	private UserProfile user;
	public String previouslySavedShareText;

	public static ReadingItemFragment newInstance(Story story, String feedTitle, String feedFaviconColor, String feedFaviconFade, Classifier classifier) { 
		ReadingItemFragment readingFragment = new ReadingItemFragment();

		Bundle args = new Bundle();
		args.putSerializable("story", story);
		args.putString("feedTitle", feedTitle);
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
		

		user = PrefsUtil.getUserDetails(getActivity());

		feedTitle = getArguments().getString("feedTitle");
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

		view = inflater.inflate(R.layout.fragment_readingitem, null);

		web = (NewsblurWebview) view.findViewById(R.id.reading_webview);
		setupWebview(web);
		setupItemMetadata(view);
		setupShareButton(view);
		
		if (story.sharedUserIds.length > 0 || story.commentCount > 0 ) {
			view.findViewById(R.id.reading_share_bar).setVisibility(View.VISIBLE);
			view.findViewById(R.id.share_bar_underline).setVisibility(View.VISIBLE);
			setupItemCommentsAndShares(view);
		}

		return view;
	}

	private void setupShareButton(View view) {

		Button shareButton = (Button) view.findViewById(R.id.share_story_button);
		
		for (String userId : story.sharedUserIds) {
			if (TextUtils.equals(userId, user.id)) {
				shareButton.setText(R.string.edit);
				break;
			}
		}
		
		shareButton.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				DialogFragment newFragment = ShareDialogFragment.newInstance(ReadingItemFragment.this, story, previouslySavedShareText);
				newFragment.show(getFragmentManager(), "dialog");
			}
		});
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

		TextView itemTitle = (TextView) view.findViewById(R.id.reading_item_title);
		TextView itemDate = (TextView) view.findViewById(R.id.reading_item_date);
		itemAuthors = (TextView) view.findViewById(R.id.reading_item_authors);
		itemFeed = (TextView) view.findViewById(R.id.reading_feed_title);

		itemDate.setText(story.shortDate);
		itemTitle.setText(story.title);
		
		if (!TextUtils.isEmpty(story.authors)) {
			itemAuthors.setText(story.authors.toUpperCase());
		}
		
		itemAuthors.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				ClassifierDialogFragment classifierFragment = ClassifierDialogFragment.newInstance(ReadingItemFragment.this, story.feedId, classifier, story.authors, Classifier.AUTHOR);
				classifierFragment.show(getFragmentManager(), "dialog");		
			}	
		});
		
		itemFeed.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				ClassifierDialogFragment classifierFragment = ClassifierDialogFragment.newInstance(ReadingItemFragment.this, story.feedId, classifier, feedTitle, Classifier.FEED);
				classifierFragment.show(getFragmentManager(), "dialog");
			}
		});
		
		itemFeed.setText(feedTitle);

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
		tagContainer = (GridView) view.findViewById(R.id.reading_item_tags);
		tagAdapter = new TagAdapter(getActivity(), getFragmentManager(), this, story.feedId, classifier, story.tags);
		tagContainer.setAdapter(tagAdapter);
	}

	private void setupWebview(NewsblurWebview web) {
		final SharedPreferences preferences = getActivity().getSharedPreferences(PrefConstants.PREFERENCES, 0);
		float currentSize = preferences.getFloat(PrefConstants.PREFERENCE_TEXT_SIZE, 1.0f);
		
		StringBuilder builder = new StringBuilder();
		builder.append("<html><head><meta name=\"viewport\" content=\"target-densitydpi=device-dpi\" />");
		builder.append("<style style=\"text/css\">");
		builder.append(String.format("body { font-size: %s em; } ", Float.toString(currentSize + 0.5f)));
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

	@Override
	public void updateTagView(String key, int classifierType, int classifierAction) {
		switch (classifierType) {
			case Classifier.AUTHOR:
				switch (classifierAction) {
					case Classifier.LIKE:
						itemAuthors.setTextColor(getActivity().getResources().getColor(R.color.positive));
						break;
					case Classifier.DISLIKE:
						itemAuthors.setTextColor(getActivity().getResources().getColor(R.color.negative));
						break;
					case Classifier.CLEAR_DISLIKE:
						itemAuthors.setTextColor(getActivity().getResources().getColor(R.color.darkgray));
						break;
					case Classifier.CLEAR_LIKE:
						itemAuthors.setTextColor(getActivity().getResources().getColor(R.color.darkgray));
						break;	
				}
				break;
			case Classifier.FEED:
				switch (classifierAction) {
				case Classifier.LIKE:
					itemFeed.setTextColor(getActivity().getResources().getColor(R.color.positive));
					break;
				case Classifier.DISLIKE:
					itemFeed.setTextColor(getActivity().getResources().getColor(R.color.negative));
					break;
				case Classifier.CLEAR_DISLIKE:
					itemFeed.setTextColor(getActivity().getResources().getColor(R.color.darkgray));
					break;
				case Classifier.CLEAR_LIKE:
					itemFeed.setTextColor(getActivity().getResources().getColor(R.color.darkgray));
					break;
				}
				break;
			case Classifier.TAG:
				classifier.tags.put(key, classifierAction);
				tagAdapter.setClassifier(classifier);
				tagAdapter.notifyDataSetInvalidated();
				break;	
		}
	}


	@Override
	public void sharedCallback(String sharedText, boolean hasBeenShared) {
		
		if (!hasBeenShared) {
			LayoutInflater inflater = getActivity().getLayoutInflater();
			
			View commentView = inflater.inflate(R.layout.include_comment, null);
			commentView.setTag(SetupCommentSectionTask.COMMENT_VIEW_BY + user.id);
			
			TextView commentText = (TextView) commentView.findViewById(R.id.comment_text);
			commentText.setTag("commentBy" + user.id);
			commentText.setText(sharedText);
			
			ImageView commentImage = (ImageView) commentView.findViewById(R.id.comment_user_image);
			commentImage.setImageBitmap(UIUtils.roundCorners(PrefsUtil.getUserImage(getActivity()), 10f));
			
			TextView commentSharedDate = (TextView) commentView.findViewById(R.id.comment_shareddate);
			commentSharedDate.setText(R.string.now);
			
			TextView commentUsername = (TextView) commentView.findViewById(R.id.comment_username);
			commentUsername.setText(user.username);
			
			((LinearLayout) view.findViewById(R.id.reading_friend_comment_container)).addView(commentView);
			
			commentView.setBackgroundResource(R.drawable.transition_edit_background);
			
			final TransitionDrawable transition = (TransitionDrawable) commentView.getBackground();
			transition.startTransition(1000);
			
			new Handler().postDelayed(new Runnable() {
		        public void run() {
		            transition.reverseTransition(1000);
		        }
		    }, 1000);
			
		} else {
			View commentViewForUser = view.findViewWithTag(SetupCommentSectionTask.COMMENT_VIEW_BY + user.id);
			commentViewForUser.setBackgroundResource(R.drawable.transition_edit_background);
			
			final TransitionDrawable transition = (TransitionDrawable) commentViewForUser.getBackground();
			transition.startTransition(1000);
			
			new Handler().postDelayed(new Runnable() {
		        public void run() {
		            transition.reverseTransition(1000);
		        }
		    }, 1000);
			
			TextView commentText = (TextView) view.findViewWithTag(SetupCommentSectionTask.COMMENT_BY + user.id);
			commentText.setText(sharedText);
			
			TextView commentDateText = (TextView) view.findViewWithTag(SetupCommentSectionTask.COMMENT_DATE_BY + user.id);
			commentDateText.setText(R.string.now);
			
		}
	}


	@Override
	public void setPreviouslySavedShareText(String previouslySavedShareText) {
		this.previouslySavedShareText = previouslySavedShareText;
	}

}
