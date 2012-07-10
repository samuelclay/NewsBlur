package com.newsblur.activity;

import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.util.Log;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.MenuItem;
import com.newsblur.R;
import com.newsblur.domain.UserProfile;
import com.newsblur.fragment.ProfileActivityFragment;
import com.newsblur.fragment.ProfileDetailsFragment;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.ActivitiesResponse;
import com.newsblur.network.domain.ProfileResponse;
import com.newsblur.util.PrefsUtil;

public class Profile extends SherlockFragmentActivity {

	private FragmentManager fragmentManager;
	private String detailsTag = "details";
	private String activitiesTag = "activities";
	private String TAG = "ProfileActivity";
	private APIManager apiManager;
	public static final String USER_ID = "user_id";
	private ProfileDetailsFragment detailsFragment;
	private ProfileResponse profileResponse;
	private ProfileActivityFragment activitiesFragment;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_profile);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);
		apiManager = new APIManager(this);

		fragmentManager = getSupportFragmentManager();

		if (fragmentManager.findFragmentByTag(detailsTag) == null) {
			Log.d(TAG , "Adding current new fragment");
			FragmentTransaction detailsTransaction = fragmentManager.beginTransaction();
			detailsFragment = new ProfileDetailsFragment();
			detailsFragment.setRetainInstance(true);
			detailsTransaction.add(R.id.profile_details, detailsFragment, detailsTag);
			detailsTransaction.commit();

			FragmentTransaction activitiesTransaction = fragmentManager.beginTransaction();
			activitiesFragment = new ProfileActivityFragment();
			activitiesFragment.setRetainInstance(true);
			activitiesTransaction.add(R.id.profile_activities, activitiesFragment, activitiesTag);
			activitiesTransaction.commit();

			new LoadUserTask().execute();
		} else {
			detailsFragment = (ProfileDetailsFragment) fragmentManager.findFragmentByTag(detailsTag);
			activitiesFragment = (ProfileActivityFragment) fragmentManager.findFragmentByTag(activitiesTag);
		}
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		case android.R.id.home:
			finish();
			return true;
		default:
			return super.onOptionsItemSelected(item);	
		}
	}

	private class LoadUserTask extends AsyncTask<Void, Void, ProfileResponse> {
		private UserProfile user;
		private ActivitiesResponse[] activities;

		@Override
		protected void onPreExecute() {
			if (getIntent().getStringExtra(USER_ID) == null) {
				detailsFragment.setUser(PrefsUtil.getUserDetails(Profile.this));
			}
		}

		@Override
		protected ProfileResponse doInBackground(Void... params) {
			if (getIntent().getStringExtra(USER_ID) != null) {
				Log.d(TAG, "Viewing a user.");
				profileResponse = apiManager.getUser(getIntent().getStringExtra(USER_ID));
				user = profileResponse.user;
				activities = profileResponse.activities;
			} else {
				Log.d(TAG, "Viewing our own profile");
				apiManager.updateUserProfile();
				user = PrefsUtil.getUserDetails(Profile.this);
				profileResponse = apiManager.getUser(user.id);
				if (profileResponse != null) {
					activities = profileResponse.activities;
				}
			}
			return null;
		}

		@Override
		protected void onPostExecute(ProfileResponse result) {
			if (user != null) {
				detailsFragment.setUser(user);
				activitiesFragment.setActivities(activities);
			}
		}

	}



}
