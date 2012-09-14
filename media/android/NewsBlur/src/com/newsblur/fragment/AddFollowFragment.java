package com.newsblur.fragment;

import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;

import com.newsblur.R;

public class AddFollowFragment extends Fragment {

	boolean followingNewsblur, followingPopular;
	private View parentView;
	private LinearLayout followingNewsblurButton, followingPopularButton;
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		parentView = inflater.inflate(R.layout.fragment_addfollow, null);
		followingNewsblurButton = (LinearLayout) parentView.findViewById(R.id.addfollow_newsblur);
		followingPopularButton = (LinearLayout) parentView.findViewById(R.id.addfollow_popular);
		setupUI();
		return parentView;
	}

	private void setupUI() {
		if (followingNewsblur) {
			
		}
		
		if (followingPopular) {
			
		}
	}
	
}
