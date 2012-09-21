package com.newsblur.fragment;

import java.io.Serializable;

import android.content.ContentResolver;
import android.database.Cursor;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.text.Editable;
import android.text.TextUtils;
import android.text.TextWatcher;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;
import com.newsblur.network.APIManager;
import com.newsblur.util.PrefsUtils;

public class ShareDialogFragment extends DialogFragment {

	private static final String STORY = "story";
	private static final String CALLBACK= "callback";
	private static final String PREVIOUSLY_SAVED_SHARE_TEXT = "previouslySavedComment";
	private APIManager apiManager;
	private SharedCallbackDialog callback;
	private Story story;
	private UserProfile user;
	private ContentResolver resolver;
	private boolean hasBeenShared = false;
	private Cursor commentCursor;
	private Comment previousComment;
	private String previouslySavedShareText;
	private boolean hasShared = false;
	private EditText commentEditText;

	public static ShareDialogFragment newInstance(final SharedCallbackDialog sharedCallback, final Story story, final String previouslySavedShareText) {
		ShareDialogFragment frag = new ShareDialogFragment();
		Bundle args = new Bundle();
		args.putSerializable(STORY, story);
		args.putString(PREVIOUSLY_SAVED_SHARE_TEXT, previouslySavedShareText);
		args.putSerializable(CALLBACK, sharedCallback);
		frag.setArguments(args);
		return frag;
	}	

	@Override
	public void onCreate(Bundle savedInstanceState) {
		setStyle(DialogFragment.STYLE_NO_TITLE, R.style.dialog);
		super.onCreate(savedInstanceState);
		story = (Story) getArguments().getSerializable(STORY);
		callback = (SharedCallbackDialog) getArguments().getSerializable(CALLBACK);
		user = PrefsUtils.getUserDetails(getActivity());
		previouslySavedShareText = getArguments().getString(PREVIOUSLY_SAVED_SHARE_TEXT);
		
		apiManager = new APIManager(getActivity());
		resolver = getActivity().getContentResolver();

		for (String sharedUserId : story.sharedUserIds) {
			if (TextUtils.equals(user.id, sharedUserId)) {
				hasBeenShared = true;
				break;
			}
		}
		
		if (hasBeenShared) {
			commentCursor = resolver.query(FeedProvider.COMMENTS_URI, null, null, new String[] { story.id, user.id }, null);
			commentCursor.moveToFirst();
			previousComment = Comment.fromCursor(commentCursor);
		}
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		final String shareString = getResources().getString(R.string.share_newsblur);

		View v = inflater.inflate(R.layout.fragment_dialog, container, false);
		final TextView message = (TextView) v.findViewById(R.id.dialog_message);
		commentEditText = (EditText) v.findViewById(R.id.dialog_share_comment);
		final Button shareButton = (Button) v.findViewById(R.id.dialog_button_okay);
		shareButton.setText(R.string.share_this_story);
		
		commentEditText.addTextChangedListener(new TextWatcher() {
			@Override
			public void afterTextChanged(Editable editable) {
				if (editable.length() > 0) {
					shareButton.setText(R.string.share_with_comments);
				} else {
					shareButton.setText(R.string.share_this_story);
				}
			}

			@Override
			public void beforeTextChanged(CharSequence s, int start, int count, int after) { }

			@Override
			public void onTextChanged(CharSequence s, int start, int before, int count) { }
		});
		
		message.setText(String.format(shareString, story.title));

		if (hasBeenShared) {
			shareButton.setText(R.string.edit);
			commentEditText.setText(previousComment.commentText);
		} else if (!TextUtils.isEmpty(previouslySavedShareText)) {
			commentEditText.setText(previouslySavedShareText);
		}

		Button okayButton = (Button) v.findViewById(R.id.dialog_button_okay);
		okayButton.setOnClickListener(new OnClickListener() {
			public void onClick(final View v) {
				final String shareComment = commentEditText.getText().toString();
				v.setEnabled(false);

				new AsyncTask<Void, Void, Boolean>() {
					@Override
					protected Boolean doInBackground(Void... arg) {
						return apiManager.shareStory(story.id, story.feedId, shareComment, story.sourceUserId);
					}

					@Override
					protected void onPostExecute(Boolean result) {
						if (result) {
							hasShared = true;
							callback.sharedCallback(shareComment, hasBeenShared);
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
	
	@Override
	public void onDestroy() {
		if (commentCursor != null && !commentCursor.isClosed()) {
			commentCursor.close();
		}
		
		if (!hasShared && commentEditText.length() > 0) {
			Log.d("ShareDialog", "settingPreviouslySharedText");
			previouslySavedShareText = commentEditText.getText().toString();
			callback.setPreviouslySavedShareText(previouslySavedShareText);
		}
		super.onDestroy();
	}

	public interface SharedCallbackDialog extends Serializable{
		public void setPreviouslySavedShareText(String previouslySavedShareText);
		public void sharedCallback(String sharedText, boolean alreadyShared);
	}

}
