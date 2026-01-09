package com.newsblur.fragment;

import android.app.Dialog;
import android.os.Bundle;
import android.text.TextUtils;
import android.view.View;
import android.widget.EditText;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import androidx.lifecycle.ViewModelProvider;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.preference.PrefsRepo;
import com.newsblur.util.UIUtils;
import com.newsblur.viewModel.ShareDialogViewModel;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class ShareDialogFragment extends DialogFragment {

    @Inject
    BlurDatabaseHelper dbHelper;

    @Inject
    PrefsRepo prefsRepo;

    private static final String STORY = "story";
    private static final String SOURCE_USER_ID = "sourceUserId";
    private Story story;
    private Comment previousComment;
    private EditText commentEditText;
    private String sourceUserId;

    private ShareDialogViewModel viewModel;

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
        story = (Story) getArguments().getSerializable(STORY);
        UserDetails user = prefsRepo.getUserDetails();
        sourceUserId = getArguments().getString(SOURCE_USER_ID);

        boolean hasBeenShared = false;
        for (String sharedUserId : story.sharedUserIds) {
            if (TextUtils.equals(user.id, sharedUserId)) {
                hasBeenShared = true;
                break;
            }
        }

        if (hasBeenShared) {
            previousComment = dbHelper.getComment(story.id, user.id);
        }

        AlertDialog.Builder builder = new AlertDialog.Builder(requireContext());
        builder.setTitle(String.format(getResources().getString(R.string.share_save_newsblur), UIUtils.fromHtml(story.title)));

        View replyView = getLayoutInflater().inflate(R.layout.share_dialog, null);
        builder.setView(replyView);
        commentEditText = replyView.findViewById(R.id.comment_field);

        int positiveButtonText = R.string.share_this_story;
        int negativeButtonText = R.string.alert_dialog_cancel;
        if (hasBeenShared) {
            positiveButtonText = R.string.update_shared;
            if (previousComment != null) {
                commentEditText.setText(previousComment.commentText);
            }
            negativeButtonText = R.string.unshare;
        }

        builder.setPositiveButton(positiveButtonText, (dialogInterface, i) -> {
            String shareComment = commentEditText.getText().toString();
            viewModel.shareStory(requireContext(), story, shareComment, sourceUserId);
            ShareDialogFragment.this.dismiss();
        });
        if (hasBeenShared) {
            // unshare
            builder.setNegativeButton(negativeButtonText, (dialogInterface, i) -> {
                viewModel.unshareStory(requireContext(), story);
                ShareDialogFragment.this.dismiss();
            });
        } else {
            // cancel
            builder.setNegativeButton(negativeButtonText, (dialogInterface, i) -> ShareDialogFragment.this.dismiss());
        }
        return builder.create();
    }

}
