package com.newsblur.fragment;

import java.util.List;
import java.util.Map;

import android.app.Activity;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;

import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.databinding.DialogTrainfeedBinding;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class FeedIntelTrainerFragment extends DialogFragment {

    @Inject
    FeedUtils feedUtils;

    @Inject
    BlurDatabaseHelper dbHelper;

    private Feed feed;
    private FeedSet fs;
    private Classifier classifier;
    private DialogTrainfeedBinding binding;

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
        classifier = dbHelper.getClassifierForFeed(feed.feedId);

        final Activity activity = getActivity();
        LayoutInflater inflater = LayoutInflater.from(activity);
        View v = inflater.inflate(R.layout.dialog_trainfeed, null);
        binding = DialogTrainfeedBinding.bind(v);

        // display known title classifiers
        for (Map.Entry<String, Integer> rule : classifier.title.entrySet()) {
                View row = inflater.inflate(R.layout.include_intel_row, null);
                TextView label = (TextView) row.findViewById(R.id.intel_row_label);
                label.setText(rule.getKey());
                UIUtils.setupIntelDialogRow(row, classifier.title, rule.getKey());
                binding.existingTitleIntelContainer.addView(row);
        }
        if (classifier.title.size() < 1) binding.intelTitleHeader.setVisibility(View.GONE);
        
        // get the list of suggested tags
        List<String> allTags = dbHelper.getTagsForFeed(feed.feedId);
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
            binding.existingTagIntelContainer.addView(row);
        }
        if (allTags.size() < 1) binding.intelTagHeader.setVisibility(View.GONE);

        // get the list of suggested authors
        List<String> allAuthors = dbHelper.getAuthorsForFeed(feed.feedId);
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
            binding.existingAuthorIntelContainer.addView(rowAuthor);
        }
        if (allAuthors.size() < 1) binding.intelAuthorHeader.setVisibility(View.GONE);

        // for feel-level intel, the label is the title and the intel identifier is the feed ID
        View rowFeed = inflater.inflate(R.layout.include_intel_row, null);
        TextView labelFeed = (TextView) rowFeed.findViewById(R.id.intel_row_label);
        labelFeed.setText(feed.title);
        UIUtils.setupIntelDialogRow(rowFeed, classifier.feeds, feed.feedId);
        binding.existingFeedIntelContainer.addView(rowFeed);

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
                feedUtils.updateClassifier(feed.feedId, classifier, fs, activity);
                FeedIntelTrainerFragment.this.dismiss();
            }
        });

        Dialog dialog = builder.create();
        dialog.getWindow().getAttributes().gravity = Gravity.BOTTOM;
        return dialog;
    }

}

