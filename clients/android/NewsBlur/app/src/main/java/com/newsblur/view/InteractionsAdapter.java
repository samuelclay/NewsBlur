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
 * InteractionsAdapter.java renders what other people did to a profile as complete translated
 * sentences, such as "%1$s favorited your comments on %2$s" or "%1$s favorited %2$s's comments on
 * %3$s", and colors the arguments wherever each translation places them (SpannedFormat.kt). The
 * "your" and "%2$s's" forms are separate strings so each language can phrase the possessive itself.
 */
public class InteractionsAdapter extends ActivityDetailsAdapter {

    private final Resources resources;

    public InteractionsAdapter(final Context context, UserDetails user, ImageLoader iconLoader) {
        super(context, user, iconLoader);
        resources = context.getResources();
    }

    @Override
    protected CharSequence getTextForActivity(ActivityDetails activity) {
        if (activity.category == ActivityDetails.Category.FOLLOW) {
            return getFollowContent(activity);
        } else if (activity.category == ActivityDetails.Category.COMMENT_LIKE) {
            return getCommentLikeContent(activity);
        } else if (activity.category == ActivityDetails.Category.COMMENT_REPLY ||
                   activity.category == ActivityDetails.Category.REPLY_REPLY) {
            return getCommentReplyContent(activity);
        } else {
            return getSharedStoryContent(activity);
        }
    }

    /**
     * Formats a sentence whose first argument is the person who interacted. When the profile is
     * the reader's own, the "you"/"your" string is used and the profile's username is left out;
     * otherwise it follows the actor as the second argument.
     */
    private SpannableStringBuilder format(ActivityDetails activity, int youTemplate, int userTemplate, Argument... arguments) {
        Argument actor = new Argument(isolated(activityUsername(activity)), this::linkSpan);
        Argument[] all;
        int template;
        if (userIsYou) {
            all = new Argument[arguments.length + 1];
            all[0] = actor;
            System.arraycopy(arguments, 0, all, 1, arguments.length);
            template = youTemplate;
        } else {
            all = new Argument[arguments.length + 2];
            all[0] = actor;
            all[1] = new Argument(isolated(currentUserDetails.username), this::contentSpan);
            System.arraycopy(arguments, 0, all, 2, arguments.length);
            template = userTemplate;
        }
        return SpannedFormat.format(resources.getString(template), this::contentSpan, all);
    }

    private CharSequence getFollowContent(ActivityDetails activity) {
        return format(activity, R.string.profile_interaction_following_you, R.string.profile_interaction_following_user);
    }

    private CharSequence getCommentLikeContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = format(activity,
                R.string.profile_interaction_favorited_your_comments, R.string.profile_interaction_favorited_user_comments,
                new Argument(isolated(activity.title), this::linkSpan));
        appendQuote(stringBuilder, activity.content);
        return stringBuilder;
    }

    private CharSequence getCommentReplyContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder;
        if (activity.category == ActivityDetails.Category.COMMENT_REPLY) {
            stringBuilder = format(activity,
                    R.string.profile_interaction_replied_your_comment, R.string.profile_interaction_replied_user_comment);
        } else {
            stringBuilder = format(activity,
                    R.string.profile_interaction_replied_your_reply, R.string.profile_interaction_replied_user_reply);
        }
        appendQuote(stringBuilder, activity.content);
        return stringBuilder;
    }

    private CharSequence getSharedStoryContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = SpannedFormat.format(
                resources.getString(R.string.profile_interaction_reshared), this::contentSpan,
                new Argument(isolated(activityUsername(activity)), this::linkSpan),
                new Argument(isolated(activity.title), this::linkSpan));
        if (!TextUtils.isEmpty(activity.content)) {
            appendQuote(stringBuilder, activity.content);
        }
        return stringBuilder;
    }
}
