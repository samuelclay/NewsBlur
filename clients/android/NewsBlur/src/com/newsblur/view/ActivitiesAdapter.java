package com.newsblur.view;

import android.content.Context;
import android.content.res.Resources;
import android.text.Spannable;
import android.text.SpannableStringBuilder;
import android.text.TextUtils;
import android.text.style.ForegroundColorSpan;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.NewsBlurApplication;
import com.newsblur.domain.UserDetails;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.network.APIConstants;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefsUtils;

public class ActivitiesAdapter extends ArrayAdapter<ActivityDetails> {

	private LayoutInflater inflater;
	private ImageLoader imageLoader;
	private final String startedFollowing, ago, repliedTo, sharedStory, favorited, subscribedTo, saved, signup, commentsOn;
	private ForegroundColorSpan linkColor, contentColor, quoteColor;
	private String TAG = "ActivitiesAdapter";
	private Context context;
	private UserDetails currentUserDetails;
	
	public ActivitiesAdapter(final Context context, UserDetails user) {
		super(context, R.id.row_activity_text);
		inflater = LayoutInflater.from(context);
		imageLoader = ((NewsBlurApplication) context.getApplicationContext()).getImageLoader();
		this.context = context;
		
		currentUserDetails = user;
		
		Resources resources = context.getResources();
		startedFollowing = resources.getString(R.string.profile_started_following);
		repliedTo = resources.getString(R.string.profile_replied_to);
		favorited = resources.getString(R.string.profile_favorited);
		sharedStory = resources.getString(R.string.profile_shared_story);
		subscribedTo = resources.getString(R.string.profile_subscribed_to);
		saved = resources.getString(R.string.profile_saved);
		signup = resources.getString(R.string.profile_signup);
		ago = resources.getString(R.string.profile_ago);
		commentsOn = resources.getString(R.string.profile_comments_on);

		if (PrefsUtils.isLightThemeSelected(context)) {
            linkColor = new ForegroundColorSpan(resources.getColor(R.color.linkblue));
            contentColor = new ForegroundColorSpan(resources.getColor(R.color.darkgray));
            // TODO
            quoteColor = new ForegroundColorSpan(resources.getColor(R.color.darkgray));
        } else {
            linkColor = new ForegroundColorSpan(resources.getColor(R.color.dark_linkblue));
            contentColor = new ForegroundColorSpan(resources.getColor(R.color.white));
            quoteColor = new ForegroundColorSpan(resources.getColor(R.color.lightgray));
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
		
		TextView activityText = (TextView) view.findViewById(R.id.row_activity_text);
		TextView activityTime = (TextView) view.findViewById(R.id.row_activity_time);
		ImageView imageView = (ImageView) view.findViewById(R.id.row_activity_icon);
		
		activityTime.setText(activity.timeSince.toUpperCase() + " " + ago);
		if (TextUtils.equals(activity.category, "feedsub")) {
			imageLoader.displayImage(APIConstants.S3_URL_FEED_ICONS + activity.feedId + ".png", imageView);
		} else if (TextUtils.equals(activity.category, "sharedstory")) {
			imageLoader.displayImage(currentUserDetails.photoUrl, imageView, 10f);
		} else if (TextUtils.equals(activity.category, "star")) {
			imageView.setImageResource(R.drawable.clock);
	    } else if (activity.user != null) {
			imageLoader.displayImage(activity.user.photoUrl, imageView);
		} else {
			imageView.setImageResource(R.drawable.logo);
		}

		if (TextUtils.equals(activity.category, "feedsub")) {
			addFeedSubscriptionContent(activity, stringBuilder);
		} else if (TextUtils.equals(activity.category, "star")) {
			addStarContent(activity, stringBuilder);
		} else if (TextUtils.equals(activity.category, "signup")) {
			addSignupContent(stringBuilder);
		} else if (TextUtils.equals(activity.category, "follow")) {
            addFollowContent(activity, stringBuilder);
		} else if (TextUtils.equals(activity.category, "comment_like")) {
			addCommentLikeContent(activity, stringBuilder);
		} else if (TextUtils.equals(activity.category, "comment_reply")) {
			addCommentReplyContent(activity, stringBuilder);
		} else if (TextUtils.equals(activity.category, "sharedstory")) {
			addSharedStoryContent(activity, stringBuilder);
		}
		
		activityText.setText(stringBuilder);
		return view;
	}

	private void addFeedSubscriptionContent(ActivityDetails activity, SpannableStringBuilder stringBuilder) {
		stringBuilder.append(subscribedTo);
		stringBuilder.append(" ");
		stringBuilder.append(activity.content);

		stringBuilder.setSpan(contentColor, 0, subscribedTo.length() + activity.content.length() + 1, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
    }

	private void addStarContent(ActivityDetails activity, SpannableStringBuilder stringBuilder) {
		stringBuilder.append(saved);
		stringBuilder.append(" ");
		stringBuilder.append(activity.content);

        stringBuilder.setSpan(contentColor, 0, saved.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, saved.length() + 1, saved.length() + 1 + activity.content.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
	}

	private void addSignupContent(SpannableStringBuilder stringBuilder) {
		stringBuilder.append(signup);
		stringBuilder.setSpan(contentColor, 0, signup.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
	}

	private void addFollowContent(ActivityDetails activity, SpannableStringBuilder stringBuilder) {
		stringBuilder.append(startedFollowing);
		stringBuilder.append(" ");
		stringBuilder.append(activity.user.username);

		stringBuilder.setSpan(contentColor, 0, startedFollowing.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(linkColor, startedFollowing.length() + 1, startedFollowing.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
	}

	private void addCommentLikeContent(ActivityDetails activity, SpannableStringBuilder stringBuilder) {
		stringBuilder.append(favorited);
		stringBuilder.append(" ");
		stringBuilder.append(activity.user.username);
		stringBuilder.append(" ");
		stringBuilder.append(commentsOn);
		stringBuilder.append(" ");
		stringBuilder.append(activity.title);
		stringBuilder.append("\n\n\"");
		stringBuilder.append(activity.content);
		stringBuilder.append("\" ");

		int usernameLength = activity.user.username.length();
		stringBuilder.setSpan(contentColor, 0, favorited.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		int usernameSpanStart = favorited.length() + 1;
		stringBuilder.setSpan(linkColor, usernameSpanStart, usernameSpanStart + usernameLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);

		int titleSpanStart = usernameSpanStart + usernameLength + 1 + commentsOn.length() + 1;
		int titleLength = activity.title.length();
		stringBuilder.setSpan(linkColor, titleSpanStart, titleSpanStart + titleLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);

		int quoteSpanStart = titleSpanStart + titleLength;
		stringBuilder.setSpan(quoteColor, quoteSpanStart, quoteSpanStart + activity.content.length() + 4, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
	}

	private void addCommentReplyContent(ActivityDetails activity, SpannableStringBuilder stringBuilder) {
		stringBuilder.append(repliedTo);
		stringBuilder.append(" ");
		stringBuilder.append(activity.user.username);
		stringBuilder.append("\n\n\"");
		stringBuilder.append(activity.content);
		stringBuilder.append("\"");

		stringBuilder.setSpan(contentColor, 0, repliedTo.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(linkColor, repliedTo.length() + 1, repliedTo.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		stringBuilder.setSpan(quoteColor, stringBuilder.length() - activity.content.length() - 2, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
	}

	private void addSharedStoryContent(ActivityDetails activity, SpannableStringBuilder stringBuilder) {
		stringBuilder.append(sharedStory);
		stringBuilder.append(" ");
		stringBuilder.append(activity.title);
		stringBuilder.append(" ");
		if (!TextUtils.isEmpty(activity.content)) {
			stringBuilder.append("\n\n\"");
			stringBuilder.append(activity.content);
			stringBuilder.append("\"");
		}

		stringBuilder.setSpan(contentColor, 0, sharedStory.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, sharedStory.length() + 1, sharedStory.length() + 1 + activity.title.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		if (!TextUtils.isEmpty(activity.content)) {
			stringBuilder.setSpan(quoteColor, sharedStory.length() + 2 + activity.title.length(), stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		}
	}
}
