package com.newsblur.activity;

import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.newsblur.R;
import com.newsblur.fragment.RegisterProgressFragment;

/**
 * Show progress screen while registering request is being processed. This
 * Activity doesn't extend NbFragmentActivity because it is one of the few
 * Activities that will be shown while the user is still logged out.
 */
public class RegisterProgress extends SherlockFragmentActivity {

	private FragmentManager fragmentManager;
	private String currentTag = "fragment";

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		setContentView(R.layout.activity_loginprogress);
		
		fragmentManager = getSupportFragmentManager();
		
		if (fragmentManager.findFragmentByTag(currentTag ) == null) {
			final String username = getIntent().getStringExtra("username");
			final String password = getIntent().getStringExtra("password");
			final String email = getIntent().getStringExtra("email");
			FragmentTransaction transaction = fragmentManager.beginTransaction();
			RegisterProgressFragment register = RegisterProgressFragment.getInstance(username, password, email);
			transaction.add(R.id.login_progress_container, register, currentTag);
			transaction.commit();
		}
	}
	
}



