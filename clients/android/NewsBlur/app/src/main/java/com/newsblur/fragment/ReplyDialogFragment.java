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
public class ReplyDialogFragment extends DialogFragment {

    @Inject
    FeedUtils feedUtils;

	private static final String STORY = "story";
	private static final String COMMENT_USER_ID = "comment_user_id";
	private static final String COMMENT_USERNAME = "comment_username";
	
	private String commentUserId;
	private Story story;
	
	public static ReplyDialogFragment newInstance(final Story story, final String commentUserId, final String commentUsername) {
		ReplyDialogFragment frag = new ReplyDialogFragment();
		Bundle args = new Bundle();
		args.putSerializable(STORY, story);
		args.putString(COMMENT_USER_ID, commentUserId);
		args.putString(COMMENT_USERNAME, commentUsername);
		frag.setArguments(args);
		return frag;
	}	

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        story = (Story) getArguments().getSerializable(STORY);
        commentUserId = getArguments().getString(COMMENT_USER_ID);

        final Activity activity = getActivity();

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        String shareString = getResources().getString(R.string.reply_to);
        builder.setTitle(String.format(shareString, getArguments().getString(COMMENT_USERNAME)));

        LayoutInflater layoutInflater = LayoutInflater.from(activity);
        View replyView = layoutInflater.inflate(R.layout.reply_dialog, null);
        builder.setView(replyView);
        final EditText reply = (EditText) replyView.findViewById(R.id.reply_field);

        builder.setPositiveButton(R.string.alert_dialog_ok, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                feedUtils.replyToComment(story.id, story.feedId, commentUserId, reply.getText().toString(), activity);
            }
        });
        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                ReplyDialogFragment.this.dismiss();
            }
        });
        return builder.create();
    }
	
}
