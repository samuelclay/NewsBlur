package com.newsblur.fragment;

import java.util.Map;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.text.InputType;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import butterknife.ButterKnife;
import butterknife.Bind;

import com.newsblur.R;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.view.SelectOnlyEditText;

public class StoryIntelTrainerFragment extends DialogFragment {

    private Story story;
    private FeedSet fs;
    private Classifier classifier;
    private Integer newTitleTraining;

    @Bind(R.id.intel_tag_header) TextView headerTags;
    @Bind(R.id.intel_author_header) TextView headerAuthor;
    @Bind(R.id.intel_title_selection) SelectOnlyEditText titleSelection;
    @Bind(R.id.intel_title_like) Button titleLikeButton;
    @Bind(R.id.intel_title_dislike) Button titleDislikeButton;
    @Bind(R.id.intel_title_clear) Button titleClearButton;
    @Bind(R.id.existing_title_intel_container) LinearLayout titleRowsContainer;
    @Bind(R.id.existing_tag_intel_container) LinearLayout tagRowsContainer;
    @Bind(R.id.existing_author_intel_container) LinearLayout authorRowsContainer;
    @Bind(R.id.existing_feed_intel_container) LinearLayout feedRowsContainer;

    public static StoryIntelTrainerFragment newInstance(Story story, FeedSet fs) {
        if (story.feedId.equals("0")) {
            throw new IllegalArgumentException("cannot intel train stories with a null/zero feed");
        }
        StoryIntelTrainerFragment fragment = new StoryIntelTrainerFragment();
        Bundle args = new Bundle();
        args.putSerializable("story", story);
        args.putSerializable("feedset", fs);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        story = (Story) getArguments().getSerializable("story");
        fs = (FeedSet) getArguments().getSerializable("feedset");
        classifier = FeedUtils.dbHelper.getClassifierForFeed(story.feedId);

        final Activity activity = getActivity();
        LayoutInflater inflater = LayoutInflater.from(activity);
        View v = inflater.inflate(R.layout.dialog_trainstory, null);
        ButterKnife.bind(this, v);

        // set up the special title training box for the title from this story and the associated buttons
        titleSelection.setText(story.title);
        // the layout sets inputType="none" on this EditText, but a widespread platform bug requires us
        // to also set this programmatically to make the field read-only for selection.
        titleSelection.setInputType(InputType.TYPE_NULL);
        // the user is selecting for our custom widget, not to copy/paste
        titleSelection.disableActionMenu();
        // pre-select the whole title to make it easier for the user to manipulate the selection handles
        titleSelection.selectAll();
        // do this after init and selection to prevent toast spam
        titleSelection.setForceSelection(true);
        // the disposition buttons for a new title training don't immediately impact the classifier object,
        // lest the user want to change selection substring after choosing the disposition.  so just store
        // the training factor in a variable that can be pulled on completion
        titleLikeButton.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                newTitleTraining = Classifier.LIKE;
                titleLikeButton.setBackgroundResource(R.drawable.ic_like_active);
                titleDislikeButton.setBackgroundResource(R.drawable.ic_dislike_gray55);
            }
        });
        titleDislikeButton.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                newTitleTraining = Classifier.DISLIKE;
                titleLikeButton.setBackgroundResource(R.drawable.ic_like_gray55);
                titleDislikeButton.setBackgroundResource(R.drawable.ic_dislike_active);
            }
        });
        titleClearButton.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                newTitleTraining = null;
                titleLikeButton.setBackgroundResource(R.drawable.ic_like_gray55);
                titleDislikeButton.setBackgroundResource(R.drawable.ic_dislike_gray55);
            }
        });

        // scan trained title fragments for this feed and see if any apply to this story
        for (Map.Entry<String, Integer> rule : classifier.title.entrySet()) {
            if (story.title.indexOf(rule.getKey()) >= 0) {
                View row = inflater.inflate(R.layout.include_intel_row, null);
                TextView label = (TextView) row.findViewById(R.id.intel_row_label);
                label.setText(rule.getKey());
                UIUtils.setupIntelDialogRow(row, classifier.title, rule.getKey());
                titleRowsContainer.addView(row);
            }
        }
        
        // list all tags for this story, trained or not
        for (String tag : story.tags) {
            View row = inflater.inflate(R.layout.include_intel_row, null);
            TextView label = (TextView) row.findViewById(R.id.intel_row_label);
            label.setText(tag);
            UIUtils.setupIntelDialogRow(row, classifier.tags, tag);
            tagRowsContainer.addView(row);
        }
        if (story.tags.length < 1) headerTags.setVisibility(View.GONE);

        // there is a single author per story
        if (!TextUtils.isEmpty(story.authors)) {
            View rowAuthor = inflater.inflate(R.layout.include_intel_row, null);
            TextView labelAuthor = (TextView) rowAuthor.findViewById(R.id.intel_row_label);
            labelAuthor.setText(story.authors);
            UIUtils.setupIntelDialogRow(rowAuthor, classifier.authors, story.authors);
            authorRowsContainer.addView(rowAuthor);
        } else {
            headerAuthor.setVisibility(View.GONE);
        }

        // there is a single feed to be trained, but it is a bit odd in that the label is the title and
        // the intel identifier is the feed ID
        View rowFeed = inflater.inflate(R.layout.include_intel_row, null);
        TextView labelFeed = (TextView) rowFeed.findViewById(R.id.intel_row_label);
        labelFeed.setText(FeedUtils.getFeedTitle(story.feedId));
        UIUtils.setupIntelDialogRow(rowFeed, classifier.feeds, story.feedId);
        feedRowsContainer.addView(rowFeed);

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle(R.string.story_intel_dialog_title);
        builder.setView(v);

        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                StoryIntelTrainerFragment.this.dismiss();
            }
        });
        builder.setPositiveButton(R.string.dialog_story_intel_save, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                if ((newTitleTraining != null) && (!TextUtils.isEmpty(titleSelection.getSelection()))) {
                    classifier.title.put(titleSelection.getSelection(), newTitleTraining);
                }
                FeedUtils.updateClassifier(story.feedId, classifier, fs, activity);
                StoryIntelTrainerFragment.this.dismiss();
            }
        });

        Dialog dialog = builder.create();
        dialog.getWindow().getAttributes().gravity = Gravity.BOTTOM;
        return dialog;
    }

}

