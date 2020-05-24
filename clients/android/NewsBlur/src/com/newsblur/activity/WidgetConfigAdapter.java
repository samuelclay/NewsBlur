package com.newsblur.activity;

import android.content.Context;
import android.support.annotation.NonNull;
import android.support.v7.util.DiffUtil;
import android.support.v7.widget.RecyclerView;
import android.text.format.DateUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.CheckBox;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.util.FeedOrderFilter;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.Set;
import java.util.TimeZone;

import butterknife.Bind;
import butterknife.ButterKnife;

public class WidgetConfigAdapter extends RecyclerView.Adapter<WidgetConfigAdapter.ViewHolder> {

    private ArrayList<Feed> feedList = new ArrayList<>();
    private Set<String> feedIds = new HashSet<>();
    private FeedOrderFilter feedOrderFilter = FeedOrderFilter.NAME;

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.row_widget_config_feed, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull final ViewHolder holder, int position) {
        final Feed feed = feedList.get(position);

        holder.checkBox.setChecked(feedIds.contains(feed.feedId));
        holder.textTitle.setText(feed.title);
        if (feedOrderFilter == FeedOrderFilter.NAME || feedOrderFilter == FeedOrderFilter.OPENS) {
            holder.textDetails.setText(holder.itemView.getContext().getString(R.string.feed_opens, feed.feedOpens));
        } else if (feedOrderFilter == FeedOrderFilter.SUBSCRIBERS) {
            holder.textDetails.setText(holder.itemView.getContext().getString(R.string.feed_subscribers, feed.subscribers));
        } else if (feedOrderFilter == FeedOrderFilter.STORIES_MONTH) {
            holder.textDetails.setText(holder.itemView.getContext().getString(R.string.feed_stories_per_month, feed.storiesPerMonth));
        } else {
            // FeedOrderFilter.RECENT_STORY
            try {
                DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
                dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
                Date dateTime = dateFormat.parse(feed.lastStoryDate);
                CharSequence relativeTimeString = DateUtils.getRelativeTimeSpanString(dateTime.getTime(), System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS);
                holder.textDetails.setText(relativeTimeString);
            } catch (Exception e) {
                holder.textDetails.setText(feed.lastStoryDate);
            }
        }

        FeedUtils.iconLoader.displayImage(feed.faviconUrl, holder.img, 0, false);

        holder.itemView.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                holder.checkBox.setChecked(!holder.checkBox.isChecked());
                if (holder.checkBox.isChecked()) {
                    feedIds.add(feed.feedId);
                } else {
                    feedIds.remove(feed.feedId);
                }
                setWidgetFeedIds(holder.itemView.getContext());
            }
        });
    }

    @Override
    public int getItemCount() {
        return feedList.size();
    }

    void diffAll(ArrayList<Feed> feedList, FeedOrderFilter feedOrderFilter) {
        boolean hasSameFilter = this.feedOrderFilter == feedOrderFilter;
        DiffUtil.Callback diffCallback = new WidgetListDiffCallback(this.feedList, feedList, hasSameFilter);
        DiffUtil.DiffResult diffResult = DiffUtil.calculateDiff(diffCallback);
        this.feedList.clear();
        this.feedList.addAll(feedList);
        this.feedOrderFilter = feedOrderFilter;
        diffResult.dispatchUpdatesTo(this);
    }

    void replaceAll(Context context, ArrayList<Feed> feedList, Set<String> feedIds) {
        this.feedOrderFilter = PrefsUtils.getWidgetConfigFeedOrder(context);
        this.feedIds.clear();
        this.feedIds.addAll(feedIds);
        this.feedList.clear();
        this.feedList.addAll(feedList);
        this.notifyDataSetChanged();
    }

    private void setWidgetFeedIds(Context context) {
        PrefsUtils.setWidgetFeedIds(context, feedIds);
    }

    static class ViewHolder extends RecyclerView.ViewHolder {

        @Bind(R.id.text_title)
        TextView textTitle;
        @Bind(R.id.text_details)
        TextView textDetails;
        @Bind(R.id.check_box)
        CheckBox checkBox;
        @Bind(R.id.img)
        ImageView img;

        ViewHolder(View itemView) {
            super(itemView);
            ButterKnife.bind(this, itemView);
        }
    }

    static class WidgetListDiffCallback extends DiffUtil.Callback {

        private ArrayList<Feed> oldList;
        private ArrayList<Feed> newList;
        private boolean hasSameFilter;

        WidgetListDiffCallback(ArrayList<Feed> oldList, ArrayList<Feed> newList, boolean hasSameFilter) {
            this.oldList = oldList;
            this.newList = newList;
            this.hasSameFilter = hasSameFilter;
        }

        @Override
        public int getOldListSize() {
            return oldList.size();
        }

        @Override
        public int getNewListSize() {
            return newList.size();
        }

        @Override
        public boolean areItemsTheSame(int oldItemPosition, int newItemPosition) {
            return oldList.get(oldItemPosition) == newList.get(newItemPosition);
        }

        @Override
        public boolean areContentsTheSame(int oldItemPosition, int newItemPosition) {
            if (hasSameFilter) {
                Feed oldFeed = oldList.get(oldItemPosition);
                Feed newFeed = newList.get(newItemPosition);
                return oldFeed.feedId.equals(newFeed.feedId) && oldFeed.title.equals(newFeed.title);
            } else return false;
        }
    }
}
