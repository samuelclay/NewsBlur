package com.newsblur.activity;

import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.util.Log;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.newsblur.R;
import com.newsblur.fragment.RegisterProgressFragment;

public class RegisterProgress extends SherlockFragmentActivity {

	private FragmentManager fragmentManager;
	private String currentTag = "fragment";
	private String TAG = "RegisterProgressActivity";

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



