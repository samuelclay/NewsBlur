package com.newsblur.activity;

import android.view.View;
import android.view.ViewGroup;
import android.widget.CheckBox;
import android.widget.ImageView;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.preference.PrefRepository;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ImageLoader;

import java.util.ArrayList;

public class WidgetConfigAdapter extends FeedChooserAdapter {

    WidgetConfigAdapter(FeedUtils feedUtils, ImageLoader iconLoader, PrefRepository prefRepository) {
        super(feedUtils, iconLoader, prefRepository);
    }

    @Override
    public View getGroupView(final int groupPosition, boolean isExpanded, View convertView, final ViewGroup parent) {
        View groupView = super.getGroupView(groupPosition, isExpanded, convertView, parent);

        groupView.setOnClickListener(v -> {
            ArrayList<Feed> folderChild = WidgetConfigAdapter.this.folderChildren.get(groupPosition);
            // check all is selected
            boolean allSelected = true;
            for (Feed feed : folderChild) {
                if (!feedIds.contains(feed.feedId)) {
                    allSelected = false;
                    break;
                }
            }
            for (Feed feed : folderChild) {
                if (allSelected) {
                    feedIds.remove(feed.feedId);
                } else {
                    feedIds.add(feed.feedId);
                }
            }
            setWidgetFeedIds();
            notifyDataChanged();
        });
        return groupView;
    }

    @Override
    public View getChildView(int groupPosition, int childPosition, boolean isLastChild, View convertView, final ViewGroup parent) {
        View childView = super.getChildView(groupPosition, childPosition, isLastChild, convertView, parent);
        final Feed feed = folderChildren.get(groupPosition).get(childPosition);
        final CheckBox checkBox = childView.findViewById(R.id.check_box);
        final ImageView imgToggle = childView.findViewById(R.id.img_toggle);
        checkBox.setVisibility(View.VISIBLE);
        imgToggle.setVisibility(View.GONE);

        childView.setOnClickListener(v -> {
            checkBox.setChecked(!checkBox.isChecked());
            if (checkBox.isChecked()) {
                feedIds.add(feed.feedId);
            } else {
                feedIds.remove(feed.feedId);
            }
            setWidgetFeedIds();
        });
        return childView;
    }

    private void setWidgetFeedIds() {
        prefRepository.setWidgetFeedIds(feedIds);
    }
}
