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
import com.newsblur.network.APIManager;

public class ShareDialogFragment extends DialogFragment {

	private static final String STORY_ID = "story_id";
	private static final String FEED_ID = "feed_id";
	private static final String SOURCE_ID = "source_id";
	private static final String STORY_TITLE = "story_title";
	private static final String COMMENT = "comment";
	private APIManager apiManager;


	public static ShareDialogFragment newInstance(final String storyId, final String storyTitle, final String feedId, final String sourceUserId) {
		ShareDialogFragment frag = new ShareDialogFragment();
		Bundle args = new Bundle();
		args.putString(STORY_ID, storyId);
		args.putString(STORY_TITLE, storyTitle);
		args.putString(FEED_ID, feedId);
		args.putString(SOURCE_ID, sourceUserId);
		frag.setArguments(args);
		return frag;
	}	
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		setStyle(DialogFragment.STYLE_NO_TITLE, R.style.dialog);
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		final String shareString = getResources().getString(R.string.share_newsblur);
		
		apiManager = new APIManager(getActivity());
		View v = inflater.inflate(R.layout.fragment_dialog, container, false);
		final TextView message = (TextView) v.findViewById(R.id.dialog_message);
		final EditText comment = (EditText) v.findViewById(R.id.dialog_share_comment);
		message.setText(String.format(shareString, getArguments().getString(STORY_TITLE)));
		
		Button okayButton = (Button) v.findViewById(R.id.dialog_button_okay);
		okayButton.setOnClickListener(new OnClickListener() {
			public void onClick(final View v) {
				final String storyId = getArguments().getString(STORY_ID);
				final String feedId = getArguments().getString(FEED_ID);
				final String shareComment = comment.getText().toString();
				final String sourceId = getArguments().getString(SOURCE_ID);
				v.setEnabled(false);
				
				new AsyncTask<Void, Void, Boolean>() {
					@Override
					protected Boolean doInBackground(Void... arg) {
						return apiManager.shareStory(storyId, feedId, shareComment, sourceId);
					}
					
					@Override
					protected void onPostExecute(Boolean result) {
						if (result) {
							Toast.makeText(getActivity(), R.string.shared, Toast.LENGTH_LONG).show();
						} else {
							Toast.makeText(getActivity(), R.string.error_sharing, Toast.LENGTH_LONG).show();
						}
						v.setEnabled(true);
						ShareDialogFragment.this.dismiss();
					};
				}.execute();
			}
		});
		
		Button cancelButton = (Button) v.findViewById(R.id.dialog_button_cancel);
		cancelButton.setOnClickListener(new OnClickListener() {
			public void onClick(View v) {
				ShareDialogFragment.this.dismiss();
			}
		});

		return v;
	}

}
