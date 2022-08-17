package com.newsblur.activity;

import android.content.Context;
import android.text.TextUtils;
import android.text.format.DateUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseExpandableListAdapter;
import android.widget.CheckBox;
import android.widget.ExpandableListView;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedOrderFilter;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.FolderViewFilter;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.ListOrderFilter;
import com.newsblur.util.PrefsUtils;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.TimeZone;

public class FeedChooserAdapter extends BaseExpandableListAdapter {

    protected final static int defaultTextSizeChild = 14;
    protected final static int defaultTextSizeGroup = 13;

    protected Set<String> feedIds = new HashSet<>();
    protected ArrayList<String> folderNames = new ArrayList<>();
    protected ArrayList<ArrayList<Feed>> folderChildren = new ArrayList<>();

    protected FolderViewFilter folderViewFilter;
    protected ListOrderFilter listOrderFilter;
    protected FeedOrderFilter feedOrderFilter;
    protected final FeedUtils feedUtils;
    protected final ImageLoader iconLoader;

    protected float textSize;

    FeedChooserAdapter(Context context, FeedUtils feedUtils, ImageLoader iconLoader) {
        folderViewFilter = PrefsUtils.getFeedChooserFolderView(context);
        listOrderFilter = PrefsUtils.getFeedChooserListOrder(context);
        feedOrderFilter = PrefsUtils.getFeedChooserFeedOrder(context);
        textSize = PrefsUtils.getListTextSize(context);
        this.feedUtils = feedUtils;
        this.iconLoader = iconLoader;
    }

    @Override
    public int getGroupCount() {
        return folderNames.size();
    }

    @Override
    public int getChildrenCount(int groupPosition) {
        return folderChildren.get(groupPosition).size();
    }

    @Override
    public String getGroup(int groupPosition) {
        return folderNames.get(groupPosition);
    }

    @Override
    public Feed getChild(int groupPosition, int childPosition) {
        return folderChildren.get(groupPosition).get(childPosition);
    }

    @Override
    public long getGroupId(int groupPosition) {
        return folderNames.get(groupPosition).hashCode();
    }

    @Override
    public long getChildId(int groupPosition, int childPosition) {
        return folderChildren.get(groupPosition).get(childPosition).hashCode();
    }

    @Override
    public boolean hasStableIds() {
        return true;
    }

    @Override
    public View getGroupView(final int groupPosition, boolean isExpanded, View convertView, final ViewGroup parent) {
        String folderName = folderNames.get(groupPosition);
        if (folderName.equals(AppConstants.ROOT_FOLDER)) {
            convertView = LayoutInflater.from(parent.getContext()).inflate(R.layout.row_widget_config_root_folder, parent, false);
        } else {
            convertView = LayoutInflater.from(parent.getContext()).inflate(R.layout.row_widget_config_folder, parent, false);
            TextView textName = convertView.findViewById(R.id.text_folder_name);
            textName.setTextSize(textSize * defaultTextSizeGroup);
            textName.setText(folderName);
        }

        ((ExpandableListView) parent).expandGroup(groupPosition);
        return convertView;
    }

    @Override
    public View getChildView(int groupPosition, int childPosition, boolean isLastChild, View convertView, final ViewGroup parent) {
        if (convertView == null) {
            convertView = LayoutInflater.from(parent.getContext()).inflate(R.layout.row_widget_config_feed, parent, false);
        }

        final Feed feed = folderChildren.get(groupPosition).get(childPosition);
        TextView textTitle = convertView.findViewById(R.id.text_title);
        TextView textDetails = convertView.findViewById(R.id.text_details);
        final CheckBox checkBox = convertView.findViewById(R.id.check_box);
        ImageView img = convertView.findViewById(R.id.img);
        textTitle.setTextSize(textSize * defaultTextSizeChild);
        textDetails.setTextSize(textSize * defaultTextSizeChild);
        textTitle.setText(feed.title);
        checkBox.setChecked(feedIds.contains(feed.feedId));

        if (feedOrderFilter == FeedOrderFilter.NAME || feedOrderFilter == FeedOrderFilter.OPENS) {
            textDetails.setText(parent.getContext().getString(R.string.feed_opens, feed.feedOpens));
        } else if (feedOrderFilter == FeedOrderFilter.SUBSCRIBERS) {
            textDetails.setText(parent.getContext().getString(R.string.feed_subscribers, feed.subscribers));
        } else if (feedOrderFilter == FeedOrderFilter.STORIES_MONTH) {
            textDetails.setText(parent.getContext().getString(R.string.feed_stories_per_month, feed.storiesPerMonth));
        } else {
            // FeedOrderFilter.RECENT_STORY
            try {
                DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
                dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
                Date dateTime = dateFormat.parse(feed.lastStoryDate);
                CharSequence relativeTimeString = DateUtils.getRelativeTimeSpanString(dateTime.getTime(), System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS);
                textDetails.setText(relativeTimeString);
            } catch (Exception e) {
                textDetails.setText(feed.lastStoryDate);
            }
        }

        iconLoader.displayImage(feed.faviconUrl, img, img.getHeight(), true);
        return convertView;
    }

    @Override
    public boolean isChildSelectable(int groupPosition, int childPosition) {
        return true;
    }

    protected void setData(ArrayList<String> activeFoldersNames, ArrayList<ArrayList<Feed>> activeFolderChildren, ArrayList<Feed> feeds) {
        if (folderViewFilter == FolderViewFilter.NESTED) {
            this.folderNames = activeFoldersNames;
            this.folderChildren = activeFolderChildren;
        } else {
            this.folderNames = new ArrayList<>(1);
            this.folderNames.add(AppConstants.ROOT_FOLDER);
            this.folderChildren = new ArrayList<>();
            this.folderChildren.add(feeds);
        }
        this.notifyDataChanged();
    }

    protected void replaceFeedOrder(FeedOrderFilter feedOrderFilter) {
        this.feedOrderFilter = feedOrderFilter;
        notifyDataChanged();
    }

    protected void replaceListOrder(ListOrderFilter listOrderFilter) {
        this.listOrderFilter = listOrderFilter;
        notifyDataChanged();
    }

    protected void replaceFolderView(FolderViewFilter folderViewFilter) {
        this.folderViewFilter = folderViewFilter;
    }

    protected void notifyDataChanged() {
        for (ArrayList<Feed> feedList : this.folderChildren) {
            Collections.sort(feedList, getListComparator());
        }
        this.notifyDataSetChanged();
    }

    protected void setFeedIds(Set<String> feedIds) {
        this.feedIds.clear();
        this.feedIds.addAll(feedIds);
    }

    protected void replaceFeedIds(Set<String> feedIds) {
        setFeedIds(feedIds);
        this.notifyDataSetChanged();
    }

    private Comparator<Feed> getListComparator() {
        return (o1, o2) -> {
            // some feeds have missing data
            if (o1.title == null) o1.title = "";
            if (o2.title == null) o2.title = "";
            if (feedOrderFilter == FeedOrderFilter.NAME && listOrderFilter == ListOrderFilter.ASCENDING) {
                return o1.title.compareTo(o2.title);
            } else if (feedOrderFilter == FeedOrderFilter.NAME && listOrderFilter == ListOrderFilter.DESCENDING) {
                return o2.title.compareTo(o1.title);
            } else if (o1.subscribers != null && o2.subscribers != null &&
                    feedOrderFilter == FeedOrderFilter.SUBSCRIBERS &&
                    listOrderFilter == ListOrderFilter.ASCENDING) {
                return Integer.valueOf(o1.subscribers).compareTo(Integer.valueOf(o2.subscribers));
            } else if (o1.subscribers != null && o2.subscribers != null &&
                    feedOrderFilter == FeedOrderFilter.SUBSCRIBERS &&
                    listOrderFilter == ListOrderFilter.DESCENDING) {
                return Integer.valueOf(o2.subscribers).compareTo(Integer.valueOf(o1.subscribers));
            } else if (feedOrderFilter == FeedOrderFilter.OPENS && listOrderFilter == ListOrderFilter.ASCENDING) {
                return Integer.compare(o1.feedOpens, o2.feedOpens);
            } else if (feedOrderFilter == FeedOrderFilter.OPENS && listOrderFilter == ListOrderFilter.DESCENDING) {
                return Integer.compare(o2.feedOpens, o1.feedOpens);
            } else if (o1.lastStoryDate != null && o2.lastStoryDate != null &&
                    feedOrderFilter == FeedOrderFilter.RECENT_STORY &&
                    listOrderFilter == ListOrderFilter.ASCENDING) {
                return compareLastStoryDateTimes(o1.lastStoryDate, o2.lastStoryDate, listOrderFilter);
            } else if (o1.lastStoryDate != null && o2.lastStoryDate != null &&
                    feedOrderFilter == FeedOrderFilter.RECENT_STORY &&
                    listOrderFilter == ListOrderFilter.DESCENDING) {
                return compareLastStoryDateTimes(o1.lastStoryDate, o2.lastStoryDate, listOrderFilter);
            } else if (feedOrderFilter == FeedOrderFilter.STORIES_MONTH && listOrderFilter == ListOrderFilter.ASCENDING) {
                return Integer.compare(o1.storiesPerMonth, o2.storiesPerMonth);
            } else if (feedOrderFilter == FeedOrderFilter.STORIES_MONTH && listOrderFilter == ListOrderFilter.DESCENDING) {
                return Integer.compare(o2.storiesPerMonth, o1.storiesPerMonth);
            }
            return o1.title.compareTo(o2.title);
        };
    }

    private int compareLastStoryDateTimes(String firstDateTime, String secondDateTime, ListOrderFilter listOrderFilter) {
        try {
            DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
            // found null last story date times on feeds
            if (TextUtils.isEmpty(firstDateTime)) {
                firstDateTime = "2000-01-01 00:00:00";
            }
            if (TextUtils.isEmpty(secondDateTime)) {
                secondDateTime = "2000-01-01 00:00:00";
            }

            Date firstDate = dateFormat.parse(firstDateTime);
            Date secondDate = dateFormat.parse(secondDateTime);
            if (listOrderFilter == ListOrderFilter.ASCENDING) {
                return firstDate.compareTo(secondDate);
            } else {
                return secondDate.compareTo(firstDate);
            }
        } catch (ParseException e) {
            e.printStackTrace();
            return 0;
        }
    }
}