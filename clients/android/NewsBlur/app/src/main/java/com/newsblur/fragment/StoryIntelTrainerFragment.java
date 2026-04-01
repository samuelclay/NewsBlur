package com.newsblur.fragment;

import java.util.Map;

import android.app.Dialog;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.google.android.material.bottomsheet.BottomSheetDialogFragment;
import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.databinding.DialogTrainstoryBinding;
import com.newsblur.databinding.FragmentStoryIntelTrainerSheetBinding;
import com.newsblur.design.ReaderSheetPalette;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.preference.PrefsRepo;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.NewsBlurBottomSheet;
import com.newsblur.util.UIUtils;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class StoryIntelTrainerFragment extends BottomSheetDialogFragment {

    @Inject
    FeedUtils feedUtils;

    @Inject
    BlurDatabaseHelper dbHelper;

    @Inject
    PrefsRepo prefsRepo;

    private Story story;
    private FeedSet fs;
    private Classifier classifier;
    private Integer newTitleTraining;
    private DialogTrainstoryBinding contentBinding;
    private FragmentStoryIntelTrainerSheetBinding binding;

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

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        return NewsBlurBottomSheet.createDialog(this);
    }

    @Override
    public void onStart() {
        super.onStart();
        Dialog dialog = getDialog();
        if (dialog != null) {
            NewsBlurBottomSheet.expandWithTheme(dialog, prefsRepo.getResolvedTheme(requireContext()));
        }
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        binding = FragmentStoryIntelTrainerSheetBinding.inflate(inflater, container, false);
        contentBinding = binding.trainContent;
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        story = (Story) getArguments().getSerializable("story");
        fs = (FeedSet) getArguments().getSerializable("feedset");
        classifier = dbHelper.getClassifierForFeed(story.feedId);
        bindTheme();

        // set up the special title training box for the title from this story and the associated buttons
        contentBinding.intelTitleSelection.setText(story.title);
        // the layout sets inputType="none" on this EditText, but a widespread platform bug requires us
        // to also set this programmatically to make the field read-only for selection.
        contentBinding.intelTitleSelection.setInputType(android.text.InputType.TYPE_NULL);
        // the user is selecting for our custom widget, not to copy/paste
        contentBinding.intelTitleSelection.disableActionMenu();
        // pre-select the whole title to make it easier for the user to manipulate the selection handles
        contentBinding.intelTitleSelection.selectAll();
        // do this after init and selection to prevent toast spam
        contentBinding.intelTitleSelection.setForceSelection(true);
        // the disposition buttons for a new title training don't immediately impact the classifier object,
        // lest the user want to change selection substring after choosing the disposition.  so just store
        // the training factor in a variable that can be pulled on completion
        contentBinding.intelTitleLike.setOnClickListener(v -> {
            newTitleTraining = Classifier.LIKE;
            contentBinding.intelTitleLike.setBackgroundResource(R.drawable.ic_thumb_up_green);
            contentBinding.intelTitleDislike.setBackgroundResource(R.drawable.ic_thumb_down_yellow);
            contentBinding.intelTitleSuperDislike.setBackgroundResource(R.drawable.ic_thumb_down_double_yellow);
        });
        contentBinding.intelTitleDislike.setOnClickListener(v -> {
            newTitleTraining = Classifier.DISLIKE;
            contentBinding.intelTitleLike.setBackgroundResource(R.drawable.ic_thumb_up_yellow);
            contentBinding.intelTitleDislike.setBackgroundResource(R.drawable.ic_thumb_down_red);
            contentBinding.intelTitleSuperDislike.setBackgroundResource(R.drawable.ic_thumb_down_double_yellow);
        });
        contentBinding.intelTitleSuperDislike.setOnClickListener(v -> {
            newTitleTraining = Classifier.SUPER_DISLIKE;
            contentBinding.intelTitleLike.setBackgroundResource(R.drawable.ic_thumb_up_yellow);
            contentBinding.intelTitleDislike.setBackgroundResource(R.drawable.ic_thumb_down_yellow);
            contentBinding.intelTitleSuperDislike.setBackgroundResource(R.drawable.ic_thumb_down_double_crimson);
        });
        contentBinding.intelTitleClear.setOnClickListener(v -> {
            newTitleTraining = null;
            contentBinding.intelTitleLike.setBackgroundResource(R.drawable.ic_thumb_up_yellow);
            contentBinding.intelTitleDislike.setBackgroundResource(R.drawable.ic_thumb_down_yellow);
            contentBinding.intelTitleSuperDislike.setBackgroundResource(R.drawable.ic_thumb_down_double_yellow);
        });

        // scan trained title fragments for this feed and see if any apply to this story
        for (Map.Entry<String, Integer> rule : classifier.title.entrySet()) {
            if (story.title.indexOf(rule.getKey()) >= 0) {
                View row = getLayoutInflater().inflate(R.layout.include_intel_row, null);
                TextView label = row.findViewById(R.id.intel_row_label);
                label.setText(rule.getKey());
                UIUtils.setupIntelDialogRow(row, classifier.title, rule.getKey());
                contentBinding.existingTitleIntelContainer.addView(row);
            }
        }
        
        // list all tags for this story, trained or not
        for (String tag : story.tags) {
            View row = getLayoutInflater().inflate(R.layout.include_intel_row, null);
            TextView label = row.findViewById(R.id.intel_row_label);
            label.setText(tag);
            UIUtils.setupIntelDialogRow(row, classifier.tags, tag);
            contentBinding.existingTagIntelContainer.addView(row);
        }
        if (story.tags.length < 1) contentBinding.intelTagHeader.setVisibility(View.GONE);

        // there is a single author per story
        if (!TextUtils.isEmpty(story.authors)) {
            View rowAuthor = getLayoutInflater().inflate(R.layout.include_intel_row, null);
            TextView labelAuthor = rowAuthor.findViewById(R.id.intel_row_label);
            labelAuthor.setText(story.authors);
            UIUtils.setupIntelDialogRow(rowAuthor, classifier.authors, story.authors);
            contentBinding.existingAuthorIntelContainer.addView(rowAuthor);
        } else {
            contentBinding.intelAuthorHeader.setVisibility(View.GONE);
        }

        // there is a single feed to be trained, but it is a bit odd in that the label is the title and
        // the intel identifier is the feed ID
        View rowFeed = getLayoutInflater().inflate(R.layout.include_intel_row, null);
        TextView labelFeed = rowFeed.findViewById(R.id.intel_row_label);
        labelFeed.setText(feedUtils.getFeedTitle(story.feedId));
        UIUtils.setupIntelDialogRow(rowFeed, classifier.feeds, story.feedId);
        contentBinding.existingFeedIntelContainer.addView(rowFeed);

        binding.cancelButton.setOnClickListener(v -> dismiss());
        binding.saveButton.setOnClickListener(v -> saveAndDismiss());
    }

    private void saveAndDismiss() {
        if ((newTitleTraining != null) && (!TextUtils.isEmpty(contentBinding.intelTitleSelection.getSelection()))) {
            classifier.title.put(contentBinding.intelTitleSelection.getSelection(), newTitleTraining);
        }
        feedUtils.updateClassifier(story.feedId, classifier, fs, requireActivity());
        dismiss();
    }

    private void bindTheme() {
        PrefConstants.ThemeValue theme = prefsRepo.getResolvedTheme(requireContext());
        int borderColor = ReaderSheetPalette.borderArgb(theme);
        int textPrimaryColor = ReaderSheetPalette.textPrimaryArgb(theme);
        int textSecondaryColor = ReaderSheetPalette.textSecondaryArgb(theme);
        int accentColor = ReaderSheetPalette.accentArgb(theme);

        binding.sheetDragHandle.setBackground(makeRoundedRect(borderColor, 2f));
        binding.sheetTitle.setTextColor(textPrimaryColor);
        binding.cancelButton.setTextColor(textSecondaryColor);
        binding.cancelButton.setRippleColor(android.content.res.ColorStateList.valueOf(borderColor));
        binding.saveButton.setBackgroundTintList(android.content.res.ColorStateList.valueOf(accentColor));
        binding.saveButton.setTextColor(androidx.core.content.ContextCompat.getColor(requireContext(), R.color.white));

        UIUtils.setupIntelExplainer(binding.getRoot(), theme);
    }

    private android.graphics.drawable.GradientDrawable makeRoundedRect(int color, float radiusDp) {
        android.graphics.drawable.GradientDrawable drawable = new android.graphics.drawable.GradientDrawable();
        drawable.setShape(android.graphics.drawable.GradientDrawable.RECTANGLE);
        drawable.setCornerRadius(radiusDp * getResources().getDisplayMetrics().density);
        drawable.setColor(color);
        return drawable;
    }

    @Override
    public void onDestroyView() {
        contentBinding = null;
        binding = null;
        super.onDestroyView();
    }

}
