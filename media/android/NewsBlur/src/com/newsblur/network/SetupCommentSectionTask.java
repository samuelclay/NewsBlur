package com.newsblur.network;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;

import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.os.AsyncTask;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentManager;
import android.support.v7.widget.GridLayout;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.Profile;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Reply;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;
import com.newsblur.fragment.ReplyDialogFragment;
import com.newsblur.fragment.ShareDialogFragment;
import com.newsblur.network.domain.ProfileResponse;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefsUtil;
import com.newsblur.util.UIUtils;

public class SetupCommentSectionTask extends AsyncTask<Void, Void, Void> {
	private ArrayList<View> publicCommentViews;
	private ArrayList<View> friendCommentViews;
	private final ContentResolver resolver;
	private final APIManager apiManager;

	private HashMap<String, UserProfile> friendUserMap = new HashMap<String, UserProfile>();
	private HashMap<String, UserProfile> publicUserMap = new HashMap<String, UserProfile>();
	private final Story story;
	private final LayoutInflater inflater;
	private final ImageLoader imageLoader;
	private WeakReference<View> viewHolder;
	private final Context context;
	private UserProfile user;
	private final FragmentManager manager;

	public SetupCommentSectionTask(final Context context, final View view, final FragmentManager manager, LayoutInflater inflater, final ContentResolver resolver, final APIManager apiManager, final Story story, final ImageLoader imageLoader) {
		this.context = context;
		this.manager = manager;
		this.inflater = inflater;
		this.resolver = resolver;
		this.apiManager = apiManager;
		this.story = story;
		this.imageLoader = imageLoader;
		viewHolder = new WeakReference<View>(view);
		user = PrefsUtil.getUserDetails(context);
	}

	@Override
	protected Void doInBackground(Void... arg0) {
		for (String userId : story.sharedUserIds) {
			ProfileResponse user = apiManager.getUser(userId);
			friendUserMap.put(userId, user.user);
		}

		for (String userId : story.friendUserIds) {
			ProfileResponse user = apiManager.getUser(userId);
			friendUserMap.put(userId, user.user);
		}

		for (String userId : story.publicUserIds) {
			ProfileResponse user = apiManager.getUser(userId);
			publicUserMap.put(userId, user.user);
		}

		Cursor cursor = resolver.query(FeedProvider.COMMENTS_URI, null, null, new String[] { story.id }, null);

		publicCommentViews = new ArrayList<View>();
		friendCommentViews = new ArrayList<View>();

		while (cursor.moveToNext()) {
			final Comment comment = Comment.fromCursor(cursor);
			View commentView = inflater.inflate(R.layout.include_comment, null);
			TextView commentText = (TextView) commentView.findViewById(R.id.comment_text);
			commentText.setText(comment.commentText);
			ImageView commentImage = (ImageView) commentView.findViewById(R.id.comment_user_image);
			TextView commentSharedDate = (TextView) commentView.findViewById(R.id.comment_shareddate);
			commentSharedDate.setText(comment.sharedDate);

			final TextView favouriteCount = (TextView) commentView.findViewById(R.id.comment_favourite_count);
			final ImageView favouriteIcon = (ImageView) commentView.findViewById(R.id.comment_favourite_icon);
			final ImageView replyIcon = (ImageView) commentView.findViewById(R.id.comment_reply_icon);
			
			if (comment.likingUsers != null) {
				if (Arrays.asList(comment.likingUsers).contains(user.id)) {
					favouriteIcon.setImageResource(R.drawable.have_favourite);
				}
				favouriteCount.setText(Integer.toString(comment.likingUsers.length));
				favouriteIcon.setOnClickListener(new OnClickListener() {
					@Override
					public void onClick(View v) {
						if (!Arrays.asList(comment.likingUsers).contains(user.id)) {
							new LikeCommentTask(context, apiManager, favouriteCount, favouriteIcon, story.id, comment, story.feedId, user.id).execute();
						} else {
							new UnLikeCommentTask(context, apiManager, favouriteCount, favouriteIcon, story.id, comment, story.feedId, user.id).execute();
						}
					}
				});
			}
			
			replyIcon.setOnClickListener(new OnClickListener() {
				@Override
				public void onClick(View v) {
					if (story != null) {
						DialogFragment newFragment = ReplyDialogFragment.newInstance(story.id, story.feedId, comment.userId, friendUserMap.get(comment.userId).username);
						newFragment.show(manager, "dialog");
					}
				}
			});
			
			
			Cursor replies = resolver.query(FeedProvider.REPLIES_URI, null, null, new String[] { comment.id }, DatabaseConstants.REPLY_DATE + " DESC");
			
			while (replies.moveToNext()) {
				Reply reply = Reply.fromCursor(replies);
				View replyView = inflater.inflate(R.layout.include_reply, null);
				TextView replyText = (TextView) replyView.findViewById(R.id.reply_text);
				replyText.setText(reply.text);
				ImageView replyImage = (ImageView) replyView.findViewById(R.id.reply_user_image);

				ProfileResponse replyUser = apiManager.getUser(reply.userId);
				imageLoader.displayImage(replyUser.user.photoUrl, replyImage);
				TextView replyUsername = (TextView) replyView.findViewById(R.id.reply_username);
				replyUsername.setText(replyUser.user.username);

				TextView replySharedDate = (TextView) replyView.findViewById(R.id.reply_shareddate);
				replySharedDate.setText(reply.shortDate);

				((LinearLayout) commentView.findViewById(R.id.comment_replies_container)).addView(replyView);
			}

			if (publicUserMap.containsKey(comment.userId)) {
				UserProfile commentUser = publicUserMap.get(comment.userId);
				TextView commentUsername = (TextView) commentView.findViewById(R.id.comment_username);
				commentUsername.setText(commentUser.username);
				String userPhoto = commentUser.photoUrl;
				imageLoader.displayImage(userPhoto, commentImage);
				publicCommentViews.add(commentView);
			} else {
				UserProfile commentUser = friendUserMap.get(comment.userId);
				if (commentUser != null) {
					TextView commentUsername = (TextView) commentView.findViewById(R.id.comment_username);
					commentUsername.setText(commentUser.username);
					String userPhoto = commentUser.photoUrl;
					imageLoader.displayImage(userPhoto, commentImage);
					friendCommentViews.add(commentView);
				}
			}
		}
		return null;
	}

	protected void onPostExecute(Void result) {
		if (viewHolder.get() != null) {
			GridLayout grid = (GridLayout) viewHolder.get().findViewById(R.id.reading_social_shareimages);
			GridLayout friendGrid = (GridLayout) viewHolder.get().findViewById(R.id.reading_social_friendimages);

			for (final String userId : story.publicUserIds) {
				ImageView image = new ImageView(context);
				int imageLength = UIUtils.convertDPsToPixels(context, 25);
				image.setMaxHeight(imageLength);
				image.setMaxWidth(imageLength);
				GridLayout.LayoutParams imageParameters = new GridLayout.LayoutParams();
				imageParameters.height = imageLength;
				imageParameters.width = imageLength;
				image.setLayoutParams(imageParameters);

				imageLoader.displayImageByUid(publicUserMap.get(userId).photoUrl, image);
				image.setOnClickListener(new OnClickListener() {
					@Override
					public void onClick(View view) {
						Intent i = new Intent(context, Profile.class);
						i.putExtra(Profile.USER_ID, userId);
						context.startActivity(i);
					}
				});
				grid.addView(image);
			}

			for (final String userId : story.friendUserIds) {
				ImageView image = new ImageView(context);
				int imageLength = UIUtils.convertDPsToPixels(context, 25);
				image.setMaxHeight(imageLength);
				image.setMaxWidth(imageLength);
				GridLayout.LayoutParams imageParameters = new GridLayout.LayoutParams();
				imageParameters.height = imageLength;
				imageParameters.width = imageLength;
				image.setLayoutParams(imageParameters);

				imageLoader.displayImageByUid(friendUserMap.get(userId).photoUrl, image);
				image.setOnClickListener(new OnClickListener() {
					@Override
					public void onClick(View view) {
						Intent i = new Intent(context, Profile.class);
						i.putExtra(Profile.USER_ID, userId);
						context.startActivity(i);
					}
				});
				friendGrid.addView(image);
			}
			
			for (View comment : publicCommentViews) {
				((LinearLayout) viewHolder.get().findViewById(R.id.reading_public_comment_container)).addView(comment);
			}
			for (View comment : friendCommentViews) {
				((LinearLayout) viewHolder.get().findViewById(R.id.reading_friend_comment_container)).addView(comment);
			}
		}
	}
}


