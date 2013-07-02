package com.newsblur.fragment;

import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
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
	public void onCreate(Bundle savedInstanceState) {
		setStyle(DialogFragment.STYLE_NO_TITLE, R.style.dialog);

		story = (Story) getArguments().getSerializable(STORY);
		
		commentUserId = getArguments().getString(COMMENT_USER_ID);
		commentUsername = getArguments().getString(COMMENT_USERNAME);
		
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		final String shareString = getResources().getString(R.string.reply_to);
		
		apiManager = new APIManager(getActivity());
		View v = inflater.inflate(R.layout.fragment_dialog, container, false);
		final TextView message = (TextView) v.findViewById(R.id.dialog_message);
		final EditText reply = (EditText) v.findViewById(R.id.dialog_share_comment);
		message.setText(String.format(shareString, getArguments().getString(COMMENT_USERNAME)));
		
		Button okayButton = (Button) v.findViewById(R.id.dialog_button_okay);
		okayButton.setOnClickListener(new OnClickListener() {
			public void onClick(final View v) {
				
				v.setEnabled(false);
				
				new AsyncTask<Void, Void, Boolean>() {
					@Override
					protected Boolean doInBackground(Void... arg) {
						return apiManager.replyToComment(story.id, story.feedId, commentUserId, reply.getText().toString());
					}
					
					@Override
					protected void onPostExecute(Boolean result) {
						if (result) {
							Toast.makeText(getActivity(), R.string.replied, Toast.LENGTH_LONG).show();
						} else {
							Toast.makeText(getActivity(), R.string.error_replying, Toast.LENGTH_LONG).show();
						}
						v.setEnabled(true);
						ReplyDialogFragment.this.dismiss();
					};
				}.execute();
			}
		});
		
		Button cancelButton = (Button) v.findViewById(R.id.dialog_button_cancel);
		cancelButton.setOnClickListener(new OnClickListener() {
			public void onClick(View v) {
				ReplyDialogFragment.this.dismiss();
			}
		});

		return v;
	}

	public interface ReplyDialogCallback {
		public void replyPosted(String reply);
	}
	
}
