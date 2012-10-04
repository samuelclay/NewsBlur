package com.newsblur.activity;

import android.os.Bundle;
import android.support.v4.app.FragmentActivity;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.util.Log;
import android.view.Window;

import com.newsblur.R;
import com.newsblur.fragment.LoginProgressFragment;

public class LoginProgress extends FragmentActivity {

	private FragmentManager fragmentManager;
	private String currentTag = "fragment";
	private String TAG = "LoginProgressActivity";

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		requestWindowFeature(Window.FEATURE_NO_TITLE);
		setContentView(R.layout.activity_loginprogress);
		
		fragmentManager = getSupportFragmentManager();
		
		if (fragmentManager.findFragmentByTag(currentTag ) == null) {
			String username = getIntent().getStringExtra("username");
			String password = getIntent().getStringExtra("password");
			FragmentTransaction transaction = fragmentManager.beginTransaction();
			LoginProgressFragment login = LoginProgressFragment.getInstance(username, password);
			transaction.add(R.id.login_progress_container, login, currentTag);
			transaction.commit();
		}
	}
	
}
