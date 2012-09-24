package com.newsblur.util;

import android.content.Context;
import android.content.Intent;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.Profile;
import com.newsblur.domain.UserProfile;
import com.newsblur.view.FlowLayout;

public class ViewUtils {
	
	public static void setupShareCount(Context context, View storyView, int sharedUserCount) {
		String sharedBy = context.getResources().getString(R.string.reading_shared_count);
		TextView sharesText = (TextView) storyView.findViewById(R.id.shared_by);
		if (sharedUserCount > 0) {
			sharedBy = String.format(sharedBy, sharedUserCount);
			sharesText.setText(sharedUserCount > 1 ? sharedBy : sharedBy.substring(0, sharedBy.length() - 1));
		} else {
			sharesText.setVisibility(View.INVISIBLE);
		}
	}
	
	public static void setupCommentCount(Context context, View storyView, int sharedCommentCount) {
		String commentsBy = context.getResources().getString(R.string.reading_comment_count);
		TextView sharesText = (TextView) storyView.findViewById(R.id.comment_by);
		if (sharedCommentCount > 0) {
			commentsBy = String.format(commentsBy, sharedCommentCount);
			sharesText.setText(sharedCommentCount > 1 ? commentsBy : commentsBy.substring(0, commentsBy.length() - 1));
		} else {
			sharesText.setVisibility(View.INVISIBLE);
		}
	}

	public static ImageView createSharebarImage(final Context context, final ImageLoader imageLoader, final UserProfile user) {
		ImageView image = new ImageView(context);
		int imageLength = UIUtils.convertDPsToPixels(context, 15);
		image.setMaxHeight(imageLength);
		image.setMaxWidth(imageLength);
		
		FlowLayout.LayoutParams imageParameters = new FlowLayout.LayoutParams(1, 1);
		
		imageParameters.height = imageLength;
		imageParameters.width = imageLength;
		
		image.setMaxHeight(imageLength);
		image.setMaxWidth(imageLength);
		
		image.setLayoutParams(imageParameters);
		imageLoader.displayImageByUid(user.photoUrl, image);
		image.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View view) {
				Intent i = new Intent(context, Profile.class);
				i.putExtra(Profile.USER_ID, user.userId);
				context.startActivity(i);
			}
		});
		return image;
	}

}
