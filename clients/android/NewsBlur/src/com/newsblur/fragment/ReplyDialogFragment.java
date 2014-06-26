package com.newsblur.fragment;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.DialogFragment;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.EditText;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.domain.Story;
import com.newsblur.network.APIManager;

public class ReplyDialogFragment extends DialogFragment {

	private static final String STORY = "story";
	private static final String COMMENT_USER_ID = "comment_user_id";
	private static final String COMMENT_USERNAME = "comment_username";
	
	private String commentUserId, commentUsername;
	private Story story;
	
	private APIManager apiManager;


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
        commentUsername = getArguments().getString(COMMENT_USERNAME);

        final Activity activity = getActivity();
        apiManager = new APIManager(activity);

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        final String shareString = getResources().getString(R.string.reply_to);
        builder.setTitle(String.format(shareString, getArguments().getString(COMMENT_USERNAME)));

        LayoutInflater layoutInflater = LayoutInflater.from(activity);
        View replyView = layoutInflater.inflate(R.layout.reply_dialog, null);
        builder.setView(replyView);
        final EditText reply = (EditText) replyView.findViewById(R.id.reply_field);

        builder.setPositiveButton(R.string.alert_dialog_ok, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {

                new AsyncTask<Void, Void, Boolean>() {
                    @Override
                    protected Boolean doInBackground(Void... arg) {
                        return apiManager.replyToComment(story.id, story.feedId, commentUserId, reply.getText().toString());
                    }

                    @Override
                    protected void onPostExecute(Boolean result) {
                        if (result) {
                            Toast.makeText(activity, R.string.replied, Toast.LENGTH_LONG).show();
                        } else {
                            Toast.makeText(activity, R.string.error_replying, Toast.LENGTH_LONG).show();
                        }
                        ReplyDialogFragment.this.dismiss();
                    };
                }.execute();
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
