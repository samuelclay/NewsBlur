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
import android.text.TextUtils;
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
import com.newsblur.network.domain.ProfileResponse;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ViewUtils;

public class SetupCommentSectionTask extends AsyncTask<Void, Void, Void> {
	public static final String COMMENT_BY = "commentBy";
	public static final String COMMENT_DATE_BY = "commentDateBy";
	public static final String COMMENT_VIEW_BY = "commentViewBy";
	
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
	private Cursor commentCursor;

	public SetupCommentSectionTask(final Context context, final View view, final FragmentManager manager, LayoutInflater inflater, final ContentResolver resolver, final APIManager apiManager, final Story story, final ImageLoader imageLoader) {
		this.context = context;
		this.manager = manager;
		this.inflater = inflater;
		this.resolver = resolver;
		this.apiManager = apiManager;
		this.story = story;
		this.imageLoader = imageLoader;
		viewHolder = new WeakReference<View>(view);
		user = PrefsUtils.getUserDetails(context);
	}

	@Override
	protected Void doInBackground(Void... arg0) {
		
		for (String userId : story.friendUserIds) {
			ProfileResponse user = apiManager.getUser(userId);
			friendUserMap.put(userId, user.user);
		}
		
		for (String userId : story.publicUserIds) {
			ProfileResponse user = apiManager.getUser(userId);
			publicUserMap.put(userId, user.user);
		}

		for (String userId : story.sharedUserIds) {
			if (!publicUserMap.containsKey(userId) && !friendUserMap.containsKey(userId)) {
				ProfileResponse user = apiManager.getUser(userId);
				publicUserMap.put(userId, user.user);
			}
		}

		commentCursor = resolver.query(FeedProvider.COMMENTS_URI, null, null, new String[] { story.id }, null);

		publicCommentViews = new ArrayList<View>();
		friendCommentViews = new ArrayList<View>();

		while (commentCursor.moveToNext()) {
			final Comment comment = Comment.fromCursor(commentCursor);
			View commentView = inflater.inflate(R.layout.include_comment, null);
			commentView.setTag(COMMENT_VIEW_BY + comment.userId);
			
			TextView commentText = (TextView) commentView.findViewById(R.id.comment_text);
			commentText.setText(comment.commentText);
			commentText.setTag(COMMENT_BY + comment.userId);
			
			ImageView commentImage = (ImageView) commentView.findViewById(R.id.comment_user_image);
			
			TextView commentSharedDate = (TextView) commentView.findViewById(R.id.comment_shareddate);
			commentSharedDate.setText(comment.sharedDate);
			commentSharedDate.setTag(COMMENT_DATE_BY + comment.userId);

			final LinearLayout favouriteContainer = (LinearLayout) commentView.findViewById(R.id.comment_favourite_avatars);
			final ImageView favouriteIcon = (ImageView) commentView.findViewById(R.id.comment_favourite_icon);
			final ImageView replyIcon = (ImageView) commentView.findViewById(R.id.comment_reply_icon);
			
			if (comment.likingUsers != null) {
				if (Arrays.asList(comment.likingUsers).contains(user.id)) {
					favouriteIcon.setImageResource(R.drawable.have_favourite);
				}
				
				for (String id : comment.likingUsers) {
					ImageView favouriteImage = new ImageView(context);
					UserProfile favouriteUser = null;
					
					if (publicUserMap.containsKey(id)) {
						favouriteUser = publicUserMap.get(id);
					} else if (friendUserMap.containsKey(id)) {
						favouriteUser = friendUserMap.get(id);
					} else {
						favouriteUser = apiManager.getUser(id).user;
					}
					
					imageLoader.displayImage(favouriteUser.photoUrl, favouriteImage);
					favouriteContainer.addView(favouriteImage);
				}
				
				favouriteIcon.setOnClickListener(new OnClickListener() {
					@Override
					public void onClick(View v) {
						if (!Arrays.asList(comment.likingUsers).contains(user.id)) {
							new LikeCommentTask(context, apiManager, favouriteIcon, story.id, comment, story.feedId, user.id).execute();
						} else {
							new UnLikeCommentTask(context, apiManager, favouriteIcon, story.id, comment, story.feedId, user.id).execute();
						}
					}
				});
			}
			
			replyIcon.setOnClickListener(new OnClickListener() {
				@Override
				public void onClick(View v) {
					if (story != null) {
						DialogFragment newFragment = ReplyDialogFragment.newInstance(story, comment.userId, publicUserMap.get(comment.userId).username);
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

				final ProfileResponse replyUser = apiManager.getUser(reply.userId);
				imageLoader.displayImage(replyUser.user.photoUrl, replyImage);
				replyImage.setOnClickListener(new OnClickListener() {
					@Override
					public void onClick(View view) {
						Intent i = new Intent(context, Profile.class);
						i.putExtra(Profile.USER_ID, replyUser.user.userId);
						context.startActivity(i);
					}
				});
				
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
				
				if (!TextUtils.isEmpty(comment.sourceUserId)) {
					commentImage.setVisibility(View.INVISIBLE);
					ImageView usershareImage = (ImageView) commentView.findViewById(R.id.comment_user_reshare_image);
					ImageView sourceUserImage = (ImageView) commentView.findViewById(R.id.comment_sharesource_image);
					sourceUserImage.setVisibility(View.VISIBLE);
					usershareImage.setVisibility(View.VISIBLE);
					commentImage.setVisibility(View.INVISIBLE);
					
					UserProfile user;
					if (publicUserMap.containsKey(comment.sourceUserId)) {
						user = publicUserMap.get(comment.sourceUserId);
					} else {
						user = friendUserMap.get(comment.sourceUserId);
					}
					
					imageLoader.displayImage(user.photoUrl, sourceUserImage);
					imageLoader.displayImage(userPhoto, usershareImage);
				} else {
					imageLoader.displayImage(userPhoto, commentImage);
				}
				
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
			
			commentImage.setOnClickListener(new OnClickListener() {
				@Override
				public void onClick(View view) {
					Intent i = new Intent(context, Profile.class);
					i.putExtra(Profile.USER_ID, comment.userId);
					context.startActivity(i);
				}
			});
			
		}
		return null;
	}

	protected void onPostExecute(Void result) {
		if (viewHolder.get() != null) {
			GridLayout sharedGrid = (GridLayout) viewHolder.get().findViewById(R.id.reading_social_shareimages);
			GridLayout commentGrid = (GridLayout) viewHolder.get().findViewById(R.id.reading_social_commentimages);

			ViewUtils.setupCommentCount(context, viewHolder.get(), commentCursor.getCount());
			ViewUtils.setupShareCount(context, viewHolder.get(), story.sharedUserIds.length);
			
			for (final String userId : story.publicUserIds) {
				ImageView image = ViewUtils.createSharebarImage(context, imageLoader, publicUserMap.get(userId));
				sharedGrid.addView(image);
			}

			commentCursor.moveToFirst();
			
			for (int i = 0; i < commentCursor.getCount(); i++) {
				final Comment comment = Comment.fromCursor(commentCursor);
				UserProfile user;
				if ((user = publicUserMap.get(comment.userId)) == null) {
					user = friendUserMap.get(comment.userId);
				}
				ImageView image = ViewUtils.createSharebarImage(context, imageLoader, user);
				commentGrid.addView(image);
				commentCursor.moveToNext();
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


