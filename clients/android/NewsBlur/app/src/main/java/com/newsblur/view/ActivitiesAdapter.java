package com.newsblur.view;

import android.content.Context;
import android.content.res.Resources;
import android.text.Spannable;
import android.text.SpannableStringBuilder;
import android.text.TextUtils;

import com.newsblur.R;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.domain.UserDetails;
import com.newsblur.util.ImageLoader;

/**
 * Created by mark on 17/06/15.
 */
public class ActivitiesAdapter extends ActivityDetailsAdapter {

    private final String startedFollowing, repliedTo, favorited, subscribedTo, saved, signup, commentsOn, sharedStory, you;

    public ActivitiesAdapter(final Context context, UserDetails user, ImageLoader iconLoader) {
        super(context, user, iconLoader);

        Resources resources = context.getResources();
        startedFollowing = resources.getString(R.string.profile_started_following);
        repliedTo = resources.getString(R.string.profile_replied_to);
        favorited = resources.getString(R.string.profile_favorited);
        subscribedTo = resources.getString(R.string.profile_subscribed_to);
        saved = resources.getString(R.string.profile_saved);
        signup = resources.getString(R.string.profile_signup);
        commentsOn = resources.getString(R.string.profile_comments_on);
        sharedStory = resources.getString(R.string.profile_shared_story);
        you = resources.getString(R.string.profile_you);

    }

    @Override
    protected CharSequence getTextForActivity(ActivityDetails activity) {
        String userString = you;
        if (!userIsYou) {
            userString = currentUserDetails.username;
        }

        if (activity.category == ActivityDetails.Category.FEED_SUBSCRIPTION) {
            return getFeedSubscriptionContent(activity, userString);
        } else if (activity.category == ActivityDetails.Category.STAR) {
            return getStarContent(activity, userString);
        } else if (activity.category == ActivityDetails.Category.SIGNUP) {
            return getSignupContent(userString);
        } else if (activity.category == ActivityDetails.Category.FOLLOW) {
            return getFollowContent(activity, userString);
        } else if (activity.category == ActivityDetails.Category.COMMENT_LIKE) {
            return getCommentLikeContent(activity, userString);
        } else if (activity.category == ActivityDetails.Category.COMMENT_REPLY) {
            return getCommentReplyContent(activity, userString);
        } else {
            return getSharedStoryContent(activity, userString);
        }
    }

    private CharSequence getFeedSubscriptionContent(ActivityDetails activity, String userString) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(userString);
        stringBuilder.append(" ");
        stringBuilder.append(subscribedTo);
        stringBuilder.append(" ");
        stringBuilder.append(activity.content);

        stringBuilder.setSpan(contentColor, 0, userString.length() + subscribedTo.length() + activity.content.length() + 2, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder;
    }

    private CharSequence getStarContent(ActivityDetails activity, String userString) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(userString);
        stringBuilder.append(" ");
        stringBuilder.append(saved);
        stringBuilder.append(" ");
        stringBuilder.append(activity.content);

        int contentColorLength = userString.length() + saved.length() + 1;
        stringBuilder.setSpan(contentColor, 0, contentColorLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, contentColorLength + 1, contentColorLength + 1 + activity.content.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder;
    }

    private CharSequence getSignupContent(String userString) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(userString);
        stringBuilder.append(" ");
        stringBuilder.append(signup);
        stringBuilder.setSpan(contentColor, 0, userString.length() + signup.length() + 1, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder;
    }

    private CharSequence getFollowContent(ActivityDetails activity, String userString) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        int usernameLength;
        stringBuilder.append(userString);
        stringBuilder.append(" ");
        stringBuilder.append(startedFollowing);
        stringBuilder.append(" ");
        if (activity.user != null) {
            stringBuilder.append(activity.user.username);
            usernameLength = activity.user.username.length();
        } else {
            stringBuilder.append(UNKNOWN_USERNAME);
            usernameLength = UNKNOWN_USERNAME.length();
        }

        int contentColorLength = userString.length() + startedFollowing.length() + 1;
        stringBuilder.setSpan(contentColor, 0, contentColorLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, contentColorLength + 1, contentColorLength + 1 + usernameLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder;
    }

    private CharSequence getCommentLikeContent(ActivityDetails activity, String userString) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        int usernameLength;
        stringBuilder.append(userString);
        stringBuilder.append(" ");
        stringBuilder.append(favorited);
        stringBuilder.append(" ");
        if (activity.user != null) {
            stringBuilder.append(activity.user.username);
            usernameLength = activity.user.username.length();
        } else {
            stringBuilder.append(UNKNOWN_USERNAME);
            usernameLength = UNKNOWN_USERNAME.length();
        }
        stringBuilder.append(" ");
        stringBuilder.append(commentsOn);
        stringBuilder.append(" ");
        stringBuilder.append(activity.title);
        stringBuilder.append("\n\n\"");
        stringBuilder.append(activity.content);
        stringBuilder.append("\" ");

        stringBuilder.setSpan(contentColor, 0, userString.length() + favorited.length() + 1, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        int usernameSpanStart = userString.length() + favorited.length() + 2;
        stringBuilder.setSpan(linkColor, usernameSpanStart, usernameSpanStart + usernameLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);

        int titleSpanStart = usernameSpanStart + usernameLength + 1 + commentsOn.length() + 1;
        int titleLength = activity.title.length();
        stringBuilder.setSpan(linkColor, titleSpanStart, titleSpanStart + titleLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);

        int quoteSpanStart = titleSpanStart + titleLength;
        stringBuilder.setSpan(quoteColor, quoteSpanStart, quoteSpanStart + activity.content.length() + 4, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder;
    }

    private CharSequence getCommentReplyContent(ActivityDetails activity, String userString) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        int usernameLength;
        stringBuilder.append(userString);
        stringBuilder.append(" ");
        stringBuilder.append(repliedTo);
        stringBuilder.append(" ");
        if (activity.user != null) {
            stringBuilder.append(activity.user.username);
            usernameLength = activity.user.username.length();
        } else {
            stringBuilder.append(UNKNOWN_USERNAME);
            usernameLength = UNKNOWN_USERNAME.length();
        }
        stringBuilder.append("\n\n\"");
        stringBuilder.append(activity.content);
        stringBuilder.append("\"");

        stringBuilder.setSpan(contentColor, 0, userString.length() + repliedTo.length() + 1, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, userString.length() + repliedTo.length() + 2, userString.length() + repliedTo.length() + 2 + usernameLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(quoteColor, stringBuilder.length() - activity.content.length() - 2, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder;
    }

    private CharSequence getSharedStoryContent(ActivityDetails activity, String userString) {
        int activityTitleLength = 0;
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(userString);
        stringBuilder.append(" ");
        stringBuilder.append(sharedStory);
        stringBuilder.append(" ");
        if (!TextUtils.isEmpty(activity.title)) {
            activityTitleLength = activity.title.length();
            stringBuilder.append(activity.title);
            stringBuilder.append(" ");
        }
        if (!TextUtils.isEmpty(activity.content)) {
            stringBuilder.append("\n\n\"");
            stringBuilder.append(activity.content);
            stringBuilder.append("\"");
        }

        stringBuilder.setSpan(contentColor, 0, userString.length() + sharedStory.length() + 1, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, userString.length() + sharedStory.length() + 2, userString.length() + sharedStory.length() + 2 + activityTitleLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        if (!TextUtils.isEmpty(activity.content)) {
            stringBuilder.setSpan(quoteColor, userString.length() + sharedStory.length() + 3 + activityTitleLength, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        }
        return stringBuilder;
    }
}
