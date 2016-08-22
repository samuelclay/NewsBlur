package com.newsblur.view;

import android.content.Context;
import android.content.res.Resources;
import android.text.style.ForegroundColorSpan;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.UserDetails;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.domain.ActivityDetails.Category;
import com.newsblur.network.APIConstants;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ThemeUtils;

public abstract class ActivityDetailsAdapter extends ArrayAdapter<ActivityDetails> {

    private LayoutInflater inflater;
    protected final String ago;
    protected ForegroundColorSpan linkColor, contentColor, quoteColor;
    private String TAG = "ActivitiesAdapter";
    protected UserDetails currentUserDetails;
    protected final boolean userIsYou;

    public ActivityDetailsAdapter(final Context context, UserDetails user) {
        super(context, R.id.row_activity_text);
        inflater = LayoutInflater.from(context);

        currentUserDetails = user;

        Resources resources = context.getResources();
        ago = resources.getString(R.string.profile_ago);

        linkColor = new ForegroundColorSpan(ThemeUtils.getProfileActivitiesLinkColor(context));
        contentColor = new ForegroundColorSpan(ThemeUtils.getProfileActivitiesContentColor(context));
        quoteColor = new ForegroundColorSpan(ThemeUtils.getProfileActivitiesQuoteColor(context));

        userIsYou = user.userId == null;
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View view = null;
        if (convertView == null) {
            view = inflater.inflate(R.layout.row_activity, null);
        } else {
            view = convertView;
        }
        final ActivityDetails activity = getItem(position);

        TextView activityText = (TextView) view.findViewById(R.id.row_activity_text);
        TextView activityTime = (TextView) view.findViewById(R.id.row_activity_time);
        ImageView imageView = (ImageView) view.findViewById(R.id.row_activity_icon);

        activityTime.setText(activity.timeSince.toUpperCase() + " " + ago);
        if (activity.category == Category.FEED_SUBSCRIPTION) {
            FeedUtils.iconLoader.displayImage(APIConstants.S3_URL_FEED_ICONS + activity.feedId + ".png", imageView, 5, false);
        } else if (activity.category == Category.SHARED_STORY) {
            FeedUtils.iconLoader.displayImage(currentUserDetails.photoUrl, imageView, 10f, false);
        } else if (activity.category == Category.STAR) {
            imageView.setImageResource(R.drawable.clock);
        } else if (activity.user != null) {
            FeedUtils.iconLoader.displayImage(activity.user.photoUrl, imageView, 5, false);
        } else {
            imageView.setImageResource(R.drawable.logo);
        }

        activityText.setText(getTextForActivity(activity));
        return view;
    }

    protected abstract CharSequence getTextForActivity(ActivityDetails activity);
}
