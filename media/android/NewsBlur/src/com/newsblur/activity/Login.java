package com.newsblur.activity;

import android.os.Bundle;
import android.support.v4.app.FragmentActivity;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.util.Log;
import android.view.Window;

import com.newsblur.R;
import com.newsblur.fragment.LoginFragment;

public class Login extends FragmentActivity implements LoginFragment.LoginFragmentInterface {
	
	private FragmentManager fragmentManager;
	private final static String currentTag = "currentFragment";
	private static final String TAG = "LoginActivity";
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		requestWindowFeature(Window.FEATURE_NO_TITLE);
		setContentView(R.layout.login);
		fragmentManager = getSupportFragmentManager();
		
		if (fragmentManager.findFragmentByTag(currentTag) == null) {
			Log.d(TAG, "Adding current new fragment");
			FragmentTransaction transaction = fragmentManager.beginTransaction();
			LoginFragment login = new LoginFragment();
			transaction.add(R.id.login_container, login, currentTag);
			transaction.commit();
		}
	}

	@Override
	public void loginSuccessful() {
		Log.d(TAG, "Login successful");
	}

	@Override
	public void loginUnsuccessful() {
		Log.d(TAG, "Login unsuccessful");
	}
	

}
