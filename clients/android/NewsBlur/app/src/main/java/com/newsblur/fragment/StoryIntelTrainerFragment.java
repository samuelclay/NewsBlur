package com.newsblur.fragment;

import android.app.Dialog;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.google.android.material.bottomsheet.BottomSheetDialogFragment;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.databinding.FragmentIntelTrainerSheetBinding;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.di.IconLoader;
import com.newsblur.di.ThumbnailLoader;
import com.newsblur.network.ClassifierApi;
import com.newsblur.util.ImageLoader;
import com.newsblur.preference.PrefsRepo;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.NewsBlurBottomSheet;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

/**
 * The story trainer, laid out by IntelTrainerSections.kt like clients/ios/Classes/TrainerView.swift.
 */
@AndroidEntryPoint
public class StoryIntelTrainerFragment extends BottomSheetDialogFragment {

    @Inject
    FeedUtils feedUtils;

    @Inject
    BlurDatabaseHelper dbHelper;

    @Inject
    PrefsRepo prefsRepo;

    @Inject
    ClassifierApi classifierApi;

    @Inject
    @ThumbnailLoader
    ImageLoader thumbnailLoader;

    @Inject
    @IconLoader
    ImageLoader iconLoader;

    private Story story;
    private FeedSet fs;
    private Classifier classifier;
    private IntelTrainerSections sections;
    private FragmentIntelTrainerSheetBinding binding;

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
            IntelTrainerSections.expandSheet(dialog, prefsRepo.getResolvedTheme(requireContext()));
        }
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        binding = FragmentIntelTrainerSheetBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        story = (Story) getArguments().getSerializable("story");
        fs = (FeedSet) getArguments().getSerializable("feedset");
        classifier = dbHelper.getClassifierForFeed(story.feedId);
        PrefConstants.ThemeValue theme = prefsRepo.getResolvedTheme(requireContext());
        IntelTrainerSections.styleSheet(binding, theme, true);

        sections = new IntelTrainerSections(this, binding.trainerSections, classifier, story, story.feedId, theme,
                prefsRepo, dbHelper, classifierApi, thumbnailLoader, iconLoader);
        sections.bind();

        binding.cancelButton.setOnClickListener(v -> dismiss());
        binding.saveButton.setOnClickListener(v -> saveAndDismiss());
    }

    private void saveAndDismiss() {
        sections.commit();
        feedUtils.updateClassifier(story.feedId, classifier, fs, requireActivity());
        dismiss();
    }

    @Override
    public void onDestroyView() {
        binding = null;
        super.onDestroyView();
    }

}
