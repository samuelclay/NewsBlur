package com.newsblur.activity;

import android.os.Bundle;
import android.support.v4.app.FragmentActivity;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.view.Window;

import com.newsblur.R;
import com.newsblur.fragment.LoginFragment;

public class Login extends FragmentActivity {
	
	private FragmentManager fragmentManager;
	private final static String currentTag = "currentFragment";
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		requestWindowFeature(Window.FEATURE_NO_TITLE);
		setContentView(R.layout.login);
		
		fragmentManager = getSupportFragmentManager();
		if (fragmentManager.findFragmentByTag(currentTag) == null) {
			FragmentTransaction transaction = fragmentManager.beginTransaction();
			transaction.add(R.id.login_container, new LoginFragment(), currentTag);
			transaction.commit();
		}
		
	}

}
