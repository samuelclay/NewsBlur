package com.newsblur.activity;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.app.Activity;
import android.app.FragmentManager;
import android.app.FragmentTransaction;
import android.view.Window;

import com.newsblur.R;
import com.newsblur.fragment.LoginRegisterFragment;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;

public class Login extends Activity {
	
	private FragmentManager fragmentManager;
	private final static String currentTag = "currentFragment";
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
        PrefsUtils.applyThemePreference(this);

		super.onCreate(savedInstanceState);
		preferenceCheck();
		requestWindowFeature(Window.FEATURE_NO_TITLE);
		setContentView(R.layout.activity_login);
		fragmentManager = getFragmentManager();
		
		if (fragmentManager.findFragmentByTag(currentTag) == null) {
			FragmentTransaction transaction = fragmentManager.beginTransaction();
			LoginRegisterFragment login = new LoginRegisterFragment();
			transaction.add(R.id.login_container, login, currentTag);
			transaction.commit();
		}
	}

	private void preferenceCheck() {
		final SharedPreferences preferences = getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE);
		if (preferences.getString(PrefConstants.PREF_COOKIE, null) != null) {
			final Intent mainIntent = new Intent(this, Main.class);
			startActivity(mainIntent);
		}
	}
	

}
