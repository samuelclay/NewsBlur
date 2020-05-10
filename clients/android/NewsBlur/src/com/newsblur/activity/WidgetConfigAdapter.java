package com.newsblur.activity;

import android.content.Context;
import android.support.annotation.NonNull;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.CheckBox;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.widget.WidgetUtils;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

import butterknife.Bind;
import butterknife.ButterKnife;

public class WidgetConfigAdapter extends RecyclerView.Adapter<WidgetConfigAdapter.ViewHolder> {

    private ArrayList<Feed> feedList = new ArrayList<>();
    private Set<String> feedIds = new HashSet<>();

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
        holder.textDetails.setText(String.format(holder.itemView.getContext().getString(R.string.total_subscribers), feed.subscribers));

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

    void replaceAll(ArrayList<Feed> feeds, Set<String> feedIds) {
        this.feedList.clear();
        this.feedIds.clear();
        this.feedList.addAll(feeds);
        this.feedIds.addAll(feedIds);
        this.notifyDataSetChanged();
    }

    private void setWidgetFeedIds(Context context) {
        PrefsUtils.setWidgetFeedIds(context, feedIds);
        WidgetUtils.notifyViewDataChanged(context);
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
}
