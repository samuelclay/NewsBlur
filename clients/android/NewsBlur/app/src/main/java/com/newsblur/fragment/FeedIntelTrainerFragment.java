package com.newsblur.fragment;

import java.util.List;
import java.util.Map;

import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;

import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import androidx.lifecycle.ViewModelProvider;

import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.databinding.DialogTrainfeedBinding;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.viewModel.FeedIntelTrainerViewModel;
import com.newsblur.viewModel.FeedIntelUiState;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class FeedIntelTrainerFragment extends DialogFragment {

    @Inject
    FeedUtils feedUtils;

    private Feed feed;
    private FeedSet fs;
    private DialogTrainfeedBinding binding;

    private FeedIntelUiState latestState;
    private FeedIntelTrainerViewModel viewModel;
    private AlertDialog dialog;

    public static FeedIntelTrainerFragment newInstance(Feed feed, FeedSet fs) {
        FeedIntelTrainerFragment fragment = new FeedIntelTrainerFragment();
        Bundle args = new Bundle();
        args.putString("feedId", feed.feedId);

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

        View v = getLayoutInflater().inflate(R.layout.dialog_trainfeed, null);
        binding = DialogTrainfeedBinding.bind(v);

        binding.intelLoading.setVisibility(View.VISIBLE);
        binding.intelContent.setVisibility(View.GONE);

        viewModel = new ViewModelProvider(this).get(FeedIntelTrainerViewModel.class);
        viewModel.getUiState().observe(this, uiState -> {
            latestState = uiState;
            renderUiState(uiState);
        });

        AlertDialog.Builder builder = new AlertDialog.Builder(requireContext());
        builder.setTitle(R.string.feed_intel_dialog_title);
        builder.setView(v);

        builder.setNegativeButton(R.string.alert_dialog_cancel, (dialogInterface, i) -> FeedIntelTrainerFragment.this.dismiss());

        builder.setPositiveButton(R.string.dialog_story_intel_save, (dialogInterface, i) -> {
            if (latestState == null || latestState.getClassifier() == null) return;
            feedUtils.updateClassifier(feed.feedId, latestState.getClassifier(), fs, requireContext());
            dismiss();
        });

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

    private void renderUiState(FeedIntelUiState state) {
        if (binding == null) return;

        binding.intelLoading.setVisibility(state.getLoading() ? View.VISIBLE : View.GONE);
        binding.intelContent.setVisibility(state.getLoading() ? View.GONE : View.VISIBLE);

        if (state.getError() != null) {
            Toast.makeText(requireContext(), state.getError(), Toast.LENGTH_LONG).show();
        }

        // enable Save
        if (dialog != null) {
            Button positive = dialog.getButton(AlertDialog.BUTTON_POSITIVE);
            if (positive != null) positive.setEnabled(!state.getLoading() && state.getClassifier() != null);
        }

        if (state.getLoading() || state.getClassifier() == null) return;

        Classifier c = state.getClassifier();

        // ----- Title -----
        binding.existingTitleIntelContainer.removeAllViews();
        for (Map.Entry<String, Integer> rule : c.title.entrySet()) {
            View row = getLayoutInflater().inflate(R.layout.include_intel_row, binding.existingTitleIntelContainer, false);
            ((TextView) row.findViewById(R.id.intel_row_label)).setText(rule.getKey());
            UIUtils.setupIntelDialogRow(row, c.title, rule.getKey());
            binding.existingTitleIntelContainer.addView(row);
        }
        binding.intelTitleHeader.setVisibility(c.title.isEmpty() ? View.GONE : View.VISIBLE);

        // ----- Text -----
        binding.existingTextIntelContainer.removeAllViews();
        for (Map.Entry<String, Integer> rule : c.texts.entrySet()) {
            View row = getLayoutInflater().inflate(R.layout.include_intel_row, binding.existingTextIntelContainer, false);
            ((TextView) row.findViewById(R.id.intel_row_label)).setText(rule.getKey());
            UIUtils.setupIntelDialogRow(row, c.texts, rule.getKey());
            binding.existingTextIntelContainer.addView(row);
        }
        binding.intelTextHeader.setVisibility(c.texts.isEmpty() ? View.GONE : View.VISIBLE);

        // ----- Tags (suggested + trained) -----
        binding.existingTagIntelContainer.removeAllViews();
        List<String> tags = state.getTags();
        for (String tag : tags) {
            View row = getLayoutInflater().inflate(R.layout.include_intel_row, binding.existingTagIntelContainer, false);
            ((TextView) row.findViewById(R.id.intel_row_label)).setText(tag);
            UIUtils.setupIntelDialogRow(row, c.tags, tag);
            binding.existingTagIntelContainer.addView(row);
        }
        binding.intelTagHeader.setVisibility(tags.isEmpty() ? View.GONE : View.VISIBLE);

        // ----- Authors (suggested + trained) -----
        binding.existingAuthorIntelContainer.removeAllViews();
        List<String> authors = state.getAuthors();
        for (String author : authors) {
            View row = getLayoutInflater().inflate(R.layout.include_intel_row, binding.existingAuthorIntelContainer, false);
            ((TextView) row.findViewById(R.id.intel_row_label)).setText(author);
            UIUtils.setupIntelDialogRow(row, c.authors, author);
            binding.existingAuthorIntelContainer.addView(row);
        }
        binding.intelAuthorHeader.setVisibility(authors.isEmpty() ? View.GONE : View.VISIBLE);

        // ----- Feed -----
        binding.existingFeedIntelContainer.removeAllViews();
        View rowFeed = getLayoutInflater().inflate(R.layout.include_intel_row, binding.existingFeedIntelContainer, false);
        ((TextView) rowFeed.findViewById(R.id.intel_row_label)).setText(feed.title);
        UIUtils.setupIntelDialogRow(rowFeed, c.feeds, feed.feedId);
        binding.existingFeedIntelContainer.addView(rowFeed);
    }
}
