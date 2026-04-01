package com.newsblur.fragment;

import android.app.Dialog;
import android.content.res.ColorStateList;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextUtils;
import android.text.TextWatcher;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.ViewModelProvider;

import com.google.android.material.bottomsheet.BottomSheetDialogFragment;
import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.databinding.FragmentShareDialogSheetBinding;
import com.newsblur.design.ReaderSheetPalette;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.preference.PrefsRepo;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.NewsBlurBottomSheet;
import com.newsblur.util.UIUtils;
import com.newsblur.viewModel.ShareDialogViewModel;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class ShareDialogFragment extends BottomSheetDialogFragment {

    @Inject
    BlurDatabaseHelper dbHelper;

    @Inject
    PrefsRepo prefsRepo;

    private static final String STORY = "story";
    private static final String SOURCE_USER_ID = "sourceUserId";
    private Story story;
    private Comment previousComment;
    private String sourceUserId;
    private boolean hasBeenShared;

    private ShareDialogViewModel viewModel;
    private FragmentShareDialogSheetBinding binding;

    public static ShareDialogFragment newInstance(final Story story, final String sourceUserId) {
        ShareDialogFragment frag = new ShareDialogFragment();
        Bundle args = new Bundle();
        args.putSerializable(STORY, story);
        args.putString(SOURCE_USER_ID, sourceUserId);
        frag.setArguments(args);
        return frag;
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        viewModel = new ViewModelProvider(this).get(ShareDialogViewModel.class);
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        return NewsBlurBottomSheet.createDialog(
                this,
                WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE | WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
        );
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
        binding = FragmentShareDialogSheetBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        story = (Story) getArguments().getSerializable(STORY);
        UserDetails user = prefsRepo.getUserDetails();
        sourceUserId = getArguments().getString(SOURCE_USER_ID);

        hasBeenShared = false;
        for (String sharedUserId : story.sharedUserIds) {
            if (TextUtils.equals(user.id, sharedUserId)) {
                hasBeenShared = true;
                break;
            }
        }

        if (hasBeenShared) {
            previousComment = dbHelper.getComment(story.id, user.id);
        }

        bindTheme();
        binding.storyTitle.setText(UIUtils.fromHtml(story.title));
        if (hasBeenShared) {
            if (previousComment != null) {
                binding.commentField.setText(previousComment.commentText);
            }
        }
        binding.secondaryButton.setText(hasBeenShared ? R.string.unshare : R.string.alert_dialog_cancel);
        updatePrimaryButtonText();

        binding.primaryButton.setOnClickListener(v1 -> {
            String shareComment = binding.commentField.getText().toString();
            viewModel.shareStory(requireContext(), story, shareComment, sourceUserId);
            dismiss();
        });
        binding.secondaryButton.setOnClickListener(v12 -> {
            if (hasBeenShared) {
                viewModel.unshareStory(requireContext(), story);
            }
            dismiss();
        });
        binding.commentField.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                updatePrimaryButtonText();
            }

            @Override
            public void afterTextChanged(Editable s) {}
        });
        binding.commentField.post(() -> {
            binding.commentField.requestFocus();
            if (getDialog() != null && getDialog().getWindow() != null) {
                getDialog().getWindow().setSoftInputMode(
                        WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE | WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
                );
            }
        });
    }

    private void bindTheme() {
        PrefConstants.ThemeValue theme = prefsRepo.getResolvedTheme(requireContext());
        int borderColor = ReaderSheetPalette.borderArgb(theme);
        int inputBackgroundColor = ReaderSheetPalette.inputBackgroundArgb(theme);
        int textPrimaryColor = ReaderSheetPalette.textPrimaryArgb(theme);
        int textSecondaryColor = ReaderSheetPalette.textSecondaryArgb(theme);
        int accentColor = ReaderSheetPalette.accentArgb(theme);

        binding.sheetDragHandle.setBackground(makeRoundedRect(borderColor, 2f));
        binding.sheetTitle.setTextColor(textPrimaryColor);
        binding.storyTitle.setTextColor(textSecondaryColor);
        binding.commentField.setTextColor(textPrimaryColor);
        binding.commentField.setHintTextColor(textSecondaryColor);
        binding.commentField.setBackground(makeStrokedRoundedRect(inputBackgroundColor, borderColor, 1));
        binding.primaryButton.setBackgroundTintList(ColorStateList.valueOf(accentColor));
        binding.primaryButton.setTextColor(ContextCompat.getColor(requireContext(), R.color.white));
        binding.secondaryButton.setTextColor(textSecondaryColor);
        binding.secondaryButton.setRippleColor(ColorStateList.valueOf(borderColor));
    }

    private void updatePrimaryButtonText() {
        boolean hasComment = binding.commentField.getText() != null && binding.commentField.getText().length() > 0;
        if (hasBeenShared) {
            binding.primaryButton.setText(R.string.update_shared);
        } else {
            binding.primaryButton.setText(hasComment ? R.string.share_with_comment : R.string.share_this_story);
        }
    }

    private GradientDrawable makeRoundedRect(int color, float radiusDp) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setShape(GradientDrawable.RECTANGLE);
        drawable.setCornerRadius(radiusDp * getResources().getDisplayMetrics().density);
        drawable.setColor(color);
        return drawable;
    }

    private GradientDrawable makeStrokedRoundedRect(int fillColor, int strokeColor, int strokeWidthDp) {
        GradientDrawable drawable = makeRoundedRect(fillColor, 8f);
        drawable.setStroke((int) (strokeWidthDp * getResources().getDisplayMetrics().density), strokeColor);
        return drawable;
    }

    @Override
    public void onDestroyView() {
        binding = null;
        super.onDestroyView();
    }

}
