package com.newsblur.fragment;

import java.util.List;
import java.util.Map;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.app.DialogFragment;
import android.content.DialogInterface;
import android.os.Bundle;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

import butterknife.ButterKnife;
import butterknife.Bind;

import com.newsblur.R;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;

public class FeedIntelTrainerFragment extends DialogFragment {

    private Feed feed;
    private FeedSet fs;
    private Classifier classifier;

    @Bind(R.id.intel_title_header) TextView headerTitles;
    @Bind(R.id.intel_tag_header) TextView headerTags;
    @Bind(R.id.intel_author_header) TextView headerAuthor;
    @Bind(R.id.existing_title_intel_container) LinearLayout titleRowsContainer;
    @Bind(R.id.existing_tag_intel_container) LinearLayout tagRowsContainer;
    @Bind(R.id.existing_author_intel_container) LinearLayout authorRowsContainer;
    @Bind(R.id.existing_feed_intel_container) LinearLayout feedRowsContainer;

    public static FeedIntelTrainerFragment newInstance(Feed feed, FeedSet fs) {
        FeedIntelTrainerFragment fragment = new FeedIntelTrainerFragment();
        Bundle args = new Bundle();
        args.putSerializable("feed", feed);
        args.putSerializable("feedset", fs);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        feed = (Feed) getArguments().getSerializable("feed");
        fs = (FeedSet) getArguments().getSerializable("feedset");
        classifier = FeedUtils.dbHelper.getClassifierForFeed(feed.feedId);

        final Activity activity = getActivity();
        LayoutInflater inflater = LayoutInflater.from(activity);
        View v = inflater.inflate(R.layout.dialog_trainfeed, null);
        ButterKnife.bind(this, v);

        // display known title classifiers
        for (Map.Entry<String, Integer> rule : classifier.title.entrySet()) {
                View row = inflater.inflate(R.layout.include_intel_row, null);
                TextView label = (TextView) row.findViewById(R.id.intel_row_label);
                label.setText(rule.getKey());
                UIUtils.setupIntelDialogRow(row, classifier.title, rule.getKey());
                titleRowsContainer.addView(row);
        }
        if (classifier.title.size() < 1) headerTitles.setVisibility(View.GONE);
        
        // get the list of suggested tags
        List<String> allTags = FeedUtils.dbHelper.getTagsForFeed(feed.feedId);
        // augment that list with known trained tags
        for (Map.Entry<String, Integer> rule : classifier.tags.entrySet()) {
            if (!allTags.contains(rule.getKey())) {
                allTags.add(rule.getKey());
            }
        }
        for (String tag : allTags) {
            View row = inflater.inflate(R.layout.include_intel_row, null);
            TextView label = (TextView) row.findViewById(R.id.intel_row_label);
            label.setText(tag);
            UIUtils.setupIntelDialogRow(row, classifier.tags, tag);
            tagRowsContainer.addView(row);
        }
        if (allTags.size() < 1) headerTags.setVisibility(View.GONE);

        // get the list of suggested authors
        List<String> allAuthors = FeedUtils.dbHelper.getAuthorsForFeed(feed.feedId);
        // augment that list with known trained authors
        for (Map.Entry<String, Integer> rule : classifier.authors.entrySet()) {
            if (!allAuthors.contains(rule.getKey())) {
                allAuthors.add(rule.getKey());
            }
        }
        for (String author : allAuthors) {
            View rowAuthor = inflater.inflate(R.layout.include_intel_row, null);
            TextView labelAuthor = (TextView) rowAuthor.findViewById(R.id.intel_row_label);
            labelAuthor.setText(author);
            UIUtils.setupIntelDialogRow(rowAuthor, classifier.authors, author);
            authorRowsContainer.addView(rowAuthor);
        }
        if (allAuthors.size() < 1) headerAuthor.setVisibility(View.GONE);

        // for feel-level intel, the label is the title and the intel identifier is the feed ID
        View rowFeed = inflater.inflate(R.layout.include_intel_row, null);
        TextView labelFeed = (TextView) rowFeed.findViewById(R.id.intel_row_label);
        labelFeed.setText(feed.title);
        UIUtils.setupIntelDialogRow(rowFeed, classifier.feeds, feed.feedId);
        feedRowsContainer.addView(rowFeed);

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle(R.string.feed_intel_dialog_title);
        builder.setView(v);

        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                FeedIntelTrainerFragment.this.dismiss();
            }
        });
        builder.setPositiveButton(R.string.dialog_story_intel_save, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                FeedUtils.updateClassifier(feed.feedId, classifier, fs, activity);
                FeedIntelTrainerFragment.this.dismiss();
            }
        });

        Dialog dialog = builder.create();
        dialog.getWindow().getAttributes().gravity = Gravity.BOTTOM;
        return dialog;
    }

}

