package com.newsblur.fragment;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.TransitionDrawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.ScaleDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.Fragment;
import android.text.Html;
import android.text.TextUtils;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.NewsBlurApplication;
import com.newsblur.activity.Reading;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.network.APIManager;
import com.newsblur.network.SetupCommentSectionTask;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.util.ViewUtils;
import com.newsblur.view.FlowLayout;
import com.newsblur.view.NewsblurWebview;
import com.newsblur.view.NonfocusScrollview;

public class ReadingItemFragment extends Fragment implements ClassifierDialogFragment.TagUpdateCallback, ShareDialogFragment.SharedCallbackDialog {

	public static final String TEXT_SIZE_CHANGED = "textSizeChanged";
	public static final String TEXT_SIZE_VALUE = "textSizeChangeValue";
	public Story story;
	private LayoutInflater inflater;
	private APIManager apiManager;
	private ImageLoader imageLoader;
	private String feedColor, feedTitle, feedFade, feedBorder, feedIconUrl, faviconText;
	private Classifier classifier;
	private ContentResolver resolver;
	private NewsblurWebview web;
	private BroadcastReceiver receiver;
	private TextView itemAuthors;
	private TextView itemFeed;
	private boolean displayFeedDetails;
	private FlowLayout tagContainer;
	private View view;
	private UserDetails user;
	public String previouslySavedShareText;
	private ImageView feedIcon;
    private Reading activity;
    private Boolean customContent = false;

	public static ReadingItemFragment newInstance(Story story, String feedTitle, String feedFaviconColor, String feedFaviconFade, String feedFaviconBorder, String faviconText, String faviconUrl, Classifier classifier, boolean displayFeedDetails) {
		ReadingItemFragment readingFragment = new ReadingItemFragment();

		Bundle args = new Bundle();
		args.putSerializable("story", story);
		args.putString("feedTitle", feedTitle);
		args.putString("feedColor", feedFaviconColor);
        args.putString("feedFade", feedFaviconFade);
        args.putString("feedBorder", feedFaviconBorder);
        args.putString("faviconText", faviconText);
		args.putString("faviconUrl", faviconUrl);
		args.putBoolean("displayFeedDetails", displayFeedDetails);
		args.putSerializable("classifier", classifier);
		readingFragment.setArguments(args);

		return readingFragment;
	}

    @Override
    public void onAttach(Activity activity) {
        if (activity instanceof Reading) {
            this.activity = (Reading) activity;
        }
        super.onAttach(activity);
    }

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		imageLoader = ((NewsBlurApplication) getActivity().getApplicationContext()).getImageLoader();
		apiManager = new APIManager(getActivity());
		story = getArguments() != null ? (Story) getArguments().getSerializable("story") : null;

		resolver = getActivity().getContentResolver();
		inflater = getActivity().getLayoutInflater();
		
		displayFeedDetails = getArguments().getBoolean("displayFeedDetails");
		
		user = PrefsUtils.getUserDetails(getActivity());

		feedIconUrl = getArguments().getString("faviconUrl");
		feedTitle = getArguments().getString("feedTitle");
		feedColor = getArguments().getString("feedColor");
        feedFade = getArguments().getString("feedFade");
        feedBorder = getArguments().getString("feedBorder");
        faviconText = getArguments().getString("faviconText");

		classifier = (Classifier) getArguments().getSerializable("classifier");

		receiver = new TextSizeReceiver();
		getActivity().registerReceiver(receiver, new IntentFilter(TEXT_SIZE_CHANGED));
	}
    @Override
    public void onSaveInstanceState(Bundle outState) {
        outState.putSerializable("story", story);
    }

	@Override
	public void onDestroy() {
		getActivity().unregisterReceiver(receiver);
		super.onDestroy();
	}

    // WebViews don't automatically pause content like audio and video when they lose focus.  Chain our own
    // state into the webview so it behaves.
    @Override
    public void onPause() {
        if (this.web != null ) { this.web.onPause(); }
        super.onPause();
    }

    @Override
    public void onResume() {
        if (this.web != null ) { this.web.onResume(); }
        super.onResume();
    }

	public View onCreateView(final LayoutInflater inflater, final ViewGroup container, final Bundle savedInstanceState) {

		view = inflater.inflate(R.layout.fragment_readingitem, null);

		web = (NewsblurWebview) view.findViewById(R.id.reading_webview);
		
        synchronized (customContent) {
            setupWebview(story.content);
            customContent = false;
        }

		setupItemMetadata();
		setupShareButton();
		setupSaveButton();

		if (story.sharedUserIds.length > 0 || story.commentCount > 0 ) {
			view.findViewById(R.id.reading_share_bar).setVisibility(View.VISIBLE);
			view.findViewById(R.id.share_bar_underline).setVisibility(View.VISIBLE);
			setupItemCommentsAndShares(view);
		}

        NonfocusScrollview scrollView = (NonfocusScrollview) view.findViewById(R.id.reading_scrollview);
        scrollView.registerScrollChangeListener(this.activity);

		return view;
	}
	
	private void setupSaveButton() {
		final Button saveButton = (Button) view.findViewById(R.id.save_story_button);
        saveButton.setText(story.starred ? R.string.unsave_this : R.string.save_this);

        saveButton.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
                if (story.starred) {
                    FeedUtils.unsaveStory(story, activity, apiManager, activity);
                } else {
				    FeedUtils.saveStory(story, activity, apiManager, activity);
                }
			}
		});
	}

    public void updateSaveButton() {
		Button saveButton = (Button) view.findViewById(R.id.save_story_button);
        saveButton.setText(story.starred ? R.string.unsave_this : R.string.save_this);
    }

    public void updateStory(Story story) {
        this.story = story;
    }
    
	private void setupShareButton() {
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

	private void setupItemMetadata() {

        View feedHeader = view.findViewById(R.id.row_item_feed_header);
        View feedHeaderBorder = view.findViewById(R.id.item_feed_border);
        TextView itemTitle = (TextView) view.findViewById(R.id.reading_item_title);
        TextView itemDate = (TextView) view.findViewById(R.id.reading_item_date);
        itemAuthors = (TextView) view.findViewById(R.id.reading_item_authors);
        itemFeed = (TextView) view.findViewById(R.id.reading_feed_title);
        feedIcon = (ImageView) view.findViewById(R.id.reading_feed_icon);

		if (TextUtils.equals(feedColor, "#null") || TextUtils.equals(feedFade, "#null")) {
            feedColor = "#303030";
            feedFade = "#505050";
            feedBorder = "#202020";
        }

        int[] colors = {
            Color.parseColor(feedColor),
            Color.parseColor(feedFade)
        };
        GradientDrawable gradient = new GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP,
                colors);
        feedHeader.setBackgroundDrawable(gradient);
        feedHeaderBorder.setBackgroundColor(Color.parseColor(feedBorder));

        if (TextUtils.equals(faviconText, "black")) {
            itemFeed.setTextColor(getActivity().getResources().getColor(R.color.darkgray));
            itemFeed.setShadowLayer(1, 0, 1, getActivity().getResources().getColor(R.color.half_white));
        } else {
            itemFeed.setTextColor(getActivity().getResources().getColor(R.color.white));
            itemFeed.setShadowLayer(1, 0, 1, getActivity().getResources().getColor(R.color.half_black));
        }

		if (!displayFeedDetails) {
			itemFeed.setVisibility(View.GONE);
			feedIcon.setVisibility(View.GONE);
		} else {
			imageLoader.displayImage(feedIconUrl, feedIcon, false);
			itemFeed.setText(feedTitle);
		}

        itemTitle.setText(Html.fromHtml(story.title));
		itemDate.setText(story.longDate);

        if (!TextUtils.isEmpty(story.authors)) {
            itemAuthors.setText("•   " + story.authors);
            if (classifier != null && classifier.authors.containsKey(story.authors)) {
                updateTagView(story.authors, Classifier.AUTHOR, classifier.authors.get(story.authors));
            }
        }

        if (story.tags.length <= 0) {
            tagContainer = (FlowLayout) view.findViewById(R.id.reading_item_tags);
            tagContainer.setVisibility(View.GONE);
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

		itemTitle.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				Intent i = new Intent(Intent.ACTION_VIEW);
				i.setData(Uri.parse(story.permalink));
				startActivity(i);
			}
		});

		setupTags();
	}

	private void setupTags() {
		tagContainer = (FlowLayout) view.findViewById(R.id.reading_item_tags);
        ViewUtils.setupTags(getActivity());
		for (String tag : story.tags) {
			View v = ViewUtils.createTagView(inflater, getFragmentManager(), tag, classifier, this, story.feedId);
			tagContainer.addView(v);
		}
		
	}

    /**
     * Set the webview to show the default story content.
     */
    public void setDefaultWebview() {
        // if the default content hasn't been changed, don't reset it
        synchronized (customContent) {
            if (!customContent) return;
            setupWebview(story.content);
            customContent = false;
        }
    }

    /**
     * Set the webview to show non-default content, tracking the change.
     */
    public void setCustomWebview(String content) {
        synchronized (customContent) {
            setupWebview(content);
            customContent = true;
        }
    }

	private void setupWebview(String storyText) {
        if (getActivity() == null) {
            // this method gets called by async UI bits that might hold stale fragment references with no assigned
            // activity.  If this happens, just abort the call.
            return;
        }
		final SharedPreferences preferences = getActivity().getSharedPreferences(PrefConstants.PREFERENCES, 0);
		float currentSize = preferences.getFloat(PrefConstants.PREFERENCE_TEXT_SIZE, 0.5f);

		StringBuilder builder = new StringBuilder();
		builder.append("<html><head><meta name=\"viewport\" content=\"width=device-width; initial-scale=1; maximum-scale=1; minimum-scale=1; user-scalable=0; target-densityDpi=medium-dpi\" />");
		builder.append("<style style=\"text/css\">");
		builder.append(String.format("body { font-size: %s em; } ", Float.toString(currentSize + AppConstants.FONT_SIZE_LOWER_BOUND)));
		builder.append("</style>");
		builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"reading.css\" /></head><body><div class=\"NB-story\">");
		builder.append(storyText);
		builder.append("</div></body></html>");
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
				itemAuthors.setTextColor(getActivity().getResources().getColor(R.color.half_darkgray));
				break;
			case Classifier.CLEAR_LIKE:
				itemAuthors.setTextColor(getActivity().getResources().getColor(R.color.half_darkgray));
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
			tagContainer.removeAllViews();
			setupTags();
			break;	
		}
	}

	@Override
	public void sharedCallback(String sharedText, boolean hasAlreadyBeenShared) {
		view.findViewById(R.id.reading_share_bar).setVisibility(View.VISIBLE);
		view.findViewById(R.id.share_bar_underline).setVisibility(View.VISIBLE);
		
		if (!hasAlreadyBeenShared) {
			
			if (!TextUtils.isEmpty(sharedText)) {
				View commentView = inflater.inflate(R.layout.include_comment, null);
				commentView.setTag(SetupCommentSectionTask.COMMENT_VIEW_BY + user.id);

                TextView commentText = (TextView) commentView.findViewById(R.id.comment_text);
                commentText.setTag("commentBy" + user.id);
                commentText.setText(sharedText);

                TextView commentLocation = (TextView) commentView.findViewById(R.id.comment_location);
                if (!TextUtils.isEmpty(user.location)) {
                    commentLocation.setText(user.location.toUpperCase());
                } else {
                    commentLocation.setVisibility(View.GONE);
                }

                if (PrefsUtils.getUserImage(getActivity()) != null) {
					ImageView commentImage = (ImageView) commentView.findViewById(R.id.comment_user_image);
					commentImage.setImageBitmap(UIUtils.roundCorners(PrefsUtils.getUserImage(getActivity()), 10f));
				}

				TextView commentSharedDate = (TextView) commentView.findViewById(R.id.comment_shareddate);
				commentSharedDate.setText(R.string.now);

				TextView commentUsername = (TextView) commentView.findViewById(R.id.comment_username);
				commentUsername.setText(user.username);

				((LinearLayout) view.findViewById(R.id.reading_friend_comment_container)).addView(commentView);

				ViewUtils.setupCommentCount(getActivity(), view, story.commentCount + 1);
				
				final ImageView image = ViewUtils.createSharebarImage(getActivity(), imageLoader, user.photoUrl, user.id);
				((FlowLayout) view.findViewById(R.id.reading_social_commentimages)).addView(image);
				
			} else {
				ViewUtils.setupShareCount(getActivity(), view, story.sharedUserIds.length + 1);
				final ImageView image = ViewUtils.createSharebarImage(getActivity(), imageLoader, user.photoUrl, user.id);
				((FlowLayout) view.findViewById(R.id.reading_social_shareimages)).addView(image);
			}
		} else {
			View commentViewForUser = view.findViewWithTag(SetupCommentSectionTask.COMMENT_VIEW_BY + user.id);
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
