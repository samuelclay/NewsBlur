package com.newsblur.activity;

import android.os.Bundle;
import androidx.fragment.app.FragmentActivity;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;
import android.view.Window;

import com.newsblur.R;
import com.newsblur.fragment.LoginProgressFragment;
import com.newsblur.util.PrefsUtils;

public class LoginProgress extends FragmentActivity {

	private FragmentManager fragmentManager;
	private String currentTag = "fragment";

	@Override
	protected void onCreate(Bundle bundle) {
        PrefsUtils.applyThemePreference(this);

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
