package com.newsblur.fragment;

import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.UserProfile;
import com.newsblur.util.PrefsUtil;

public class ProfileDetailsFragment extends Fragment {
	
	UserProfile user;
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		user = PrefsUtil.getUserDetails(getActivity());
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_profiledetails, null);
		
		TextView username = (TextView) v.findViewById(R.id.profile_username);
		username.setText(user.username);
		TextView bio = (TextView) v.findViewById(R.id.profile_bio);
		bio.setText(user.bio);
		TextView location = (TextView) v.findViewById(R.id.profile_location);
		location.setText(user.location);
		
		TextView sharedCount = (TextView) v.findViewById(R.id.profile_sharedcount);
		sharedCount.setText("" + user.sharedStoriesCount);
		
		TextView followerCount = (TextView) v.findViewById(R.id.profile_followercount);
		followerCount.setText("" + user.followerCount);
		
		TextView followingCount = (TextView) v.findViewById(R.id.profile_followingcount);
		followingCount.setText("" + user.followingCount);
		
		TextView subscriberCount = (TextView) v.findViewById(R.id.profile_subscribercount);
		subscriberCount.setText("" + user.numberOfSubscribers);
		
		return v;
	}
	
}
