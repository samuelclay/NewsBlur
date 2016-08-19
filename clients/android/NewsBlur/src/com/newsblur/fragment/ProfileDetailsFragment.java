package com.newsblur.fragment;

import android.content.Context;
import android.graphics.Bitmap;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.Fragment;
import android.app.FragmentManager;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.UserDetails;
import com.newsblur.network.APIManager;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

public class ProfileDetailsFragment extends Fragment implements OnClickListener {
	
	UserDetails user;
	private TextView username, bio, location, sharedCount, followerCount, followingCount, website;
	private View locationIcon;
	private ImageView imageView;
	private boolean viewingSelf = false;
	private Button followButton, unfollowButton;
	private APIManager apiManager;
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		apiManager = new APIManager(getActivity());
	}
	
	public void setUser(Context context, final UserDetails user, final boolean viewingSelf) {
		this.user = user;
		this.viewingSelf = viewingSelf;
		if (username != null) {
			setUserFields(context);
		}
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_profiledetails, null);
		username = (TextView) v.findViewById(R.id.profile_username);
		bio = (TextView) v.findViewById(R.id.profile_bio);
		location = (TextView) v.findViewById(R.id.profile_location);
		locationIcon = v.findViewById(R.id.profile_location_icon);
		sharedCount = (TextView) v.findViewById(R.id.profile_sharedcount);
		website = (TextView) v.findViewById(R.id.profile_website);
		followerCount = (TextView) v.findViewById(R.id.profile_followercount);
		followingCount = (TextView) v.findViewById(R.id.profile_followingcount);
		imageView = (ImageView) v.findViewById(R.id.profile_picture);
		followButton = (Button) v.findViewById(R.id.profile_follow_button);
		unfollowButton = (Button) v.findViewById(R.id.profile_unfollow_button);
		followButton.setOnClickListener(this);
		unfollowButton.setOnClickListener(this);
		
		if (user != null) {
			setUserFields(getActivity());
		}
		
		return v;
	}

	private void setUserFields(Context context) {
		username.setText(user.username);
		
		if (!TextUtils.isEmpty(user.bio)) {
			bio.setText(user.bio);
		} else {
			bio.setVisibility(View.INVISIBLE);
		}
		
		if (!TextUtils.isEmpty(user.location)) {
			location.setText(user.location);
		} else {
			location.setVisibility(View.INVISIBLE);
			locationIcon.setVisibility(View.INVISIBLE);
		}
		
		if (!TextUtils.isEmpty(user.website)) {
			website.setText("" + user.website);
		} else {
			website.setVisibility(View.GONE);
		}
		
		sharedCount.setText("" + user.sharedStoriesCount);
		
		followerCount.setText("" + user.followerCount);
		
		followingCount.setText("" + user.followingCount);
		
		if (!viewingSelf) {
			FeedUtils.iconLoader.displayImage(user.photoUrl, imageView, 5, false);
			if (user.followedByYou) {
				unfollowButton.setVisibility(View.VISIBLE);
				followButton.setVisibility(View.GONE);
			} else {
				unfollowButton.setVisibility(View.GONE);
				followButton.setVisibility(View.VISIBLE);
			}
		} else {
			followButton.setVisibility(View.GONE);
			Bitmap userPicture = PrefsUtils.getUserImage(context);
			// seems to sometimes be an error loading the picture so prevent
			// force close if null returned
			if (userPicture != null) {
		        userPicture = UIUtils.clipAndRound(userPicture, 5, false);
			    imageView.setImageBitmap(userPicture);
			}
		}
	}
	
	private class FollowTask extends AsyncTask<Void, Void, Boolean> {
		@Override
		protected void onPreExecute() {
			followButton.setEnabled(false);
		}
		
		@Override
		protected Boolean doInBackground(Void... params) {
			return apiManager.followUser(user.userId);
		}
		
		@Override
		protected void onPostExecute(Boolean result) {
			followButton.setEnabled(true);
			if (result) {
				user.followedByYou = true;
				followButton.setVisibility(View.GONE);
				unfollowButton.setVisibility(View.VISIBLE);
			} else {
				FragmentManager fm = ProfileDetailsFragment.this.getFragmentManager();
		        AlertDialogFragment alertDialog = AlertDialogFragment.newAlertDialogFragment(getResources().getString(R.string.follow_error));
		        alertDialog.show(fm, "fragment_edit_name");
			}	
		}		
	}
	
	private class UnfollowTask extends AsyncTask<Void, Void, Boolean> {
		@Override
		protected void onPreExecute() {
			unfollowButton.setEnabled(false);
		}
		
		@Override
		protected Boolean doInBackground(Void... params) {
			return apiManager.unfollowUser(user.userId);
		}
		
		@Override
		protected void onPostExecute(Boolean result) {
			unfollowButton.setEnabled(true);
			if (result) {
				user.followedByYou = false;
				unfollowButton.setVisibility(View.GONE);
				followButton.setVisibility(View.VISIBLE);
			} else {
				FragmentManager fm = ProfileDetailsFragment.this.getFragmentManager();
                AlertDialogFragment alertDialog = AlertDialogFragment.newAlertDialogFragment(getResources().getString(R.string.unfollow_error));
                alertDialog.show(fm, "fragment_edit_name");
			}	
		}		
	}
	

	@Override
	public void onClick(View v) {
		if (v.getId() == R.id.profile_follow_button) {
			new FollowTask().execute();
		} else if (v.getId() == R.id.profile_unfollow_button) {
			new UnfollowTask().execute();
		}
	}
	
}
