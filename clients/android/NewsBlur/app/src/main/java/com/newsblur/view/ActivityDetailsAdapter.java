package com.newsblur.view;

import android.content.Context;
import android.content.res.Resources;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.TextUtils;
import android.text.style.ForegroundColorSpan;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.TextView;

import com.google.android.material.imageview.ShapeableImageView;
import com.newsblur.R;
import com.newsblur.domain.UserDetails;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.domain.ActivityDetails.Category;
import com.newsblur.network.APIConstants;
import com.newsblur.util.BidiText;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.UIUtils;

public abstract class ActivityDetailsAdapter extends ArrayAdapter<ActivityDetails> {

    private final ImageLoader iconLoader;
    private final LayoutInflater inflater;
    protected final String ago;
    private final int linkColor, contentColor, quoteColor;
    protected final UserDetails currentUserDetails;
    protected final boolean userIsYou;
    protected final String UNKNOWN_USERNAME = "Unknown";

    public ActivityDetailsAdapter(final Context context, UserDetails user, ImageLoader iconLoader) {
        super(context, R.layout.row_activity); // final argument seems unused since we override getView()
        inflater = LayoutInflater.from(context);
        this.iconLoader = iconLoader;
        currentUserDetails = user;

        Resources resources = context.getResources();
        ago = resources.getString(R.string.profile_ago);

        linkColor = UIUtils.getThemedColor(context, R.attr.linkText, android.R.attr.textColor);
        contentColor = UIUtils.getThemedColor(context, R.attr.defaultText, android.R.attr.textColor);
        quoteColor = UIUtils.getThemedColor(context, R.attr.storySnippetText, android.R.attr.textColor);

        userIsYou = user.userId == null;
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View view;
        if (convertView == null) {
            view = inflater.inflate(R.layout.row_activity, null);
        } else {
            view = convertView;
        }
        final ActivityDetails activity = getItem(position);

        TextView activityText = view.findViewById(R.id.row_activity_text);
        TextView activityTime = view.findViewById(R.id.row_activity_time);
        ShapeableImageView imageView = view.findViewById(R.id.row_activity_icon);

        activityTime.setText(activity.timeSince + " " + ago);
        if (activity.category == Category.FEED_SUBSCRIPTION) {
            iconLoader.displayImage(APIConstants.S3_URL_FEED_ICONS + activity.feedId + ".png", imageView);
        } else if (activity.category == Category.SHARED_STORY) {
            iconLoader.displayImage(currentUserDetails.photoUrl, imageView);
        } else if (activity.category == Category.STAR) {
            imageView.setImageResource(R.drawable.ic_saved);
        } else if (activity.user != null) {
            iconLoader.displayImage(activity.user.photoUrl, imageView);
        } else {
            imageView.setImageResource(R.drawable.logo);
        }

        activityText.setText(getTextForActivity(activity));
        return view;
    }

    protected abstract CharSequence getTextForActivity(ActivityDetails activity);

    // ActivityDetailsAdapter.java: each styled range needs its own span object, since a span can
    // only cover one range of a Spannable. Usernames and story titles use the link color, the
    // translated sentence around them uses the default text color, and quoted comments use the
    // story snippet color.
    protected ForegroundColorSpan linkSpan() {
        return new ForegroundColorSpan(linkColor);
    }

    protected ForegroundColorSpan contentSpan() {
        return new ForegroundColorSpan(contentColor);
    }

    protected ForegroundColorSpan quoteSpan() {
        return new ForegroundColorSpan(quoteColor);
    }

    /** The other user in an activity, such as who was followed or who commented. */
    protected String activityUsername(ActivityDetails activity) {
        return activity.user != null ? activity.user.username : UNKNOWN_USERNAME;
    }

    /**
     * Isolates a username, feed or story title (BidiText.kt) so it keeps its own direction inside
     * a translated sentence. A missing title stays empty.
     */
    protected static String isolated(String userContent) {
        return TextUtils.isEmpty(userContent) ? "" : BidiText.isolate(userContent);
    }

    /** Appends a comment as its own quoted paragraph below the activity sentence. */
    protected void appendQuote(SpannableStringBuilder stringBuilder, String comment) {
        stringBuilder.append("\n\n");
        int quoteStart = stringBuilder.length();
        stringBuilder.append("\"").append(comment).append("\"");
        stringBuilder.setSpan(quoteSpan(), quoteStart, stringBuilder.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
    }
}
