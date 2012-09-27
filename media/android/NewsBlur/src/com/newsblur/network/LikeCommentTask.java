package com.newsblur.network;

import java.lang.ref.WeakReference;

import android.content.Context;
import android.os.AsyncTask;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.domain.Comment;

public class LikeCommentTask extends AsyncTask<Void, Void, Boolean>{
	
	private static final String TAG = "LikeCommentTask";
	final WeakReference<ImageView> favouriteIconViewHolder;
	
	private final APIManager apiManager;
	private final String storyId;
	private final Comment comment;
	private final String feedId;
	private final Context context;
	private final String userId;
	
	public LikeCommentTask(final Context context, final APIManager apiManager, final ImageView favouriteIcon, final String storyId, final Comment comment, final String feedId, final String userId) {
		this.apiManager = apiManager;
		this.storyId = storyId;
		this.comment = comment;
		this.feedId = feedId;
		this.context = context;
		this.userId = userId;
		
		favouriteIconViewHolder = new WeakReference<ImageView>(favouriteIcon);
	}
	
	@Override
	protected Boolean doInBackground(Void... params) {
		return apiManager.favouriteComment(storyId, comment.userId, feedId);
	}
	
	@Override
	protected void onPostExecute(Boolean result) {
		if (favouriteIconViewHolder.get() != null) {
			if (result.booleanValue()) {
				favouriteIconViewHolder.get().setImageResource(R.drawable.have_favourite);
				
				String[] newArray = new String[comment.likingUsers.length + 1];
				System.arraycopy(comment.likingUsers, 0, newArray, 0, comment.likingUsers.length);
				newArray[newArray.length - 1] = userId;
				comment.likingUsers = newArray;
				
				Toast.makeText(context, R.string.comment_favourited, Toast.LENGTH_SHORT).show();
			} else {
				Toast.makeText(context, R.string.error_liking_comment, Toast.LENGTH_SHORT).show();
			}
		}
	}
}
