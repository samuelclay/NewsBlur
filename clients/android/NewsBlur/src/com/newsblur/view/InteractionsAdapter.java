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
public class InteractionsAdapter extends ActivityDetailsAdapter {

    private final String nowFollowingYou, repliedToYour, comment, reply, favoritedComments, reshared;

    public InteractionsAdapter(final Context context, UserDetails user) {
        super(context, user);

        Resources resources = context.getResources();
        nowFollowingYou = resources.getString(R.string.profile_now_following);
        repliedToYour = resources.getString(R.string.profile_replied_to_your);
        comment = resources.getString(R.string.profile_comment);
        reply = resources.getString(R.string.profile_reply);
        favoritedComments = resources.getString(R.string.profile_favorited_comments);
        reshared = resources.getString(R.string.profile_reshared);
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

    private CharSequence getFollowContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(activity.user.username);
        stringBuilder.append(" ");
        stringBuilder.append(nowFollowingYou);

        stringBuilder.setSpan(contentColor, 0, nowFollowingYou.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, nowFollowingYou.length() + 1, nowFollowingYou.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder.toString();
    }

    private CharSequence getCommentLikeContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(activity.user.username);
        stringBuilder.append(" ");
        stringBuilder.append(favoritedComments);
        stringBuilder.append(" ");
        stringBuilder.append(activity.title);
        stringBuilder.append("\n\n\"");
        stringBuilder.append(activity.content);
        stringBuilder.append("\" ");

        int usernameLength = activity.user.username.length();
        stringBuilder.setSpan(contentColor, 0, favoritedComments.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        int usernameSpanStart = favoritedComments.length() + 1;
        stringBuilder.setSpan(linkColor, usernameSpanStart, usernameSpanStart + usernameLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);

        int titleSpanStart = usernameSpanStart + usernameLength + 1 + favoritedComments.length() + 1;
        int titleLength = activity.title.length();
        stringBuilder.setSpan(linkColor, titleSpanStart, titleSpanStart + titleLength, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);

        int quoteSpanStart = titleSpanStart + titleLength;
        stringBuilder.setSpan(quoteColor, quoteSpanStart, quoteSpanStart + activity.content.length() + 4, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder.toString();
    }

    private CharSequence getCommentReplyContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(activity.user.username);
        stringBuilder.append(" ");
        stringBuilder.append(repliedToYour);
        stringBuilder.append(" ");
        if (activity.category == ActivityDetails.Category.COMMENT_REPLY) {
            stringBuilder.append(comment);
        } else {
            stringBuilder.append(reply);
        }
        stringBuilder.append("\n\n\"");
        stringBuilder.append(activity.content);
        stringBuilder.append("\"");

        stringBuilder.setSpan(contentColor, 0, repliedToYour.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, repliedToYour.length() + 1, repliedToYour.length() + 1 + activity.user.username.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(quoteColor, stringBuilder.length() - activity.content.length() - 2, stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        return stringBuilder.toString();
    }

    private CharSequence getSharedStoryContent(ActivityDetails activity) {
        SpannableStringBuilder stringBuilder = new SpannableStringBuilder();
        stringBuilder.append(activity.user.username);
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

        stringBuilder.setSpan(contentColor, 0, reshared.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        stringBuilder.setSpan(linkColor, reshared.length() + 1, reshared.length() + 1 + activity.title.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        if (!TextUtils.isEmpty(activity.content)) {
            stringBuilder.setSpan(quoteColor, reshared.length() + 2 + activity.title.length(), stringBuilder.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        }
        return stringBuilder.toString();
    }
}
