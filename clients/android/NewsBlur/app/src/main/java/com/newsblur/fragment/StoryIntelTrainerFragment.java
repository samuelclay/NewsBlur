package com.newsblur.fragment;

import android.app.Dialog;
import android.os.Bundle;
import android.text.InputType;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import androidx.lifecycle.ViewModelProvider;

import com.newsblur.R;
import com.newsblur.databinding.DialogTrainstoryBinding;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.viewModel.StoryIntelTrainerViewModel;
import com.newsblur.viewModel.StoryIntelUiState;

import org.jetbrains.annotations.Nullable;

import java.util.Locale;
import java.util.Map;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class StoryIntelTrainerFragment extends DialogFragment {

    @Inject
    FeedUtils feedUtils;

    private Story story;
    private FeedSet fs;
    private DialogTrainstoryBinding binding;

    private StoryIntelUiState latestState;
    private StoryIntelTrainerViewModel viewModel;
    private AlertDialog dialog;

    public static StoryIntelTrainerFragment newInstance(Story story, FeedSet fs, @Nullable String selectedText) {
        if (story.feedId.equals("0")) {
            throw new IllegalArgumentException("cannot intel train stories with a null/zero feed");
        }
        StoryIntelTrainerFragment fragment = new StoryIntelTrainerFragment();
        Bundle args = new Bundle();
        args.putString("feedId", story.feedId);
        args.putString("storyHash", story.storyHash);
        args.putString("storyTitle", story.title);

        args.putSerializable("story", story);
        args.putSerializable("feedSet", fs);
        args.putString("selectedText", selectedText);
        fragment.setArguments(args);
        return fragment;
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        story = (Story) getArguments().getSerializable("story");
        fs = (FeedSet) getArguments().getSerializable("feedSet");
        @Nullable String selectedText = getArguments().getString("selectedText");

        View v = getLayoutInflater().inflate(R.layout.dialog_trainstory, null);
        binding = DialogTrainstoryBinding.bind(v);

        binding.intelLoading.setVisibility(View.VISIBLE);
        binding.intelContent.setVisibility(View.GONE);

        // get the viewmodel (Hilt-created Kotlin VM) using ViewModelProvider
        viewModel = new ViewModelProvider(this).get(StoryIntelTrainerViewModel.class);

        // observe LiveData UI state
        viewModel.getUiState().observe(this, uiState -> {
            latestState = uiState;
            renderUiState(uiState);
        });

        // set up the special title training box for the title from this story and the associated buttons
        binding.intelTitleSelection.setText(story.title);
        // the layout sets inputType="none" on this EditText, but a widespread platform bug requires us
        // to also set this programmatically to make the field read-only for selection.
        binding.intelTitleSelection.setInputType(InputType.TYPE_NULL);
        // the user is selecting for our custom widget, not to copy/paste
        binding.intelTitleSelection.disableActionMenu();
        // pre-select the whole title to make it easier for the user to manipulate the selection handles
        binding.intelTitleSelection.selectAll();
        // do this after init and selection to prevent toast spam
        binding.intelTitleSelection.setForceSelection(true);
        // the disposition buttons for a new title training don't immediately impact the classifier object,
        // lest the user want to change selection substring after choosing the disposition.  so just store
        // the training factor in a variable that can be pulled on completion
        binding.intelTitleLike.setOnClickListener(v1 -> {
            viewModel.setPendingTitleTraining(Classifier.LIKE);
            setLikeViews(binding.intelTitleLike, binding.intelTitleDislike);
        });
        binding.intelTitleDislike.setOnClickListener(v2 -> {
            viewModel.setPendingTitleTraining(Classifier.DISLIKE);
            setDislikeViews(binding.intelTitleLike, binding.intelTitleDislike);
        });
        binding.intelTitleClear.setOnClickListener(v3 -> {
            viewModel.setPendingTitleTraining(null);
            setClearViews(binding.intelTitleLike, binding.intelTitleDislike);
        });

        if (selectedText != null && !selectedText.isEmpty()) {
            // data
            binding.intelTextSelection.setText(selectedText);
            binding.intelTextSelection.setInputType(InputType.TYPE_NULL);
            binding.intelTextSelection.disableActionMenu();
            binding.intelTextSelection.selectAll();
            binding.intelTextSelection.setForceSelection(true);

            // visibility
            binding.intelTextHeader.setVisibility(View.VISIBLE);
            binding.intelTextSelection.setVisibility(View.VISIBLE);
            binding.intelTextClear.setVisibility(View.VISIBLE);
            binding.intelTextLike.setVisibility(View.VISIBLE);
            binding.intelTextDislike.setVisibility(View.VISIBLE);

            // disposition buttons

            binding.intelTextLike.setOnClickListener(v4 -> {
                viewModel.setPendingTextTraining(Classifier.LIKE);
                setLikeViews(binding.intelTextLike, binding.intelTextDislike);
            });
            binding.intelTextDislike.setOnClickListener(v5 -> {
                viewModel.setPendingTextTraining(Classifier.DISLIKE);
                setDislikeViews(binding.intelTextLike, binding.intelTextDislike);
            });
            binding.intelTextClear.setOnClickListener(v6 -> {
                viewModel.setPendingTextTraining(null);
                setClearViews(binding.intelTextLike, binding.intelTextDislike);
            });
        } else {
            binding.intelTextHeader.setVisibility(View.GONE);
            binding.intelTextLike.setVisibility(View.GONE);
            binding.intelTextDislike.setVisibility(View.GONE);
            binding.intelTextClear.setVisibility(View.GONE);
            binding.intelTextSelection.setVisibility(View.GONE);
        }

        AlertDialog.Builder builder = getBuilder(v);

        dialog = builder.create();
        dialog.getWindow().getAttributes().gravity = Gravity.BOTTOM;
        dialog.setOnShowListener(d -> {
            if (latestState != null) {
                Button positive = dialog.getButton(AlertDialog.BUTTON_POSITIVE);
                if (positive != null) {
                    positive.setEnabled(!latestState.getLoading() && latestState.getClassifier() != null);
                }
            }
        });
        return dialog;
    }

    @NonNull
    private AlertDialog.Builder getBuilder(View v) {
        AlertDialog.Builder builder = new AlertDialog.Builder(requireActivity());
        builder.setTitle(R.string.story_intel_dialog_title);
        builder.setView(v);

        builder.setNegativeButton(R.string.alert_dialog_cancel, (dialogInterface, i) -> StoryIntelTrainerFragment.this.dismiss());
        builder.setPositiveButton(R.string.dialog_story_intel_save, (dialogInterface, i) -> {
            if (latestState == null || latestState.getClassifier() == null) {
                return;
            }
            String textSelection =
                    (binding.intelTextSelection.getVisibility() == View.VISIBLE)
                            ? binding.intelTextSelection.getSelection()
                            : null;

            Classifier updated = viewModel.buildUpdatedClassifier(
                    latestState.getClassifier(),
                    binding.intelTitleSelection.getSelection(),
                    textSelection
            );
            // existing call to persist/send
            feedUtils.updateClassifier(story.feedId, updated, fs, requireActivity());
            StoryIntelTrainerFragment.this.dismiss();
        });
        return builder;
    }

    private void setDislikeViews(View like, View dislike) {
        like.setBackgroundResource(R.drawable.ic_thumb_up_yellow);
        dislike.setBackgroundResource(R.drawable.ic_thumb_down_red);
    }

    private void setLikeViews(View like, View dislike) {
        like.setBackgroundResource(R.drawable.ic_thumb_up_green);
        dislike.setBackgroundResource(R.drawable.ic_thumb_down_yellow);
    }

    private void setClearViews(View like, View dislike) {
        like.setBackgroundResource(R.drawable.ic_thumb_up_yellow);
        dislike.setBackgroundResource(R.drawable.ic_thumb_down_yellow);
    }

    private void renderUiState(StoryIntelUiState state) {
        latestState = state;

        binding.intelLoading.setVisibility(state.getLoading() ? View.VISIBLE : View.GONE);
        binding.intelContent.setVisibility(state.getLoading() ? View.GONE : View.VISIBLE);

        if (state.getError() != null) {
            Toast.makeText(requireContext(), state.getError(), Toast.LENGTH_LONG).show();
        }

        // enable/disable Save
        if (dialog != null) {
            Button positive = dialog.getButton(AlertDialog.BUTTON_POSITIVE);
            if (positive != null) {
                positive.setEnabled(!state.getLoading() && state.getClassifier() != null);
            }
        }

        if (state.getLoading() || state.getClassifier() == null) return;

        Classifier c = state.getClassifier();

        // ----- Title matches -----
        binding.existingTitleIntelContainer.removeAllViews();
        if (story.title != null) {
            for (Map.Entry<String, Integer> rule : c.title.entrySet()) {
                if (story.title.contains(rule.getKey())) {
                    View row = getLayoutInflater().inflate(R.layout.include_intel_row, binding.existingTitleIntelContainer, false);
                    ((TextView) row.findViewById(R.id.intel_row_label)).setText(rule.getKey());
                    UIUtils.setupIntelDialogRow(row, c.title, rule.getKey());
                    binding.existingTitleIntelContainer.addView(row);
                }
            }
        }

        // ----- Text matches -----
        binding.existingTextIntelContainer.removeAllViews();
        String storyText = state.getStoryText();
        if (storyText != null) {
            String lower = storyText.toLowerCase(Locale.US);
            for (Map.Entry<String, Integer> rule : c.texts.entrySet()) {
                if (lower.contains(rule.getKey().toLowerCase(Locale.US))) {
                    View row = getLayoutInflater().inflate(R.layout.include_intel_row, binding.existingTextIntelContainer, false);
                    ((TextView) row.findViewById(R.id.intel_row_label)).setText(rule.getKey());
                    UIUtils.setupIntelDialogRow(row, c.texts, rule.getKey());
                    binding.existingTextIntelContainer.addView(row);
                }
            }

            if (binding.intelTextHeader.getVisibility() == View.GONE &&
                    binding.existingTextIntelContainer.getChildCount() > 0) {
                binding.intelTextHeader.setVisibility(View.VISIBLE);
            }
        }

        // ----- Tags -----
        binding.existingTagIntelContainer.removeAllViews();
        if (story.tags != null && story.tags.length > 0) {
            binding.intelTagHeader.setVisibility(View.VISIBLE);
            for (String tag : story.tags) {
                View row = getLayoutInflater().inflate(R.layout.include_intel_row, binding.existingTagIntelContainer, false);
                ((TextView) row.findViewById(R.id.intel_row_label)).setText(tag);
                UIUtils.setupIntelDialogRow(row, c.tags, tag);
                binding.existingTagIntelContainer.addView(row);
            }
        } else {
            binding.intelTagHeader.setVisibility(View.GONE);
        }

        // ----- Author -----
        binding.existingAuthorIntelContainer.removeAllViews();
        if (!TextUtils.isEmpty(story.authors)) {
            binding.intelAuthorHeader.setVisibility(View.VISIBLE);
            View row = getLayoutInflater().inflate(R.layout.include_intel_row, binding.existingAuthorIntelContainer, false);
            ((TextView) row.findViewById(R.id.intel_row_label)).setText(story.authors);
            UIUtils.setupIntelDialogRow(row, c.authors, story.authors);
            binding.existingAuthorIntelContainer.addView(row);
        } else {
            binding.intelAuthorHeader.setVisibility(View.GONE);
        }

        // ----- Feed -----
        binding.existingFeedIntelContainer.removeAllViews();
        View rowFeed = getLayoutInflater().inflate(R.layout.include_intel_row, binding.existingFeedIntelContainer, false);
        ((TextView) rowFeed.findViewById(R.id.intel_row_label)).setText(feedUtils.getFeedTitle(story.feedId));
        UIUtils.setupIntelDialogRow(rowFeed, c.feeds, story.feedId);
        binding.existingFeedIntelContainer.addView(rowFeed);
    }
}

