package com.newsblur.view;

import android.content.Context;
import android.content.res.Resources;
import android.text.Spannable;
import android.text.SpannableString;
import android.text.TextUtils;
import android.text.style.ForegroundColorSpan;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.network.domain.ActivitiesResponse;
import com.newsblur.util.ImageLoader;

public class ActivitiesAdapter extends ArrayAdapter<ActivitiesResponse> {

	private LayoutInflater inflater;
	private ImageLoader imageLoader;
	private final String startedFollowing, ago, repliedTo, sharedStory, withComment;
	private ForegroundColorSpan midgray, highlight, darkgray;
	
	public ActivitiesAdapter(Context context, final ActivitiesResponse[] activities) {
		super(context, R.id.row_activity_text);
		inflater = LayoutInflater.from(context);
		imageLoader = new ImageLoader(context);
		
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
		ActivitiesResponse activity = getItem(position);
		Spannable activityUpdate = null;
		
		if (TextUtils.equals(activity.category, "follow")) {
			activityUpdate = new SpannableString(startedFollowing + " " + activity.user.username);
			activityUpdate.setSpan(darkgray, 0, startedFollowing.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			activityUpdate.setSpan(highlight, startedFollowing.length() + 1, startedFollowing.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		} else if (TextUtils.equals(activity.category, "comment_reply")) {
			activityUpdate = new SpannableString(repliedTo + " " + activity.user.username + ": \"" + activity.content + "\"");
			activityUpdate.setSpan(darkgray, 0, repliedTo.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			activityUpdate.setSpan(highlight, repliedTo.length() + 1, repliedTo.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			activityUpdate.setSpan(midgray, activityUpdate.length() - activity.content.length() - 2, activityUpdate.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		} else if (TextUtils.equals(activity.category, "sharedstory")) {
			activityUpdate = new SpannableString(sharedStory + " \"" + activity.title + "\" " + withComment + ": \"" + activity.content + "\"");
			activityUpdate.setSpan(darkgray, 0, sharedStory.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			activityUpdate.setSpan(highlight, sharedStory.length() + 1, sharedStory.length() + 2 + activity.title.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
			activityUpdate.setSpan(midgray, sharedStory.length() + 4 + activity.title.length() + withComment.length(), activityUpdate.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
		}
		
		TextView activityText = (TextView) view.findViewById(R.id.row_activity_text);
		TextView activityTime = (TextView) view.findViewById(R.id.row_activity_time);
		ImageView imageView = (ImageView) view.findViewById(R.id.row_activity_icon);
		
		activityTime.setText(activity.timeSince + " " + ago);
		imageLoader.DisplayImage(activity.user.photoUrl, imageView);
		
		activityText.setText(activityUpdate);
		
		return view;
	}

}
