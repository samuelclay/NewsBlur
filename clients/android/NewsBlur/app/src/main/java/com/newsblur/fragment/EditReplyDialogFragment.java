package com.newsblur.fragment;

import android.app.Activity;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;

import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.EditText;

import com.newsblur.R;
import com.newsblur.domain.Story;
import com.newsblur.util.FeedUtils;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class EditReplyDialogFragment extends DialogFragment {

    @Inject
    FeedUtils feedUtils;

	private static final String STORY = "story";
    private static final String COMMENT_USER_ID = "comment_user_id";
    private static final String REPLY_ID = "reply_id";
    private static final String REPLY_TEXT = "reply_text";

	public static EditReplyDialogFragment newInstance(Story story, String commentUserId, String replyId, String replyText) {
		EditReplyDialogFragment frag = new EditReplyDialogFragment();
		Bundle args = new Bundle();
		args.putSerializable(STORY, story);
        args.putString(COMMENT_USER_ID, commentUserId);
        args.putString(REPLY_ID, replyId);
        args.putString(REPLY_TEXT, replyText);
		frag.setArguments(args);
		return frag;
	}

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        final Activity activity = getActivity();
        final Story story = (Story) getArguments().getSerializable(STORY);
        final String commentUserId = getArguments().getString(COMMENT_USER_ID);
        final String replyId = getArguments().getString(REPLY_ID);
        String replyText = getArguments().getString(REPLY_TEXT);

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle(R.string.edit_reply);

        LayoutInflater layoutInflater = LayoutInflater.from(activity);
        View replyView = layoutInflater.inflate(R.layout.reply_dialog, null);
        builder.setView(replyView);
        final EditText reply = (EditText) replyView.findViewById(R.id.reply_field);
        reply.setText(replyText);

        builder.setPositiveButton(R.string.edit_reply_update, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                String replyText = reply.getText().toString();
                feedUtils.updateReply(activity, story, commentUserId, replyId, replyText);
                EditReplyDialogFragment.this.dismiss();
            }
        });
        builder.setNegativeButton(R.string.edit_reply_delete, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                feedUtils.deleteReply(activity, story, commentUserId, replyId);
                EditReplyDialogFragment.this.dismiss();
            }
        });
        return builder.create();
    }

}
