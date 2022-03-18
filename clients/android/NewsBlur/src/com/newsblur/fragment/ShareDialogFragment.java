package com.newsblur.fragment;

import android.app.Activity;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;

import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.EditText;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class ShareDialogFragment extends DialogFragment {

    @Inject
    FeedUtils feedUtils;

    @Inject
    BlurDatabaseHelper dbHelper;

	private static final String STORY = "story";
    private static final String SOURCE_USER_ID = "sourceUserId";
	private Story story;
	private UserDetails user;
	private Comment previousComment;
    private EditText commentEditText;
    private String sourceUserId;

	public static ShareDialogFragment newInstance(final Story story, final String sourceUserId) {
		ShareDialogFragment frag = new ShareDialogFragment();
		Bundle args = new Bundle();
		args.putSerializable(STORY, story);
        args.putString(SOURCE_USER_ID, sourceUserId);
		frag.setArguments(args);
		return frag;
	}

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        final Activity activity = getActivity();
        story = (Story) getArguments().getSerializable(STORY);
        user = PrefsUtils.getUserDetails(activity);
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

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle(String.format(getResources().getString(R.string.share_save_newsblur), UIUtils.fromHtml(story.title)));

        LayoutInflater layoutInflater = LayoutInflater.from(activity);
        View replyView = layoutInflater.inflate(R.layout.share_dialog, null);
        builder.setView(replyView);
        commentEditText = (EditText) replyView.findViewById(R.id.comment_field);

        int positiveButtonText = R.string.share_this_story;
        int negativeButtonText = R.string.alert_dialog_cancel;
        if (hasBeenShared) {
            positiveButtonText = R.string.update_shared;
            if (previousComment != null ) {
                commentEditText.setText(previousComment.commentText);
            }
            negativeButtonText = R.string.unshare;
        }

        builder.setPositiveButton(positiveButtonText, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                String shareComment = commentEditText.getText().toString();
                feedUtils.shareStory(story, shareComment, sourceUserId, activity);
                ShareDialogFragment.this.dismiss();
            }
        });
        if (hasBeenShared) {
            // unshare
            builder.setNegativeButton(negativeButtonText, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialogInterface, int i) {
                    feedUtils.unshareStory(story, activity);
                    ShareDialogFragment.this.dismiss();
                }
            });
        } else {
            // cancel
            builder.setNegativeButton(negativeButtonText, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialogInterface, int i) {
                    ShareDialogFragment.this.dismiss();
                }
            });
        }
        return builder.create();
    }

}
