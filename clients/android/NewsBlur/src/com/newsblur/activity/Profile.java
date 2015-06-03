package com.newsblur.activity;

import android.os.AsyncTask;
import android.os.Bundle;
import android.app.FragmentManager;
import android.app.FragmentTransaction;
import android.text.TextUtils;
import android.view.MenuItem;

import com.newsblur.R;
import com.newsblur.domain.UserDetails;
import com.newsblur.fragment.ProfileActivityFragment;
import com.newsblur.fragment.ProfileDetailsFragment;
import com.newsblur.network.APIManager;
import com.newsblur.util.PrefsUtils;

public class Profile extends NbActivity {

	private FragmentManager fragmentManager;
	private String detailsTag = "details";
	private String activitiesTag = "activities";
	private String TAG = "ProfileActivity";
	private APIManager apiManager;
	public static final String USER_ID = "user_id";
	private ProfileDetailsFragment detailsFragment;
	private ProfileActivityFragment activitiesFragment;
	private String userId = null;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_profile);
		getActionBar().setDisplayHomeAsUpEnabled(true);
		apiManager = new APIManager(this);
		userId = getIntent().getStringExtra(USER_ID);
		
		fragmentManager = getFragmentManager();

		if (fragmentManager.findFragmentByTag(detailsTag) == null) {
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

	private class LoadUserTask extends AsyncTask<Void, Void, Void> {
		private UserDetails user;

		@Override
		protected void onPreExecute() {
			if (TextUtils.isEmpty(userId)) {
				detailsFragment.setUser(Profile.this, PrefsUtils.getUserDetails(Profile.this), true);
			}
		}

		@Override
		protected Void doInBackground(Void... params) {
			if (!TextUtils.isEmpty(userId)) {
				String intentUserId  = getIntent().getStringExtra(USER_ID);
				user = apiManager.getUser(intentUserId).user;
			} else {
				apiManager.updateUserProfile();
				user = PrefsUtils.getUserDetails(Profile.this);
			}
			return null;
		}

		@Override
		protected void onPostExecute(Void result) {
			if (user != null && detailsFragment != null && activitiesFragment != null) {
				detailsFragment.setUser(Profile.this, user, TextUtils.isEmpty(userId));
				activitiesFragment.setUser(Profile.this, user);
			}
		}
	}
}
