package com.newsblur.fragment;

import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.app.DialogFragment;
import android.content.DialogInterface;
import android.os.Bundle;
import android.text.InputType;
import android.text.Selection;
import android.text.Spannable;
import android.text.Spanned;
import android.text.SpanWatcher;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.View.OnKeyListener;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ListAdapter;
import android.widget.ListView;
import android.widget.TextView;

import butterknife.ButterKnife;
import butterknife.Bind;

import com.newsblur.R;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.view.SelectOnlyEditText;

public class StoryIntelTrainerFragment extends DialogFragment {

    private Story story;
    private Classifier classifier;

    @Bind(R.id.intel_title_selection) SelectOnlyEditText titleSelection;
    @Bind(R.id.existing_title_intel_container) LinearLayout titleRowsContainer;
    @Bind(R.id.existing_tag_intel_container) LinearLayout tagRowsContainer;

    public static StoryIntelTrainerFragment newInstance(Story story) {
        StoryIntelTrainerFragment fragment = new StoryIntelTrainerFragment();
        Bundle args = new Bundle();
        args.putSerializable("story", story);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        story = (Story) getArguments().getSerializable("story");
        classifier = FeedUtils.dbHelper.getClassifierForFeed(story.feedId);

        // author classifier
        // tag classifiers
        // scrollview for whole set

        final Activity activity = getActivity();
        LayoutInflater inflater = LayoutInflater.from(activity);
        View v = inflater.inflate(R.layout.dialog_trainstory, null);
        ButterKnife.bind(this, v);

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

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        //builder.setTitle(String.format(getResources().getString(R.string.title_train_story), feed.title));
        builder.setView(v);

        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                StoryIntelTrainerFragment.this.dismiss();
            }
        });
        builder.setPositiveButton(R.string.dialog_folders_save, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                //FeedUtils.moveFeedToFolders(activity, feed.feedId, newFolders, oldFolders);
                StoryIntelTrainerFragment.this.dismiss();
            }
        });

        titleSelection.setText(story.title);
        // the layout sets inputType="none" on this EditText, but a widespread platform bug requires us
        // to also set this programmatically to make the field read-only for selection.
        titleSelection.setInputType(InputType.TYPE_NULL);
        // the user is selecting for our custom widget, not to copy/paste
        titleSelection.disableActionMenu();
        // pre-select the whole title to make it easier for the user to manipulate the selection handles
        //titleSelection.setSelectAllOnFocus(true);
        titleSelection.selectAll();
        //titleSelection.requestFocus();
        // do this after init and selection to prevent toast spam
        titleSelection.setForceSelection(true);

        /*
        ListAdapter adapter = new ArrayAdapter<Folder>(getActivity(), R.layout.row_choosefolders, R.id.choosefolders_foldername, folders) {
            @Override
            public View getView(final int position, View convertView, ViewGroup parent) {
                View v = super.getView(position, convertView, parent);
                CheckBox row = (CheckBox) v.findViewById(R.id.choosefolders_foldername);
                if (position == 0) {
                    row.setText(R.string.top_level);
                }
                row.setChecked(folders.get(position).feedIds.contains(feed.feedId));
                row.setOnClickListener(new OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        CheckBox row = (CheckBox) v;
                        if (row.isChecked()) {
                            folders.get(position).feedIds.add(feed.feedId);
                            newFolders.add(folders.get(position).name);
                        } else {
                            folders.get(position).feedIds.remove(feed.feedId);
                            newFolders.remove(folders.get(position).name);
                        }
                    }
                });
                return v;
            }
        };
        listView.setAdapter(adapter);
        */

        Dialog dialog = builder.create();
        dialog.getWindow().getAttributes().gravity = Gravity.BOTTOM;
        return dialog;
    }

}

