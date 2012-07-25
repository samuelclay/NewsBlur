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
import com.newsblur.activity.Profile;
import com.newsblur.network.domain.ActivitiesResponse;
import com.newsblur.util.ImageLoader;

public class ActivitiesAdapter extends ArrayAdapter<ActivitiesResponse> {

	private LayoutInflater inflater;
	private ImageLoader imageLoader;
	private final String startedFollowing, ago, repliedTo, sharedStory, withComment;
	private ForegroundColorSpan midgray, highlight, darkgray;
	private String TAG = "ActivitiesAdapter";
	private Context context;
	
	public ActivitiesAdapter(final Context context, final ActivitiesResponse[] activities) {
		super(context, R.id.row_activity_text);
		inflater = LayoutInflater.from(context);
		imageLoader = new ImageLoader(context);
		this.context = context;
		
		for (ActivitiesResponse response : activities) {
			add(response);
		}
		
		Resources resources = context.getResources();
		startedFollowing = resources.getString(R.string.profile_started_following);
		repliedTo = resources.getString(R.string.profile_replied_to);
		sharedStory = resources.getString(R.string.profile_shared_story);
		withComment = resources.getString(R.string.profile_with_comment);
		ago = resources.getString(R.string.profile_ago);
		
		highlight = new ForegroundColorSpan(resources.getColor(R.color.lightorange));
		midgray = new ForegroundColorSpan(resources.getColor(R.color.midgray));
		darkgray = new ForegroundColorSpan(resources.getColor(R.color.darkgray));
	}
	
	@Override
	public View getView(int position, View convertView, ViewGroup parent) {
		View view = null;
		if (convertView == null) {
			view = inflater.inflate(R.layout.row_activity, null);
		} else {
			view = convertView;
		}
		final ActivitiesResponse activity = getItem(position);
		SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
		
		ClickableSpan usernameClick = new ClickableSpan() {
			@Override
			public void onClick(View widget) {
				Intent i = new Intent(context, Profile.class);
				i.putExtra(Profile.USER_ID, activity.id);
				context.startActivity(i);
			}
		};
		
		if (TextUtils.equals(activity.category, "follow")) {
			stringBuilder.append(startedFollowing);
			stringBuilder.append(" ");
			stringBuilder.append(activity.user.username);
			stringBuilder.setSpan(darkgray, 0, startedFollowing.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			stringBuilder.setSpan(usernameClick, startedFollowing.length() + 1, startedFollowing.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			stringBuilder.setSpan(highlight, startedFollowing.length() + 1, startedFollowing.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		} else if (TextUtils.equals(activity.category, "comment_reply")) {
			stringBuilder.append(repliedTo);
			stringBuilder.append(" ");
			stringBuilder.append(activity.user.username);
			stringBuilder.append(": \"");
			stringBuilder.append(activity.content);
			stringBuilder.append("\"");
			stringBuilder.setSpan(darkgray, 0, repliedTo.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			stringBuilder.setSpan(usernameClick, repliedTo.length() + 1, repliedTo.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			stringBuilder.setSpan(highlight, repliedTo.length() + 1, repliedTo.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			stringBuilder.setSpan(midgray, stringBuilder.length() - activity.content.length() - 2, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		} else if (TextUtils.equals(activity.category, "sharedstory")) {
			stringBuilder.append(sharedStory);
			stringBuilder.append(" \"");
			stringBuilder.append(activity.title);
			stringBuilder.append("\" ");
			if (!TextUtils.isEmpty(activity.content)) {
				stringBuilder.append(withComment);
				stringBuilder.append(": \"");
				stringBuilder.append(activity.content);
				stringBuilder.append("\"");
			}
			stringBuilder.setSpan(darkgray, 0, sharedStory.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			stringBuilder.setSpan(highlight, sharedStory.length() + 1, sharedStory.length() + 2 + activity.title.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			if (!TextUtils.isEmpty(activity.content)) {
				stringBuilder.setSpan(midgray, sharedStory.length() + 4 + activity.title.length() + withComment.length(), stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			}
		}
		
		TextView activityText = (TextView) view.findViewById(R.id.row_activity_text);
		TextView activityTime = (TextView) view.findViewById(R.id.row_activity_time);
		ImageView imageView = (ImageView) view.findViewById(R.id.row_activity_icon);
		
		activityTime.setText(activity.timeSince + " " + ago);
		imageLoader.displayImage(activity.user.photoUrl, activity.id, imageView);
		
		activityText.setText(stringBuilder);
		activityText.setMovementMethod(LinkMovementMethod.getInstance());
		
		return view;
	}

}
