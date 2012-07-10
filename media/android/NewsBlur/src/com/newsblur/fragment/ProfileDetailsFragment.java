package com.newsblur.fragment;

import android.graphics.Bitmap;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.UserProfile;
import com.newsblur.util.PrefsUtil;
import com.newsblur.util.UIUtils;

public class ProfileDetailsFragment extends Fragment {
	
	UserProfile user;
	private TextView username, bio, location, sharedCount, followerCount, followingCount, website;
	private ImageView imageView;
	private String noBio, noLocation;  
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		noBio = getString(R.string.profile_no_bio);
		noLocation = getActivity().getResources().getString(R.string.profile_no_location);
	}
	
	public void setUser(final UserProfile user) {
		this.user = user;
		if (username != null) {
			setUserFields();
		}
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_profiledetails, null);
		username = (TextView) v.findViewById(R.id.profile_username);
		bio = (TextView) v.findViewById(R.id.profile_bio);
		location = (TextView) v.findViewById(R.id.profile_location);
		sharedCount = (TextView) v.findViewById(R.id.profile_sharedcount);
		website = (TextView) v.findViewById(R.id.profile_website);
		followerCount = (TextView) v.findViewById(R.id.profile_followercount);
		followingCount = (TextView) v.findViewById(R.id.profile_followingcount);
		imageView = (ImageView) v.findViewById(R.id.profile_picture);
		
		if (user != null) {
			setUserFields();
		}
		
		return v;
	}

	private void setUserFields() {
		username.setText(user.username);
		
		if (!TextUtils.isEmpty(user.bio)) {
			bio.setText(user.bio);
		} else {
			bio.setText(noBio);
		}
		
		if (!TextUtils.isEmpty(user.location)) {
			location.setText(user.location);
		} else {
			location.setText(noLocation);
		}
		
		if (!TextUtils.isEmpty(user.website)) {
			website.setText("" + user.website);
		} else {
			website.setVisibility(View.GONE);
		}
		
		sharedCount.setText("" + user.sharedStoriesCount);
		
		followerCount.setText("" + user.followerCount);
		
		followingCount.setText("" + user.followingCount);
		
		Bitmap userPicture = PrefsUtil.getUserImage(getActivity());
		userPicture = UIUtils.roundCorners(userPicture, 10f);
		imageView.setImageBitmap(userPicture);
	}
	
}
