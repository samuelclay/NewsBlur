package com.newsblur.view;

import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.text.Spannable;
import android.text.SpannableStringBuilder;
import android.text.TextUtils;
import android.text.method.LinkMovementMethod;
import android.text.style.ClickableSpan;
import android.text.style.ForegroundColorSpan;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.NewsBlurApplication;
import com.newsblur.activity.Profile;
import com.newsblur.domain.UserDetails;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.network.APIConstants;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefsUtils;

public class ActivitiesAdapter extends ArrayAdapter<ActivityDetails> {

	private LayoutInflater inflater;
	private ImageLoader imageLoader;
	private final String startedFollowing, ago, repliedTo, sharedStory, withComment, likedComment, subscribedTo, saved, signup;
	private ForegroundColorSpan highlight, darkgray;
	private String TAG = "ActivitiesAdapter";
	private Context context;
	private UserDetails currentUserDetails;
	
	public ActivitiesAdapter(final Context context, final ActivityDetails[] activities, UserDetails user) {
		super(context, R.id.row_activity_text);
		inflater = LayoutInflater.from(context);
		imageLoader = ((NewsBlurApplication) context.getApplicationContext()).getImageLoader();
		this.context = context;
		
		for (ActivityDetails response : activities) {
			add(response);
		}
		
		currentUserDetails = user;
		
		Resources resources = context.getResources();
		startedFollowing = resources.getString(R.string.profile_started_following);
		repliedTo = resources.getString(R.string.profile_replied_to);
		likedComment = resources.getString(R.string.profile_liked_comment);
		sharedStory = resources.getString(R.string.profile_shared_story);
		withComment = resources.getString(R.string.profile_with_comment);
		subscribedTo = resources.getString(R.string.profile_subscribed_to);
		saved = resources.getString(R.string.profile_saved);
		signup = resources.getString(R.string.profile_signup);
		ago = resources.getString(R.string.profile_ago);

		// TODO rename variables
        if (PrefsUtils.isLightThemeSelected(context)) {
            highlight = new ForegroundColorSpan(resources.getColor(R.color.linkblue));
            darkgray = new ForegroundColorSpan(resources.getColor(R.color.darkgray));
        } else {
            highlight = new ForegroundColorSpan(resources.getColor(R.color.dark_linkblue));
            darkgray = new ForegroundColorSpan(resources.getColor(R.color.white));
        }
	}
	
	@Override
	public View getView(int position, View convertView, ViewGroup parent) {
		View view = null;
		if (convertView == null) {
			view = inflater.inflate(R.layout.row_activity, null);
		} else {
			view = convertView;
		}
		final ActivityDetails activity = getItem(position);
		SpannableStringBuilder stringBuilder = new SpannableStringBuilder();

		// TODO handle different links
		ClickableSpan usernameClick = new ClickableSpan() {
			@Override
			public void onClick(View widget) {
				Intent i = new Intent(context, Profile.class);
				i.putExtra(Profile.USER_ID, activity.id);
				context.startActivity(i);
			}
		};
		
		TextView activityText = (TextView) view.findViewById(R.id.row_activity_text);
		TextView activityTime = (TextView) view.findViewById(R.id.row_activity_time);
		ImageView imageView = (ImageView) view.findViewById(R.id.row_activity_icon);
		
		activityTime.setText(activity.timeSince.toUpperCase() + " " + ago);
		// TODO images for each category type
		if (TextUtils.equals(activity.category, "feedsub")) {
			imageLoader.displayImage(APIConstants.S3_URL_FEED_ICONS + activity.feedId + ".png", imageView);
		} else if (activity.user != null) {
			imageLoader.displayImage(activity.user.photoUrl, imageView);
		} else if (TextUtils.equals(activity.category, "sharedstory")) {
			imageLoader.displayImage(currentUserDetails.photoUrl, imageView, 10f);
		} else {
			imageView.setImageResource(R.drawable.logo);
		}

		if (TextUtils.equals(activity.category, "feedsub")) {
			addFeedSubscriptionContent(activity, stringBuilder, usernameClick);
		} else if (TextUtils.equals(activity.category, "star")) {
			addStarContent(activity, stringBuilder, usernameClick);
		} else if (TextUtils.equals(activity.category, "signup")) {
			addSignupContent(activity, stringBuilder, usernameClick);
		} else if (TextUtils.equals(activity.category, "follow")) {
            addFollowContent(activity, stringBuilder, usernameClick);
		} else if (TextUtils.equals(activity.category, "comment_like")) {
			addCommentLikeContent(activity, stringBuilder, usernameClick);
		} else if (TextUtils.equals(activity.category, "comment_reply")) {
			addCommentReplyContent(activity, stringBuilder, usernameClick);
		} else if (TextUtils.equals(activity.category, "sharedstory")) {
			addSharedStoryContent(activity, stringBuilder, usernameClick);
		}
		
		activityText.setText(stringBuilder);
		activityText.setMovementMethod(LinkMovementMethod.getInstance());
		
		return view;
	}

	private void addFeedSubscriptionContent(ActivityDetails activity, SpannableStringBuilder stringBuilder, ClickableSpan usernameClick) {
		stringBuilder.append(subscribedTo);
		stringBuilder.append(" ");
		stringBuilder.append(activity.content);
		stringBuilder.setSpan(darkgray, 0, subscribedTo.length() + activity.content.length() + 1, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
	}

	private void addStarContent(ActivityDetails activity, SpannableStringBuilder stringBuilder, ClickableSpan usernameClick) {
		stringBuilder.append(saved);
		stringBuilder.append(" ");
		stringBuilder.append(activity.content);
		stringBuilder.setSpan(darkgray, 0, saved.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(usernameClick, saved.length() + 1, saved.length() + 1 + activity.content.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(highlight, saved.length() + 1, saved.length() + 1 + activity.content.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
	}

	private void addSignupContent(ActivityDetails activity, SpannableStringBuilder stringBuilder, ClickableSpan usernameClick) {
		stringBuilder.append(activity.user.username);
		stringBuilder.append(" ");
		stringBuilder.append(signup);
		stringBuilder.setSpan(darkgray, 0, activity.user.username.length() + signup.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
	}

	private void addFollowContent(ActivityDetails activity, SpannableStringBuilder stringBuilder, ClickableSpan usernameClick) {
		stringBuilder.append(startedFollowing);
		stringBuilder.append(" ");
		stringBuilder.append(activity.user.username);
		stringBuilder.setSpan(darkgray, 0, startedFollowing.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(usernameClick, startedFollowing.length() + 1, startedFollowing.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(highlight, startedFollowing.length() + 1, startedFollowing.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
	}

	private void addCommentLikeContent(ActivityDetails activity, SpannableStringBuilder stringBuilder, ClickableSpan usernameClick) {
		stringBuilder.append(likedComment);
		stringBuilder.append(" \"");
		stringBuilder.append(activity.content);
		stringBuilder.append("\" ");
		stringBuilder.append("by ");
		stringBuilder.append(activity.user.username);
		stringBuilder.setSpan(darkgray, 0, likedComment.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(highlight, likedComment.length() + 1, likedComment.length() + 3 + activity.content.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(darkgray, stringBuilder.length() - activity.user.username.length() - 4, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(usernameClick, likedComment.length() + 3 + activity.content.length() + 4, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
	}

	private void addCommentReplyContent(ActivityDetails activity, SpannableStringBuilder stringBuilder, ClickableSpan usernameClick) {
		stringBuilder.append(repliedTo);
		stringBuilder.append(" ");
		stringBuilder.append(activity.user.username);
		stringBuilder.append(": \"");
		stringBuilder.append(activity.content);
		stringBuilder.append("\"");
		stringBuilder.setSpan(darkgray, 0, repliedTo.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(usernameClick, repliedTo.length() + 1, repliedTo.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(highlight, repliedTo.length() + 1, repliedTo.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(darkgray, stringBuilder.length() - activity.content.length() - 2, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
	}

	private void addSharedStoryContent(ActivityDetails activity, SpannableStringBuilder stringBuilder, ClickableSpan usernameClick) {
		stringBuilder.append(sharedStory);
		stringBuilder.append(" ");
		stringBuilder.append(activity.title);
		stringBuilder.append(" ");
		if (!TextUtils.isEmpty(activity.content)) {
			stringBuilder.append(withComment);
			stringBuilder.append(": \"");
			stringBuilder.append(activity.content);
			stringBuilder.append("\"");
		}
		stringBuilder.setSpan(darkgray, 0, sharedStory.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(highlight, sharedStory.length() + 1, sharedStory.length() + 1 + activity.title.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		if (!TextUtils.isEmpty(activity.content)) {
			stringBuilder.setSpan(darkgray, sharedStory.length() + 4 + activity.title.length() + withComment.length(), stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		}
	}
}
