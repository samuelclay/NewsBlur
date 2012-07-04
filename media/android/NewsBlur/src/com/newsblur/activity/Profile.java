package com.newsblur.activity;

import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.util.Log;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.newsblur.R;
import com.newsblur.fragment.ProfileDetailsFragment;

public class Profile extends SherlockFragmentActivity {

	private FragmentManager fragmentManager;
	private String detailsFragment = "details";
	private String TAG = "ProfileActivity";

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_profile);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);

		fragmentManager = getSupportFragmentManager();

		if (fragmentManager.findFragmentByTag(detailsFragment ) == null) {
			Log.d(TAG , "Adding current new fragment");
			FragmentTransaction transaction = fragmentManager.beginTransaction();
			ProfileDetailsFragment details = new ProfileDetailsFragment();
			transaction.add(R.id.profile_details, details, detailsFragment);
			transaction.commit();
		}
	}

}
