package com.newsblur.fragment;

import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.CompoundButton.OnCheckedChangeListener;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.network.APIManager;

public class AddFollowFragment extends Fragment {

	boolean followingNewsblur, followingPopular;
	private View parentView;
	private LinearLayout followingNewsblurLayout, followingPopularLayout;
	private APIManager apiManager;
	private TextView followingNewsblurText;
	private CheckBox followingNewsblurCheckbox;
	private TextView followingPopularText;
	private CheckBox followingPopularCheckbox;
	private String TAG = "addFollowFragment";
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		apiManager = new APIManager(getActivity());
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		parentView = inflater.inflate(R.layout.fragment_addfollow, null);
		followingNewsblurLayout = (LinearLayout) parentView.findViewById(R.id.addfollow_newsblur);
		followingNewsblurText = (TextView) parentView.findViewById(R.id.addfollow_newsblur_text);
		followingNewsblurCheckbox = (CheckBox) parentView.findViewById(R.id.addfollow_newsblur_checkbox);
		
		followingPopularLayout = (LinearLayout) parentView.findViewById(R.id.addfollow_popular);
		followingPopularText = (TextView) parentView.findViewById(R.id.addfollow_popular_text);
		followingPopularCheckbox = (CheckBox) parentView.findViewById(R.id.addfollow_popular_checkbox);
		
		followingPopularLayout.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				followingPopularCheckbox.toggle();
			}
		});
		
		followingNewsblurLayout.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				followingNewsblurCheckbox.toggle();
			}
		});
		
		setupUI();
		
		followingNewsblurCheckbox.setOnCheckedChangeListener(new OnCheckedChangeListener() {
			@Override
			public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
				followingNewsblurCheckbox.setEnabled(false);
				
				new AsyncTask<Void, Void, Void>() {
					@Override
					protected Void doInBackground(Void... arg0) {
						boolean addedOkay = apiManager.addFeed("http://blog.newsblur.com", null);
						followingNewsblur = true;
						return null;
					}
					
					@Override
					protected void onPostExecute(Void result) {
						setupUI();
					}
				}.execute();
			}
		});
		
		followingPopularCheckbox.setOnCheckedChangeListener(new OnCheckedChangeListener() {
			@Override
			public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
				followingPopularCheckbox.setEnabled(false);
				
				new AsyncTask<Void, Void, Void>() {

					@Override
					protected Void doInBackground(Void... arg0) {
						boolean addedOkay = apiManager.followUser("popular");
						followingPopular = true;
						return null;
					}
					
					@Override
					protected void onPostExecute(Void result) {
						setupUI();
					}
				}.execute();
			}
		});
		
		return parentView;
	}

	private void setupUI() {
		if (followingNewsblur) {
			followingNewsblurText.setText("Following Newsblur");
			followingNewsblurCheckbox.setEnabled(false);
		}
		
		if (followingPopular) {
			followingPopularText.setText("Following Popular");
			followingPopularCheckbox.setEnabled(false);
		}
	}
	
}
