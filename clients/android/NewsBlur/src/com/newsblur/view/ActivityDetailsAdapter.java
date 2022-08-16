package com.newsblur.view;

import android.content.Context;
import android.content.res.Resources;
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
import com.newsblur.util.ImageLoader;
import com.newsblur.util.UIUtils;

public abstract class ActivityDetailsAdapter extends ArrayAdapter<ActivityDetails> {

    private final ImageLoader iconLoader;
    private final LayoutInflater inflater;
    protected final String ago;
    protected ForegroundColorSpan linkColor, contentColor, quoteColor;
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

        linkColor = new ForegroundColorSpan(UIUtils.getThemedColor(context, R.attr.linkText, android.R.attr.textColor));
        contentColor = new ForegroundColorSpan(UIUtils.getThemedColor(context, R.attr.defaultText, android.R.attr.textColor));
        quoteColor = new ForegroundColorSpan(UIUtils.getThemedColor(context, R.attr.storySnippetText, android.R.attr.textColor));

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
}
