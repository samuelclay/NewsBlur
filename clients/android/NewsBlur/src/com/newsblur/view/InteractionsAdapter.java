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
public class InteractionsAdapter extends ActivityDetailsAdapter {

    private final String nowFollowingYou, repliedToYour, comment, reply, favoritedComments, reshared, your, you;

    public InteractionsAdapter(final Context context, UserDetails user, ImageLoader iconLoader) {
        super(context, user, iconLoader);

        Resources resources = context.getResources();
        nowFollowingYou = resources.getString(R.string.profile_now_following);
        repliedToYour = resources.getString(R.string.profile_replied_to_your);
        comment = resources.getString(R.string.profile_comment);
        reply = resources.getString(R.string.profile_reply);
        favoritedComments = resources.getString(R.string.profile_favorited_comments);
        reshared = resources.getString(R.string.profile_reshared);
        your = resources.getString(R.string.profile_your);
        you = resources.getString(R.string.profile_you_lower);
    }

    @Override
    protected CharSequence getTextForActivity(ActivityDetails activity) {
        if (activity.category == ActivityDetails.Category.FOLLOW) {
            String userString = you;
            if (!userIsYou) {
                userString = currentUserDetails.username;
            }
            return getFollowContent(activity, userString);
        } else if (activity.category == ActivityDetails.Category.COMMENT_LIKE) {
            String userString = your;
            if (!userIsYou) {
                userString = currentUserDetails.username + "'s";
            }
            return getCommentLikeContent(activity, userString);
        } else if (activity.category == ActivityDetails.Category.COMMENT_REPLY ||
                   activity.category == ActivityDetails.Category.REPLY_REPLY) {
            String userString = your;
            if (!userIsYou) {
                userString = currentUserDetails.username + "'s";
            }
            return getCommentReplyContent(activity, userString);
        } else {
            return getSharedStoryContent(activity);
        }
    }

    private CharSequence getFollowContent(ActivityDetails activity, String userString) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        int usernameLength;
        if (activity.user != null) {
            usernameLength = activity.user.username.length();
            stringBuilder.append(activity.user.username);
        } else {
            usernameLength = UNKNOWN_USERNAME.length();
            stringBuilder.append(UNKNOWN_USERNAME);
        }
        stringBuilder.append(" ");
        stringBuilder.append(String.format(nowFollowingYou, userString));

        stringBuilder.setSpan(linkColor, 0, usernameLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(contentColor, usernameLength + 1, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder;
    }

    private CharSequence getCommentLikeContent(ActivityDetails activity, String userString) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        int usernameLength;
        if (activity.user != null) {
            usernameLength = activity.user.username.length();
            stringBuilder.append(activity.user.username);
        } else {
            usernameLength = UNKNOWN_USERNAME.length();
            stringBuilder.append(UNKNOWN_USERNAME);
        }
        stringBuilder.append(" ");
        String favoritedString = String.format(favoritedComments, userString);
        stringBuilder.append(favoritedString);
        stringBuilder.append(" ");
        stringBuilder.append(activity.title);
        stringBuilder.append("\n\n\"");
        stringBuilder.append(activity.content);
        stringBuilder.append("\" ");

        int titleSpanStart = usernameLength + 1 + favoritedString.length() + 1;
        int titleLength = activity.title.length();
        stringBuilder.setSpan(linkColor, 0, titleSpanStart + titleLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(contentColor, usernameLength + 1, usernameLength + 1 + favoritedString.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);

        int quoteSpanStart = titleSpanStart + titleLength;
        stringBuilder.setSpan(quoteColor, quoteSpanStart, quoteSpanStart + activity.content.length() + 4, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder;
    }

    private CharSequence getCommentReplyContent(ActivityDetails activity, String userString) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        int usernameLength;
        if (activity.user != null) {
            usernameLength = activity.user.username.length();
            stringBuilder.append(activity.user.username);
        } else {
            usernameLength = UNKNOWN_USERNAME.length();
            stringBuilder.append(UNKNOWN_USERNAME);
        }
        stringBuilder.append(" ");
        stringBuilder.append(String.format(repliedToYour, userString));
        stringBuilder.append(" ");
        int commentReplyLength;
        if (activity.category == ActivityDetails.Category.COMMENT_REPLY) {
            stringBuilder.append(comment);
            commentReplyLength = comment.length();
        } else {
            stringBuilder.append(reply);
            commentReplyLength = reply.length();
        }
        stringBuilder.append("\n\n\"");
        stringBuilder.append(activity.content);
        stringBuilder.append("\"");

        stringBuilder.setSpan(linkColor, 0, usernameLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(contentColor, usernameLength + 1, usernameLength + 1 + repliedToYour.length() + 1 + commentReplyLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(quoteColor, stringBuilder.length() - activity.content.length() - 2, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder;
    }

    private CharSequence getSharedStoryContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        int usernameLength;
        if (activity.user != null) {
            usernameLength = activity.user.username.length();
            stringBuilder.append(activity.user.username);
        } else {
            usernameLength = UNKNOWN_USERNAME.length();
            stringBuilder.append(UNKNOWN_USERNAME);
        }
        stringBuilder.append(" ");
        stringBuilder.append(reshared);
        stringBuilder.append(" ");
        stringBuilder.append(activity.title);
        stringBuilder.append(" ");
        if (!TextUtils.isEmpty(activity.content)) {
            stringBuilder.append("\n\n\"");
            stringBuilder.append(activity.content);
            stringBuilder.append("\"");
        }

        int titleSpanStart = usernameLength + 1 + reshared.length() + 1;
        int titleLength = activity.title.length();
        stringBuilder.setSpan(linkColor, 0, titleSpanStart + titleLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(contentColor, usernameLength + 1, usernameLength + 1 + reshared.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);

        if (!TextUtils.isEmpty(activity.content)) {
            stringBuilder.setSpan(quoteColor, stringBuilder.length() - activity.content.length() - 2, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        }
        return stringBuilder;
    }
}
