package com.newsblur.view;

import android.content.Context;
import android.content.res.Resources;
import android.text.SpannableStringBuilder;
import android.text.TextUtils;

import com.newsblur.R;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.domain.UserDetails;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.SpannedFormat;
import com.newsblur.util.SpannedFormat.Argument;

/**
 * Created by mark on 17/06/15.
 *
 * ActivitiesAdapter.java renders a profile's own activity as complete translated sentences, such
 * as "You subscribed to %1$s" or "%1$s subscribed to %2$s", and colors the arguments wherever each
 * translation places them (SpannedFormat.kt). Sentences about the reader have their own strings
 * because many languages conjugate the verb differently for "you".
 */
public class ActivitiesAdapter extends ActivityDetailsAdapter {

    private final Resources resources;

    public ActivitiesAdapter(final Context context, UserDetails user, ImageLoader iconLoader) {
        super(context, user, iconLoader);
        resources = context.getResources();
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

    /**
     * Formats the sentence about this profile. When the profile is the reader's own, the "you"
     * string is used and the profile's username is left out of the arguments.
     */
    private SpannableStringBuilder format(int youTemplate, int userTemplate, Argument... arguments) {
        if (userIsYou) {
            return SpannedFormat.format(resources.getString(youTemplate), this::contentSpan, arguments);
        }
        Argument[] withUser = new Argument[arguments.length + 1];
        withUser[0] = new Argument(isolated(currentUserDetails.username), this::contentSpan);
        System.arraycopy(arguments, 0, withUser, 1, arguments.length);
        return SpannedFormat.format(resources.getString(userTemplate), this::contentSpan, withUser);
    }

    private CharSequence getFeedSubscriptionContent(ActivityDetails activity) {
        return format(R.string.profile_activity_you_subscribed, R.string.profile_activity_user_subscribed,
                new Argument(isolated(activity.content), this::contentSpan));
    }

    private CharSequence getStarContent(ActivityDetails activity) {
        return format(R.string.profile_activity_you_saved, R.string.profile_activity_user_saved,
                new Argument(isolated(activity.content), this::linkSpan));
    }

    private CharSequence getSignupContent() {
        return format(R.string.profile_activity_you_signed_up, R.string.profile_activity_user_signed_up);
    }

    private CharSequence getFollowContent(ActivityDetails activity) {
        return format(R.string.profile_activity_you_followed, R.string.profile_activity_user_followed,
                new Argument(isolated(activityUsername(activity)), this::linkSpan));
    }

    private CharSequence getCommentLikeContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = format(
                R.string.profile_activity_you_favorited_comments, R.string.profile_activity_user_favorited_comments,
                new Argument(isolated(activityUsername(activity)), this::linkSpan),
                new Argument(isolated(activity.title), this::linkSpan));
        appendQuote(stringBuilder, activity.content);
        return stringBuilder;
    }

    private CharSequence getCommentReplyContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = format(
                R.string.profile_activity_you_replied, R.string.profile_activity_user_replied,
                new Argument(isolated(activityUsername(activity)), this::linkSpan));
        appendQuote(stringBuilder, activity.content);
        return stringBuilder;
    }

    private CharSequence getSharedStoryContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = format(
                R.string.profile_activity_you_shared, R.string.profile_activity_user_shared,
                new Argument(isolated(activity.title), this::linkSpan));
        if (!TextUtils.isEmpty(activity.content)) {
            appendQuote(stringBuilder, activity.content);
        }
        return stringBuilder;
    }
}
