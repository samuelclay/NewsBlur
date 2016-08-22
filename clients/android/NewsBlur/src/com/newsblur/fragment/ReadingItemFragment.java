package com.newsblur.fragment;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.app.DialogFragment;
import android.text.Html;
import android.text.TextUtils;
import android.util.Log;
import android.view.ContextMenu;
import android.view.GestureDetector;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.webkit.WebView.HitTestResult;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;

import butterknife.ButterKnife;
import butterknife.Bind;
import butterknife.OnClick;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.activity.Reading;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.FileCache;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.util.ViewUtils;
import com.newsblur.view.FlowLayout;
import com.newsblur.view.NewsblurWebview;
import com.newsblur.view.ReadingScrollView;

import java.util.Date;
import java.util.HashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class ReadingItemFragment extends NbFragment implements ClassifierDialogFragment.TagUpdateCallback {

	public static final String TEXT_SIZE_CHANGED = "textSizeChanged";
	public static final String TEXT_SIZE_VALUE = "textSizeChangeValue";
	public Story story;
	private LayoutInflater inflater;
	private String feedColor, feedTitle, feedFade, feedBorder, feedIconUrl, faviconText;
	private Classifier classifier;
	@Bind(R.id.reading_webview) NewsblurWebview web;
    @Bind(R.id.custom_view_container) ViewGroup webviewCustomViewLayout;
    @Bind(R.id.reading_scrollview) View fragmentScrollview;
	private BroadcastReceiver receiver;
    @Bind(R.id.reading_item_authors) TextView itemAuthors;
	@Bind(R.id.reading_feed_title) TextView itemFeed;
	private boolean displayFeedDetails;
	@Bind(R.id.reading_item_tags) FlowLayout tagContainer;
	private View view;
	private UserDetails user;
    private DefaultFeedView selectedFeedView;
    @Bind(R.id.save_story_button) Button saveButton;
    @Bind(R.id.share_story_button) Button shareButton;

    /** The story HTML, as provided by the 'content' element of the stories API. */
    private String storyContent;
    /** The text-mode story HTML, as retrived via the secondary original text API. */
    private String originalText;

    private HashMap<String,String> imageAltTexts;
    private HashMap<String,String> imageUrlRemaps;
    private String sourceUserId;
    private int contentHash;

    // these three flags are progressively set by async callbacks and unioned
    // to set isLoadFinished, when we trigger any final UI tricks.
    private boolean isContentLoadFinished;
    private boolean isWebLoadFinished;
    private boolean isSocialLoadFinished;
    private Boolean isLoadFinished = false;

    private final Object WEBVIEW_CONTENT_MUTEX = new Object();

	public static ReadingItemFragment newInstance(Story story, String feedTitle, String feedFaviconColor, String feedFaviconFade, String feedFaviconBorder, String faviconText, String faviconUrl, Classifier classifier, boolean displayFeedDetails, DefaultFeedView defaultFeedView, String sourceUserId) {
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
        args.putSerializable("defaultFeedView", defaultFeedView);
        args.putString("sourceUserId", sourceUserId);
		readingFragment.setArguments(args);

		return readingFragment;
	}

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		story = getArguments() != null ? (Story) getArguments().getSerializable("story") : null;

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

        selectedFeedView = (DefaultFeedView)getArguments().getSerializable("defaultFeedView");

        sourceUserId = getArguments().getString("sourceUserId");

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
        web.setOnTouchListener(null);
        view.setOnTouchListener(null);
        getActivity().getWindow().getDecorView().setOnSystemUiVisibilityChangeListener(null);
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
        super.onResume();
        reloadStoryContent();
        if (this.web != null ) { this.web.onResume(); }
    }

	public View onCreateView(final LayoutInflater inflater, final ViewGroup container, final Bundle savedInstanceState) {
        view = inflater.inflate(R.layout.fragment_readingitem, null);
        ButterKnife.bind(this, view);

        Reading activity = (Reading) getActivity();

        registerForContextMenu(web);
        web.setCustomViewLayout(webviewCustomViewLayout);
        web.setWebviewWrapperLayout(fragmentScrollview);
        web.fragment = this;
        web.activity = activity;

		setupItemMetadata();
		updateShareButton();
	    updateSaveButton();
        setupItemCommentsAndShares();

        ReadingScrollView scrollView = (ReadingScrollView) view.findViewById(R.id.reading_scrollview);
        scrollView.registerScrollChangeListener(activity);

        setupImmersiveViewGestureDetector();

		return view;
	}

    private void setupImmersiveViewGestureDetector() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            // Change the system visibility on the decorview from the activity so that the state is maintained as we page through
            // fragments
            ImmersiveViewHandler immersiveViewHandler = new ImmersiveViewHandler(getActivity().getWindow().getDecorView());
            final GestureDetector gestureDetector = new GestureDetector(getActivity(), immersiveViewHandler);
            View.OnTouchListener touchListener = new View.OnTouchListener() {
                @Override
                public boolean onTouch(View view, MotionEvent motionEvent) {
                    return gestureDetector.onTouchEvent(motionEvent);
                }
            };
            web.setOnTouchListener(touchListener);
            view.setOnTouchListener(touchListener);

            getActivity().getWindow().getDecorView().setOnSystemUiVisibilityChangeListener(immersiveViewHandler);
        }
    }

    @Override
    public void onCreateContextMenu(ContextMenu menu, View v, ContextMenu.ContextMenuInfo menuInfo) {
        HitTestResult result = web.getHitTestResult();
        if (result.getType() == HitTestResult.IMAGE_TYPE ||
            result.getType() == HitTestResult.SRC_ANCHOR_TYPE ||
            result.getType() == HitTestResult.SRC_IMAGE_ANCHOR_TYPE ) {
            // if the long-pressed item was an image, see if we can pop up a little dialogue
            // that presents the alt text.  Note that images wrapped in links tend to get detected
            // as anchors, not images, and may not point to the corresponding image URL.
            String imageURL = result.getExtra();
            imageURL = imageURL.replace("file://", "");
            String mappedURL = imageUrlRemaps.get(imageURL);
            final String finalURL = mappedURL == null ? imageURL : mappedURL;
            final String altText = imageAltTexts.get(finalURL);
            if (altText != null) {
                AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
                builder.setTitle(finalURL);
                builder.setMessage(Html.fromHtml(altText).toString());
                builder.setPositiveButton(R.string.alert_dialog_openimage, new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int id) {
                        Intent i = new Intent(Intent.ACTION_VIEW);
                        i.setData(Uri.parse(finalURL));
                        try {
                            startActivity(i);
                        } catch (Exception e) {
                            android.util.Log.wtf(this.getClass().getName(), "device cannot open URLs");
                        }
                    }
                });
                builder.setNegativeButton(R.string.alert_dialog_done, new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int id) {
                        ; // do nothing
                    }
                });
                builder.show();
            }
        } else {
            super.onCreateContextMenu(menu, v, menuInfo);
        }
    }

    @OnClick(R.id.save_story_button) void clickSave() {
        if (story.starred) {
            FeedUtils.setStorySaved(story, false, getActivity());
        } else {
            FeedUtils.setStorySaved(story,true, getActivity());
        }
    }

    private void updateSaveButton() {
        if (saveButton == null) return;
        saveButton.setText(story.starred ? R.string.unsave_this : R.string.save_this);
    }

    @OnClick(R.id.share_story_button) void clickShare() {
        DialogFragment newFragment = ShareDialogFragment.newInstance(story, sourceUserId);
        newFragment.show(getFragmentManager(), "dialog");
    }

	private void updateShareButton() {
        if (shareButton == null) return;
		for (String userId : story.sharedUserIds) {
			if (TextUtils.equals(userId, user.id)) {
				shareButton.setText(R.string.already_shared);
				return;
			}
		}
        shareButton.setText(R.string.share_this);
	}

    private void setupItemCommentsAndShares() {
        new SetupCommentSectionTask(this, view, inflater, story).execute();
    }

	private void setupItemMetadata() {
        View feedHeader = view.findViewById(R.id.row_item_feed_header);
        View feedHeaderBorder = view.findViewById(R.id.item_feed_border);
        TextView itemTitle = (TextView) view.findViewById(R.id.reading_item_title);
        TextView itemDate = (TextView) view.findViewById(R.id.reading_item_date);
        ImageView feedIcon = (ImageView) view.findViewById(R.id.reading_feed_icon);

		if (TextUtils.equals(feedColor, "#null") || TextUtils.equals(feedFade, "#null")) {
            feedColor = "#303030";
            feedFade = "#505050";
            feedBorder = "#202020";
        }

        int[] colors = {
            Color.parseColor(feedColor),
            Color.parseColor(feedFade),
        };
        GradientDrawable gradient = new GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, colors);
        UIUtils.setViewBackground(feedHeader, gradient);
        feedHeaderBorder.setBackgroundColor(Color.parseColor(feedBorder));

        if (TextUtils.equals(faviconText, "black")) {
            itemFeed.setTextColor(UIUtils.getColor(getActivity(), R.color.text));
            itemFeed.setShadowLayer(1, 0, 1, UIUtils.getColor(getActivity(), R.color.half_white));
        } else {
            itemFeed.setTextColor(UIUtils.getColor(getActivity(), R.color.white));
            itemFeed.setShadowLayer(1, 0, 1, UIUtils.getColor(getActivity(), R.color.half_black));
        }

		if (!displayFeedDetails) {
			itemFeed.setVisibility(View.GONE);
			feedIcon.setVisibility(View.GONE);
		} else {
			FeedUtils.iconLoader.displayImage(feedIconUrl, feedIcon, 0, false);
			itemFeed.setText(feedTitle);
		}

        itemTitle.setText(Html.fromHtml(story.title));
        itemDate.setText(StoryUtils.formatLongDate(getActivity(), new Date(story.timestamp)));

        if (!TextUtils.isEmpty(story.authors)) {
            itemAuthors.setText("•   " + story.authors);
            if (classifier != null && classifier.authors.containsKey(story.authors)) {
                updateTagView(story.authors, Classifier.AUTHOR, classifier.authors.get(story.authors));
            }
        }

        if (story.tags.length <= 0) {
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
                try {
                    i.setData(Uri.parse(story.permalink));
                    startActivity(i);
                } catch (Throwable t) {
                    // we don't actually know if the user will successfully be able to open whatever string
                    // was in the permalink or if the Intent could throw errors
                    Log.e(this.getClass().getName(), "Error opening story by permalink URL.", t);
                }
			}
		});

		setupTags();
	}

	private void setupTags() {
        int tag_green_text = UIUtils.getColor(getActivity(), R.color.tag_green_text);
        int tag_red_text = UIUtils.getColor(getActivity(), R.color.tag_red_text);
        Drawable tag_green_background = UIUtils.getDrawable(getActivity(), R.drawable.tag_background_positive);
        Drawable tag_red_background = UIUtils.getDrawable(getActivity(), R.drawable.tag_background_negative);
		for (final String tag : story.tags) {
            View v = inflater.inflate(R.layout.tag_view, null);

            TextView tagText = (TextView) v.findViewById(R.id.tag_text);
            tagText.setText(tag);

            if (classifier != null && classifier.tags.containsKey(tag)) {
                switch (classifier.tags.get(tag)) {
                case Classifier.LIKE:
                    UIUtils.setViewBackground(tagText, tag_green_background);
                    tagText.setTextColor(tag_green_text);
                    break;
                case Classifier.DISLIKE:
                    UIUtils.setViewBackground(tagText, tag_red_background);
                    tagText.setTextColor(tag_red_text);
                    break;
                }
            }

            v.setOnClickListener(new OnClickListener() {
                @Override
                public void onClick(View view) {
                    ClassifierDialogFragment classifierFragment = ClassifierDialogFragment.newInstance(ReadingItemFragment.this, story.feedId, classifier, tag, Classifier.TAG);
                    classifierFragment.show(getFragmentManager(), "dialog");
                }
            });

			tagContainer.addView(v);
		}
	}

    public void switchSelectedFeedView() {
        synchronized (selectedFeedView) {
            // if we were already in text mode, switch back to story mode
            if (selectedFeedView == DefaultFeedView.TEXT) {
                selectedFeedView = DefaultFeedView.STORY;
            } else {
                selectedFeedView = DefaultFeedView.TEXT;
            }
            reloadStoryContent();
        }
    }

    public DefaultFeedView getSelectedFeedView() {
        return selectedFeedView;
    }

    private void reloadStoryContent() {
        if (selectedFeedView == DefaultFeedView.STORY) {
            enableProgress(false);
            if (storyContent == null) {
                loadStoryContent();
            } else {
                setupWebview(storyContent);
                onContentLoadFinished();
            }
        } else {
            if (originalText == null) {
                enableProgress(true);
                loadOriginalText();
            } else {
                setupWebview(originalText);
                onContentLoadFinished();
                enableProgress(false);
            }
        }
    }

    private void enableProgress(boolean loading) {
        Activity parent = getActivity();
        if (parent == null) return;
        ((Reading) parent).enableLeftProgressCircle(loading);
    }

    /** 
     * Lets the pager offer us an updated version of our story when a new cursor is
     * cycled in. This class takes the responsibility of ensureing that the cursor
     * index has not shifted, though, by checking story IDs.
     */
    public void offerStoryUpdate(Story story) {
        if (story == null) return;
        if (! TextUtils.equals(story.storyHash, this.story.storyHash)) return;
        this.story = story;
    }

    public void handleUpdate(int updateType) {
        if ((updateType & NbActivity.UPDATE_STORY) != 0) {
            updateSaveButton();
            updateShareButton();
        }
        if ((updateType & NbActivity.UPDATE_TEXT) != 0) {
            reloadStoryContent();
        }
        if ((updateType & NbActivity.UPDATE_SOCIAL) != 0) {
            setupItemCommentsAndShares();
        }
    }

    private void loadOriginalText() {
        if (story != null) {
            new AsyncTask<Void, Void, String>() {
                @Override
                protected String doInBackground(Void... arg) {
                    return FeedUtils.getStoryText(story.storyHash);
                }
                @Override
                protected void onPostExecute(String result) {
                    if (result != null) {
                        ReadingItemFragment.this.originalText = result;
                        reloadStoryContent();
                    } else {
                        if (getActivity() != null) setupWebview(getActivity().getResources().getString(R.string.orig_text_loading));
                        NBSyncService.getOriginalText(story.storyHash);
                        triggerSync();
                    }
                }
            }.execute();
        }
    }

    private void loadStoryContent() {
        if (story == null) return;
        new AsyncTask<Void, Void, String>() {
            @Override
            protected String doInBackground(Void... arg) {
                return FeedUtils.getStoryContent(story.storyHash);
            }
            @Override
            protected void onPostExecute(String result) {
                if (result != null) {
                    ReadingItemFragment.this.storyContent = result;
                    reloadStoryContent();
                } else {
                    Log.w(this.getClass().getName(), "couldn't find story content for existing story.");
                    Activity act = getActivity();
                    if (act != null) act.finish();
                }
            }
        }.execute();
    }

	private void setupWebview(String storyText) {
        if (getActivity() == null) {
            // this method gets called by async UI bits that might hold stale fragment references with no assigned
            // activity.  If this happens, just abort the call.
            return;
        }

        synchronized (WEBVIEW_CONTENT_MUTEX) {
            // this method might get called repeatedly despite no content change, which is expensive
            int contentHash = storyText.hashCode();
            if (this.contentHash == contentHash) return;
            this.contentHash = contentHash;
            
            sniffAltTexts(storyText);

            storyText = swapInOfflineImages(storyText);

            float currentSize = PrefsUtils.getTextSize(getActivity());

            StringBuilder builder = new StringBuilder();
            builder.append("<html><head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1, maximum-scale=1, minimum-scale=1, user-scalable=0\" />");
            builder.append("<style style=\"text/css\">");
            builder.append(String.format("body { font-size: %sem; } ", Float.toString(currentSize)));
            builder.append("</style>");
            builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"reading.css\" />");
            if (PrefsUtils.isLightThemeSelected(getActivity())) {
                builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"light_reading.css\" />");
            } else {
                builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"dark_reading.css\" />");
            }
            builder.append("</head><body><div class=\"NB-story\">");
            builder.append(storyText);
            builder.append("</div></body></html>");
            web.loadDataWithBaseURL("file:///android_asset/", builder.toString(), "text/html", "UTF-8", null);
        }
	}

    private static final Pattern altSniff1 = Pattern.compile("<img[^>]*src=(['\"])((?:(?!\\1).)*)\\1[^>]*alt=(['\"])((?:(?!\\3).)*)\\3[^>]*>", Pattern.CASE_INSENSITIVE);
    private static final Pattern altSniff2 = Pattern.compile("<img[^>]*alt=(['\"])((?:(?!\\1).)*)\\1[^>]*src=(['\"])((?:(?!\\3).)*)\\3[^>]*>", Pattern.CASE_INSENSITIVE);
    private static final Pattern altSniff3 = Pattern.compile("<img[^>]*src=(['\"])((?:(?!\\1).)*)\\1[^>]*title=(['\"])((?:(?!\\3).)*)\\3[^>]*>", Pattern.CASE_INSENSITIVE);
    private static final Pattern altSniff4 = Pattern.compile("<img[^>]*title=(['\"])((?:(?!\\1).)*)\\1[^>]*src=(['\"])((?:(?!\\3).)*)\\3[^>]*>", Pattern.CASE_INSENSITIVE);

    private void sniffAltTexts(String html) {
        // Find images with alt tags and cache the text for use on long-press
        //   NOTE: if doing this via regex has a smell, you have a good nose!  This method is far from perfect
        //   and may miss valid cases or trucate tags, but it works for popular feeds (read: XKCD) and doesn't
        //   require us to import a proper parser lib of hundreds of kilobytes just for this one feature.
        imageAltTexts = new HashMap<String,String>();
        // sniff for alts first
        Matcher imgTagMatcher = altSniff1.matcher(html);
        while (imgTagMatcher.find()) {
            imageAltTexts.put(imgTagMatcher.group(2), imgTagMatcher.group(4));
        }
        imgTagMatcher = altSniff2.matcher(html);
        while (imgTagMatcher.find()) {
            imageAltTexts.put(imgTagMatcher.group(4), imgTagMatcher.group(2));
        }
        // then sniff for 'title' tags, so they will overwrite alts and take precedence
        imgTagMatcher = altSniff3.matcher(html);
        while (imgTagMatcher.find()) {
            imageAltTexts.put(imgTagMatcher.group(2), imgTagMatcher.group(4));
        }
        imgTagMatcher = altSniff4.matcher(html);
        while (imgTagMatcher.find()) {
            imageAltTexts.put(imgTagMatcher.group(4), imgTagMatcher.group(2));
        }

        // while were are at it, create a place where we can later cache offline image remaps so that when
        // we do an alt-text lookup, we can search for the right URL key.
        imageUrlRemaps = new HashMap<String,String>();
    }

    private String swapInOfflineImages(String html) {
        Matcher imageTagMatcher = Pattern.compile("<img[^>]*(src\\s*=\\s*)\"([^\"]*)\"[^>]*>", Pattern.CASE_INSENSITIVE).matcher(html);
        while (imageTagMatcher.find()) {
            String url = imageTagMatcher.group(2);
            String localPath = FeedUtils.storyImageCache.getCachedLocation(url);
            if (localPath == null) continue;
            html = html.replace(imageTagMatcher.group(1)+"\""+url+"\"", "src=\""+localPath+"\"");
            imageUrlRemaps.put(localPath, url);
        }

        return html;
    }

    /** We have pushed our desired content into the WebView. */
    private void onContentLoadFinished() {
        isContentLoadFinished = true;
        checkLoadStatus();
    }

    /** The webview has finished loading our desired content. */
    public void onWebLoadFinished() {
        isWebLoadFinished = true;
        checkLoadStatus();
    }

    /** The social UI has finished loading from the DB. */
    public void onSocialLoadFinished() {
        isSocialLoadFinished = true;
        checkLoadStatus();
    }

    private void checkLoadStatus() {
        synchronized (isLoadFinished) {
            if (isContentLoadFinished && isWebLoadFinished && isSocialLoadFinished) {
                // iff this is the first time all content has finished loading, trigger any UI
                // behaviour that is position-dependent
                if (!isLoadFinished) {
                    onLoadFinished();
                }
                isLoadFinished = true;
            }
        }
    }

    private void onLoadFinished() {
        // TODO: perform any position-dependent UI behaviours here (@manderson23)
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
				itemAuthors.setTextColor(UIUtils.getColor(getActivity(), R.color.positive));
				break;
			case Classifier.DISLIKE:
				itemAuthors.setTextColor(UIUtils.getColor(getActivity(), R.color.negative));
				break;
			case Classifier.CLEAR_DISLIKE:
				itemAuthors.setTextColor(UIUtils.getColor(getActivity(), R.color.half_darkgray));
				break;
			case Classifier.CLEAR_LIKE:
				itemAuthors.setTextColor(UIUtils.getColor(getActivity(), R.color.half_darkgray));
				break;	
			}
			break;
		case Classifier.FEED:
			switch (classifierAction) {
			case Classifier.LIKE:
				itemFeed.setTextColor(UIUtils.getColor(getActivity(), R.color.positive));
				break;
			case Classifier.DISLIKE:
				itemFeed.setTextColor(UIUtils.getColor(getActivity(), R.color.negative));
				break;
			case Classifier.CLEAR_DISLIKE:
				itemFeed.setTextColor(UIUtils.getColor(getActivity(), R.color.text));
				break;
			case Classifier.CLEAR_LIKE:
				itemFeed.setTextColor(UIUtils.getColor(getActivity(), R.color.text));
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
    private class ImmersiveViewHandler extends GestureDetector.SimpleOnGestureListener implements View.OnSystemUiVisibilityChangeListener {
        private View view;

        public ImmersiveViewHandler(View view) {
            this.view = view;
        }

        @Override
        public boolean onSingleTapUp(MotionEvent e) {
            if (web.wasLinkClicked()) {
                // Clicked a link so ignore immersive view
                return super.onSingleTapUp(e);
            }

            if (ViewUtils.isSystemUIHidden(view)) {
                ViewUtils.showSystemUI(view);
            } else if (PrefsUtils.enterImmersiveReadingModeOnSingleTap(getActivity())) {
                ViewUtils.hideSystemUI(view);
            }

            return super.onSingleTapUp(e);
        }

        @Override
        public void onSystemUiVisibilityChange(int i) {
            // If immersive view has been exited via a system gesture we want to ensure that it gets resized
            // in the same way as using tap to exit.
            if (ViewUtils.immersiveViewExitedViaSystemGesture(view)) {
                ViewUtils.showSystemUI(view);
            }
        }
    }
}
