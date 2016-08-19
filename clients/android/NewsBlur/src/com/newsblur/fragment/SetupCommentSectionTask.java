package com.newsblur.fragment;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.app.DialogFragment;
import android.app.FragmentManager;
import android.text.Html;
import android.text.TextUtils;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.Profile;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Reply;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserDetails;
import com.newsblur.domain.UserProfile;
import com.newsblur.fragment.ReplyDialogFragment;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ViewUtils;
import com.newsblur.view.FlowLayout;

public class SetupCommentSectionTask extends AsyncTask<Void, Void, Void> {

    private ArrayList<View> topCommentViews;
    private ArrayList<View> topShareViews;

	private ArrayList<View> publicCommentViews;
	private ArrayList<View> friendCommentViews;
	private ArrayList<View> friendShareViews;

    private final ReadingItemFragment fragment;
	private final Story story;
	private final LayoutInflater inflater;
	private WeakReference<View> viewHolder;
	private final Context context;
	private UserDetails user;
	private final FragmentManager manager;
	private List<Comment> comments;

	public SetupCommentSectionTask(ReadingItemFragment fragment, View view, LayoutInflater inflater, Story story) {
        this.fragment = fragment;
		this.context = fragment.getActivity();
		this.manager = fragment.getFragmentManager();
		this.inflater = inflater;
		this.story = story;
		viewHolder = new WeakReference<View>(view);
		user = PrefsUtils.getUserDetails(context);
	}

    /**
     * Do all the DB access and image view creation in the async portion of the task, saving the views in local members.
     */
	@Override
	protected Void doInBackground(Void... arg0) {
        if (context == null) return null;
        comments = FeedUtils.dbHelper.getComments(story.id);

        topCommentViews = new ArrayList<View>();
        topShareViews = new ArrayList<View>();
		publicCommentViews = new ArrayList<View>();
		friendCommentViews = new ArrayList<View>();
		friendShareViews = new ArrayList<View>();

        // users by whom we saw non-pseudo comments
        Set<String> commentingUserIds = new HashSet<String>();
        // users by whom we saw shares
        Set<String> sharingUserIds = new HashSet<String>();

		for (final Comment comment : comments) {
			// skip public comments if they are disabled
			if (!comment.byFriend && !PrefsUtils.showPublicComments(context)) {
			    continue;
			}

			UserProfile commentUser = FeedUtils.dbHelper.getUserProfile(comment.userId);
            // rarely, we get a comment but never got the user's profile, so we can't display it
            if (commentUser == null) {
                Log.w(this.getClass().getName(), "cannot display comment from missing user ID: " + comment.userId);
                continue;
            }

			View commentView = inflater.inflate(R.layout.include_comment, null);
			TextView commentText = (TextView) commentView.findViewById(R.id.comment_text);
			commentText.setText(Html.fromHtml(comment.commentText));
			ImageView commentImage = (ImageView) commentView.findViewById(R.id.comment_user_image);

			TextView commentSharedDate = (TextView) commentView.findViewById(R.id.comment_shareddate);
            // TODO: this uses hard-coded "ago" values, which will be wrong when reading prefetched stories
            if (comment.sharedDate != null) {
			    commentSharedDate.setText(comment.sharedDate + " ago");
            }

			final FlowLayout favouriteContainer = (FlowLayout) commentView.findViewById(R.id.comment_favourite_avatars);
			final ImageView favouriteIcon = (ImageView) commentView.findViewById(R.id.comment_favourite_icon);
			final ImageView replyIcon = (ImageView) commentView.findViewById(R.id.comment_reply_icon);

			if (comment.likingUsers != null) {
				if (Arrays.asList(comment.likingUsers).contains(user.id)) {
					favouriteIcon.setImageResource(R.drawable.have_favourite);
				}

				for (String id : comment.likingUsers) {
					ImageView favouriteImage = new ImageView(context);
					UserProfile user = FeedUtils.dbHelper.getUserProfile(id);
                    if (user != null) {
                        FeedUtils.iconLoader.displayImage(user.photoUrl, favouriteImage, 10f, false);
                        favouriteContainer.addView(favouriteImage);
                    }
				}

                // users cannot fave their own comments.  attempting to do so will actually queue a fatally invalid API call
                if (TextUtils.equals(comment.userId, user.id)) {
                    favouriteIcon.setVisibility(View.GONE);
                } else {
                    favouriteIcon.setOnClickListener(new OnClickListener() {
                        @Override
                        public void onClick(View v) {
                            if (!Arrays.asList(comment.likingUsers).contains(user.id)) {
                                FeedUtils.likeComment(story, comment.userId, context);
                            } else {
                                FeedUtils.unlikeComment(story, comment.userId, context);
                            }
                        }
                    });
                }
			}

			replyIcon.setOnClickListener(new OnClickListener() {
				@Override
				public void onClick(View v) {
					if (story != null) {
						UserProfile user = FeedUtils.dbHelper.getUserProfile(comment.userId);
                        if (user != null) {
                            DialogFragment newFragment = ReplyDialogFragment.newInstance(story, comment.userId, user.username);
                            newFragment.show(manager, "dialog");
                        }
					}
				}
			});

            List<Reply> replies = FeedUtils.dbHelper.getCommentReplies(comment.id);
			for (Reply reply : replies) {
				View replyView = inflater.inflate(R.layout.include_reply, null);
				TextView replyText = (TextView) replyView.findViewById(R.id.reply_text);
				replyText.setText(Html.fromHtml(reply.text));
				ImageView replyImage = (ImageView) replyView.findViewById(R.id.reply_user_image);

                final UserProfile replyUser = FeedUtils.dbHelper.getUserProfile(reply.userId);
				if (replyUser != null) {
					FeedUtils.iconLoader.displayImage(replyUser.photoUrl, replyImage, 5, false);
					replyImage.setOnClickListener(new OnClickListener() {
						@Override
						public void onClick(View view) {
							Intent i = new Intent(context, Profile.class);
							i.putExtra(Profile.USER_ID, replyUser.userId);
							context.startActivity(i);
						}
					});
					
					TextView replyUsername = (TextView) replyView.findViewById(R.id.reply_username);
					replyUsername.setText(replyUser.username);
				} else {
					TextView replyUsername = (TextView) replyView.findViewById(R.id.reply_username);
					replyUsername.setText(R.string.unknown_user);
				}
				
                if (reply.shortDate != null) {
                    TextView replySharedDate = (TextView) replyView.findViewById(R.id.reply_shareddate);
                    replySharedDate.setText(reply.shortDate + " ago");
                }

				((LinearLayout) commentView.findViewById(R.id.comment_replies_container)).addView(replyView);
			}

			TextView commentUsername = (TextView) commentView.findViewById(R.id.comment_username);
			commentUsername.setText(commentUser.username);
			String userPhoto = commentUser.photoUrl;

            TextView commentLocation = (TextView) commentView.findViewById(R.id.comment_location);
            if (!TextUtils.isEmpty(commentUser.location)) {
                commentLocation.setText(commentUser.location.toUpperCase());
            } else {
                commentLocation.setVisibility(View.GONE);
            }

            if (!TextUtils.isEmpty(comment.sourceUserId)) {
				commentImage.setVisibility(View.INVISIBLE);
				ImageView usershareImage = (ImageView) commentView.findViewById(R.id.comment_user_reshare_image);
				ImageView sourceUserImage = (ImageView) commentView.findViewById(R.id.comment_sharesource_image);
				sourceUserImage.setVisibility(View.VISIBLE);
				usershareImage.setVisibility(View.VISIBLE);
				commentImage.setVisibility(View.INVISIBLE);


                UserProfile sourceUser = FeedUtils.dbHelper.getUserProfile(comment.sourceUserId);
				if (sourceUser != null) {
					FeedUtils.iconLoader.displayImage(sourceUser.photoUrl, sourceUserImage, 10f, false);
					FeedUtils.iconLoader.displayImage(userPhoto, usershareImage, 10f, false);
				}
			} else {
				FeedUtils.iconLoader.displayImage(userPhoto, commentImage, 10f, false);
			}

			commentImage.setOnClickListener(new OnClickListener() {
				@Override
				public void onClick(View view) {
					Intent i = new Intent(context, Profile.class);
					i.putExtra(Profile.USER_ID, comment.userId);
					context.startActivity(i);
				}
			});

			if (comment.isPseudo) {
                friendShareViews.add(commentView);
                sharingUserIds.add(comment.userId);
            } else if (comment.byFriend) {
				friendCommentViews.add(commentView);
			} else {
				publicCommentViews.add(commentView);
			}

            // for actual comments, also populate the upper icon bar
            if (!comment.isPseudo) {
                ImageView image = ViewUtils.createSharebarImage(context, commentUser.photoUrl, commentUser.userId);
                topCommentViews.add(image);
                commentingUserIds.add(comment.userId);
            }
		}

        // the story object supplements the pseudo-comment share list
        for (String userId : story.sharedUserIds) {
            // for the purpose of this top-line share list, exclude non-pseudo comments
            if (!commentingUserIds.contains(userId)) {
                sharingUserIds.add(userId);
            }
        }

        // now that we have all shares from the comments table and story object, populate the shares row
        for (String userId : sharingUserIds) {
            UserProfile user = FeedUtils.dbHelper.getUserProfile(userId);
            if (user == null) {
                Log.w(this.getClass().getName(), "cannot display share from missing user ID: " + userId);
                continue;
            }
            ImageView image = ViewUtils.createSharebarImage(context, user.photoUrl, user.userId);
            topShareViews.add(image);
        }

		return null;
	}

    /**
     * Push all the pre-created views into the actual UI.
     */
	protected void onPostExecute(Void result) {
        if (context == null) return;
        View view = viewHolder.get();
		if (view == null) return; // fragment was dismissed before we rendered

        TextView headerCommentTotal = (TextView) view.findViewById(R.id.comment_by);
        TextView headerShareTotal = (TextView) view.findViewById(R.id.shared_by);

        FlowLayout sharedGrid = (FlowLayout) view.findViewById(R.id.reading_social_shareimages);
        FlowLayout commentGrid = (FlowLayout) view.findViewById(R.id.reading_social_commentimages);

        TextView friendCommentTotal = ((TextView) view.findViewById(R.id.reading_friend_comment_total));
        TextView friendShareTotal = ((TextView) view.findViewById(R.id.reading_friend_emptyshare_total));
        TextView publicCommentTotal = ((TextView) view.findViewById(R.id.reading_public_comment_total));
        
        int publicCommentCount = publicCommentViews.size();
        int friendCommentCount = friendCommentViews.size();
        int friendShareCount = friendShareViews.size();

        int allCommentCount = topCommentViews.size();
        int allShareCount = topShareViews.size();

        if (allCommentCount > 0 || allShareCount > 0) {
            view.findViewById(R.id.reading_share_bar).setVisibility(View.VISIBLE);
            view.findViewById(R.id.share_bar_underline).setVisibility(View.VISIBLE);
        } else {
            view.findViewById(R.id.reading_share_bar).setVisibility(View.GONE);
            view.findViewById(R.id.share_bar_underline).setVisibility(View.GONE);
        }

        sharedGrid.removeAllViews();
        for (View image : topShareViews) {
            sharedGrid.addView(image);
        }

        commentGrid.removeAllViews();
        for (View image : topCommentViews) {
            commentGrid.addView(image);
        }

        if (allCommentCount > 0) {
            String countText = context.getString(R.string.friends_comments_count);
            if (allCommentCount == 1) {
                countText = countText.substring(0, countText.length() - 1);
            }
            headerCommentTotal.setText(String.format(countText, allCommentCount));
            headerCommentTotal.setVisibility(View.VISIBLE);
        } else {
            headerCommentTotal.setVisibility(View.GONE);
        }

        if (allShareCount > 0) {
            String countText = context.getString(R.string.friends_shares_count);
            if (allShareCount == 1) {
                countText = countText.substring(0, countText.length() - 1);
            }
            headerShareTotal.setText(String.format(countText, allShareCount));
            headerShareTotal.setVisibility(View.VISIBLE);
        } else {
            headerShareTotal.setVisibility(View.GONE);
        }

        if (publicCommentCount > 0) {
            String commentCount = context.getString(R.string.public_comment_count);
            if (publicCommentCount == 1) {
                commentCount = commentCount.substring(0, commentCount.length() - 1);
            }
            publicCommentTotal.setText(String.format(commentCount, publicCommentCount));
            view.findViewById(R.id.reading_public_comment_header).setVisibility(View.VISIBLE);
        } else {
            view.findViewById(R.id.reading_public_comment_header).setVisibility(View.GONE);
        }
        
        if (friendCommentCount > 0) {
            String commentCount = context.getString(R.string.friends_comments_count);
            if (friendCommentCount == 1) {
                commentCount = commentCount.substring(0, commentCount.length() - 1);
            }
            friendCommentTotal.setText(String.format(commentCount, friendCommentCount));
            view.findViewById(R.id.reading_friend_comment_header).setVisibility(View.VISIBLE);
        } else {
            view.findViewById(R.id.reading_friend_comment_header).setVisibility(View.GONE);
        }

        if (friendShareCount > 0) {
            String commentCount = context.getString(R.string.friends_shares_count);
            if (friendShareCount == 1) {
                commentCount = commentCount.substring(0, commentCount.length() - 1);
            }
            friendShareTotal.setText(String.format(commentCount, friendShareCount));
            view.findViewById(R.id.reading_friend_emptyshare_header).setVisibility(View.VISIBLE);
        } else {
            view.findViewById(R.id.reading_friend_emptyshare_header).setVisibility(View.GONE);
        }

        LinearLayout publicCommentListContainer = (LinearLayout) view.findViewById(R.id.reading_public_comment_container);
        publicCommentListContainer.removeAllViews();
        for (int i = 0; i < publicCommentViews.size(); i++) {
            if (i == publicCommentViews.size() - 1) {
                publicCommentViews.get(i).findViewById(R.id.comment_divider).setVisibility(View.GONE);
            }
            publicCommentListContainer.addView(publicCommentViews.get(i));
        }
        
        LinearLayout friendCommentListContainer = (LinearLayout) view.findViewById(R.id.reading_friend_comment_container);
        friendCommentListContainer.removeAllViews();
        for (int i = 0; i < friendCommentViews.size(); i++) {
            if (i == friendCommentViews.size() - 1) {
                friendCommentViews.get(i).findViewById(R.id.comment_divider).setVisibility(View.GONE);
            }
            friendCommentListContainer.addView(friendCommentViews.get(i));
        }

        LinearLayout friendShareListContainer = (LinearLayout) view.findViewById(R.id.reading_friend_emptyshare_container);
        friendShareListContainer.removeAllViews();
        for (int i = 0; i < friendShareViews.size(); i++) {
            if (i == friendShareViews.size() - 1) {
                friendShareViews.get(i).findViewById(R.id.comment_divider).setVisibility(View.GONE);
            }
            friendShareListContainer.addView(friendShareViews.get(i));
        }

        fragment.onSocialLoadFinished();
	}
}


