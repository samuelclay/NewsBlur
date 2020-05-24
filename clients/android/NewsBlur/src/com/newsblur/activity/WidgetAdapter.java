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

public class WidgetAdapter extends BaseExpandableListAdapter {

    private final static int defaultTextSizeChild = 14;
    private final static int defaultTextSizeGroup = 13;

    private Set<String> feedIds = new HashSet<>();
    private ArrayList<String> folderNames = new ArrayList<>();
    private ArrayList<ArrayList<Feed>> folderChildren = new ArrayList<>();

    private FolderViewFilter folderViewFilter;
    private ListOrderFilter listOrderFilter;
    private FeedOrderFilter feedOrderFilter;

    private float textSize;

    WidgetAdapter(Context context) {
        folderViewFilter = PrefsUtils.getWidgetConfigFolderView(context);
        listOrderFilter = PrefsUtils.getWidgetConfigListOrder(context);
        feedOrderFilter = PrefsUtils.getWidgetConfigFeedOrder(context);
        textSize = PrefsUtils.getListTextSize(context);
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

        convertView.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                ArrayList<Feed> folderChild = WidgetAdapter.this.folderChildren.get(groupPosition);
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
                setWidgetFeedIds(parent.getContext());
                notifyDataChanged();
            }
        });
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
                DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
                dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
                Date dateTime = dateFormat.parse(feed.lastStoryDate);
                CharSequence relativeTimeString = DateUtils.getRelativeTimeSpanString(dateTime.getTime(), System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS);
                textDetails.setText(relativeTimeString);
            } catch (Exception e) {
                textDetails.setText(feed.lastStoryDate);
            }
        }

        FeedUtils.iconLoader.displayImage(feed.faviconUrl, img, 0, false, img.getHeight(), true);

        convertView.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                checkBox.setChecked(!checkBox.isChecked());
                if (checkBox.isChecked()) {
                    feedIds.add(feed.feedId);
                } else {
                    feedIds.remove(feed.feedId);
                }
                setWidgetFeedIds(parent.getContext());
            }
        });
        return convertView;
    }

    @Override
    public boolean isChildSelectable(int groupPosition, int childPosition) {
        return true;
    }

    @Override
    public boolean areAllItemsEnabled() {
        return super.areAllItemsEnabled();
    }

    void setData(ArrayList<String> activeFoldersNames, ArrayList<ArrayList<Feed>> activeFolderChildren, ArrayList<Feed> feeds) {
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

    void replaceFeedOrder(FeedOrderFilter feedOrderFilter) {
        this.feedOrderFilter = feedOrderFilter;
        notifyDataChanged();
    }

    void replaceListOrder(ListOrderFilter listOrderFilter) {
        this.listOrderFilter = listOrderFilter;
        notifyDataChanged();
    }

    void replaceFolderView(FolderViewFilter folderViewFilter) {
        this.folderViewFilter = folderViewFilter;
    }

    private void notifyDataChanged() {
        for (ArrayList<Feed> feedList : this.folderChildren) {
            Collections.sort(feedList, getListComparator());
        }
        this.notifyDataSetChanged();
    }

    void setFeedIds(Set<String> feedIds) {
        this.feedIds.clear();
        this.feedIds.addAll(feedIds);
        this.notifyDataSetChanged();
    }

    private void setWidgetFeedIds(Context context) {
        PrefsUtils.setWidgetFeedIds(context, feedIds);
    }

    private Comparator<Feed> getListComparator() {
        return new Comparator<Feed>() {
            @Override
            public int compare(Feed o1, Feed o2) {
                if (feedOrderFilter == FeedOrderFilter.NAME && listOrderFilter == ListOrderFilter.ASCENDING) {
                    return o1.title.compareTo(o2.title);
                } else if (feedOrderFilter == FeedOrderFilter.NAME && listOrderFilter == ListOrderFilter.DESCENDING) {
                    return o2.title.compareTo(o1.title);
                } else if (feedOrderFilter == FeedOrderFilter.SUBSCRIBERS && listOrderFilter == ListOrderFilter.ASCENDING) {
                    return Integer.valueOf(o1.subscribers).compareTo(Integer.valueOf(o2.subscribers));
                } else if (feedOrderFilter == FeedOrderFilter.SUBSCRIBERS && listOrderFilter == ListOrderFilter.DESCENDING) {
                    return Integer.valueOf(o2.subscribers).compareTo(Integer.valueOf(o1.subscribers));
                } else if (feedOrderFilter == FeedOrderFilter.OPENS && listOrderFilter == ListOrderFilter.ASCENDING) {
                    return Integer.compare(o1.feedOpens, o2.feedOpens);
                } else if (feedOrderFilter == FeedOrderFilter.OPENS && listOrderFilter == ListOrderFilter.DESCENDING) {
                    return Integer.compare(o2.feedOpens, o1.feedOpens);
                } else if (feedOrderFilter == FeedOrderFilter.RECENT_STORY && listOrderFilter == ListOrderFilter.ASCENDING) {
                    return compareLastStoryDateTimes(o1.lastStoryDate, o2.lastStoryDate, listOrderFilter);
                } else if (feedOrderFilter == FeedOrderFilter.RECENT_STORY && listOrderFilter == ListOrderFilter.DESCENDING) {
                    return compareLastStoryDateTimes(o1.lastStoryDate, o2.lastStoryDate, listOrderFilter);
                } else if (feedOrderFilter == FeedOrderFilter.STORIES_MONTH && listOrderFilter == ListOrderFilter.ASCENDING) {
                    return Integer.compare(o1.storiesPerMonth, o2.storiesPerMonth);
                } else if (feedOrderFilter == FeedOrderFilter.STORIES_MONTH && listOrderFilter == ListOrderFilter.DESCENDING) {
                    return Integer.compare(o2.storiesPerMonth, o1.storiesPerMonth);
                }
                return o1.title.compareTo(o2.title);
            }
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
