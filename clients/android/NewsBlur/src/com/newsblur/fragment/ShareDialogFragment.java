package com.newsblur.fragment;

import java.io.Serializable;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.DialogFragment;
import android.text.Html;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.EditText;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.network.APIManager;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

public class ShareDialogFragment extends DialogFragment {

	private static final String STORY = "story";
	private static final String CALLBACK= "callback";
	private static final String PREVIOUSLY_SAVED_SHARE_TEXT = "previouslySavedComment";
    private static final String SOURCE_USER_ID = "sourceUserId";
    private APIManager apiManager;
	private SharedCallbackDialog callback;
	private Story story;
	private UserDetails user;
	private boolean hasBeenShared = false;
	private Comment previousComment;
	private String previouslySavedShareText;
	private boolean hasShared = false;
    private EditText commentEditText;
    private String sourceUserId;

	public static ShareDialogFragment newInstance(final SharedCallbackDialog sharedCallback, final Story story, final String previouslySavedShareText, final String sourceUserId) {
		ShareDialogFragment frag = new ShareDialogFragment();
		Bundle args = new Bundle();
		args.putSerializable(STORY, story);
		args.putString(PREVIOUSLY_SAVED_SHARE_TEXT, previouslySavedShareText);
		args.putSerializable(CALLBACK, sharedCallback);
        args.putString(SOURCE_USER_ID, sourceUserId);
		frag.setArguments(args);
		return frag;
	}

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {

        final Activity activity = getActivity();
        story = (Story) getArguments().getSerializable(STORY);
        callback = (SharedCallbackDialog) getArguments().getSerializable(CALLBACK);
        user = PrefsUtils.getUserDetails(activity);
        previouslySavedShareText = getArguments().getString(PREVIOUSLY_SAVED_SHARE_TEXT);
        sourceUserId = getArguments().getString(SOURCE_USER_ID);

        apiManager = new APIManager(getActivity());

        for (String sharedUserId : story.sharedUserIds) {
            if (TextUtils.equals(user.id, sharedUserId)) {
                hasBeenShared = true;
                break;
            }
        }

        if (hasBeenShared) {
            previousComment = FeedUtils.dbHelper.getComment(story.id, user.id);
        }

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        final String shareString = getResources().getString(R.string.share_newsblur);
        builder.setTitle(String.format(shareString, Html.fromHtml(story.title)));

        LayoutInflater layoutInflater = LayoutInflater.from(activity);
        View replyView = layoutInflater.inflate(R.layout.share_dialog, null);
        builder.setView(replyView);
        commentEditText = (EditText) replyView.findViewById(R.id.comment_field);

        int positiveButtonText = R.string.share_this_story;
        if (hasBeenShared) {
            positiveButtonText = R.string.update_shared;
            if (previousComment != null ) {
                commentEditText.setText(previousComment.commentText);
            }
        } else if (!TextUtils.isEmpty(previouslySavedShareText)) {
            commentEditText.setText(previouslySavedShareText);
        }

        builder.setPositiveButton(positiveButtonText, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {

                final String shareComment = commentEditText.getText().toString();

                new AsyncTask<Void, Void, Boolean>() {
                    @Override
                    protected Boolean doInBackground(Void... arg) {
                        // If story.sourceUsedId is set then we should use that as the sourceUserId for the share.
                        // Otherwise, use the sourceUsedId passed to the fragment.
                        if (story.sourceUserId == null) {
                            return apiManager.shareStory(story.id, story.feedId, shareComment, sourceUserId);
                        } else {
                            return apiManager.shareStory(story.id, story.feedId, shareComment, story.sourceUserId);
                        }
                    }

                    @Override
                    protected void onPostExecute(Boolean result) {
                        if (result) {
                            hasShared = true;
                            UIUtils.safeToast(activity, R.string.shared, Toast.LENGTH_LONG);
                            callback.sharedCallback(shareComment, hasBeenShared);
                        } else {
                            UIUtils.safeToast(activity, R.string.error_sharing, Toast.LENGTH_LONG);
                        }

                        ShareDialogFragment.this.dismiss();
                    };
                }.execute();
            }
        });
        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                ShareDialogFragment.this.dismiss();
            }
        });
        return builder.create();
    }
	
	@Override
	public void onDestroy() {
		if (!hasShared && commentEditText.length() > 0) {
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
