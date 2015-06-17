package com.newsblur.view;

import android.content.Context;
import android.content.res.Resources;
import android.text.Spannable;
import android.text.SpannableStringBuilder;
import android.text.TextUtils;

import com.newsblur.R;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.domain.UserDetails;

/**
 * Created by mark on 17/06/15.
 */
public class ActivitiesAdapter extends ActivityDetailsAdapter {

    private final String startedFollowing, repliedTo, favorited, subscribedTo, saved, signup, commentsOn, sharedStory;

    public ActivitiesAdapter(final Context context, UserDetails user) {
        super(context, user);

        Resources resources = context.getResources();
        startedFollowing = resources.getString(R.string.profile_started_following);
        repliedTo = resources.getString(R.string.profile_replied_to);
        favorited = resources.getString(R.string.profile_favorited);
        subscribedTo = resources.getString(R.string.profile_subscribed_to);
        saved = resources.getString(R.string.profile_saved);
        signup = resources.getString(R.string.profile_signup);
        commentsOn = resources.getString(R.string.profile_comments_on);
        sharedStory = resources.getString(R.string.profile_shared_story);
    }

    @Override
    protected CharSequence getTextForActivity(ActivityDetails activity) {
        if (activity.category == ActivityDetails.Category.FEED_SUBSCRIPTION) {
            return getFeedSubscriptionContent(activity);
        } else if (activity.category == ActivityDetails.Category.STAR) {
            return getStarContent(activity);
        } else if (activity.category == ActivityDetails.Category.SIGNUP) {
            return getSignupContent();
        } else if (activity.category == ActivityDetails.Category.FOLLOW) {
            return getFollowContent(activity);
        } else if (activity.category == ActivityDetails.Category.COMMENT_LIKE) {
            return getCommentLikeContent(activity);
        } else if (activity.category == ActivityDetails.Category.COMMENT_REPLY) {
            return getCommentReplyContent(activity);
        } else {
            return getSharedStoryContent(activity);
        }
    }

    private CharSequence getFeedSubscriptionContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(subscribedTo);
        stringBuilder.append(" ");
        stringBuilder.append(activity.content);

        stringBuilder.setSpan(contentColor, 0, subscribedTo.length() + activity.content.length() + 1, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder.toString();
    }

    private CharSequence getStarContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(saved);
        stringBuilder.append(" ");
        stringBuilder.append(activity.content);

        stringBuilder.setSpan(contentColor, 0, saved.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, saved.length() + 1, saved.length() + 1 + activity.content.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder.toString();
    }

    private CharSequence getSignupContent() {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(signup);
        stringBuilder.setSpan(contentColor, 0, signup.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder.toString();
    }

    private CharSequence getFollowContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(startedFollowing);
        stringBuilder.append(" ");
        stringBuilder.append(activity.user.username);

        stringBuilder.setSpan(contentColor, 0, startedFollowing.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, startedFollowing.length() + 1, startedFollowing.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder.toString();
    }

    private CharSequence getCommentLikeContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
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
        return stringBuilder.toString();
    }

    private CharSequence getCommentReplyContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(repliedTo);
        stringBuilder.append(" ");
        stringBuilder.append(activity.user.username);
        stringBuilder.append("\n\n\"");
        stringBuilder.append(activity.content);
        stringBuilder.append("\"");

        stringBuilder.setSpan(contentColor, 0, repliedTo.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, repliedTo.length() + 1, repliedTo.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(quoteColor, stringBuilder.length() - activity.content.length() - 2, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder.toString();
    }

    private CharSequence getSharedStoryContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
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
        return stringBuilder.toString();
    }
}
