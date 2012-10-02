package com.newsblur.network;

import java.lang.ref.WeakReference;
import java.util.ArrayList;

import android.content.Context;
import android.os.AsyncTask;
import android.text.TextUtils;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.domain.Comment;
import com.newsblur.domain.UserDetails;
import com.newsblur.util.PrefsUtils;
import com.newsblur.view.FlowLayout;

public class UnLikeCommentTask extends AsyncTask<Void, Void, Boolean>{
	
	private static final String TAG = "LikeCommentTask";
	final WeakReference<ImageView> favouriteIconViewHolder;
	private final APIManager apiManager;
	private final String storyId;
	private final Comment comment;
	private final String feedId;
	private final Context context;
	private final String userId;
	private WeakReference<FlowLayout> favouriteAvatarHolder;
	private UserDetails user;
	
	public UnLikeCommentTask(final Context context, final APIManager apiManager, final ImageView favouriteIcon, final FlowLayout favouriteAvatarContainer, final String storyId, final Comment comment, final String feedId, final String userId) {
		this.apiManager = apiManager;
		this.storyId = storyId;
		this.comment = comment;
		this.feedId = feedId;
		this.context = context;
		this.userId = userId;
		
		favouriteIconViewHolder = new WeakReference<ImageView>(favouriteIcon);
		favouriteAvatarHolder = new WeakReference<FlowLayout>(favouriteAvatarContainer);

		user = PrefsUtils.getUserDetails(context);
	}
	
	@Override
	protected Boolean doInBackground(Void... params) {
		return apiManager.unFavouriteComment(storyId, comment.userId, feedId);
	}
	
	@Override
	protected void onPostExecute(Boolean result) {
		if (favouriteIconViewHolder.get() != null) {
			if (result.booleanValue()) {
				favouriteIconViewHolder.get().setImageResource(R.drawable.favourite);
				
				View v = favouriteAvatarHolder.get().findViewWithTag(user.id);
				favouriteAvatarHolder.get().removeView(v);
				
				ArrayList<String> likingUsers = new ArrayList<String>();
				for (String user : comment.likingUsers) {
					if (!TextUtils.equals(user, userId) && TextUtils.isEmpty(user)) {
						likingUsers.add(user);
					}
				}
				String[] newArray = new String[likingUsers.size()];
				likingUsers.toArray(newArray);
				comment.likingUsers = newArray;
				
				Toast.makeText(context, "Removed like", Toast.LENGTH_SHORT).show();
			} else {
				Toast.makeText(context, "Error removing like from comment", Toast.LENGTH_SHORT).show();
			}
		}
	}
}
