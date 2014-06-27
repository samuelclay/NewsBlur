package com.newsblur.activity;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;

import com.newsblur.util.AppConstants;
import com.newsblur.util.PrefsUtils;

public class NbActivity extends Activity {

	private final static String UNIQUE_LOGIN_KEY = "uniqueLoginKey";
	private String uniqueLoginKey;
	
	@Override
	protected void onCreate(Bundle bundle) {
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onCreate");

        PrefsUtils.applyThemePreference(this);

		super.onCreate(bundle);

		if (bundle != null) {
			uniqueLoginKey = bundle.getString(UNIQUE_LOGIN_KEY);
		} 
        if (uniqueLoginKey == null) {
			uniqueLoginKey = PrefsUtils.getUniqueLoginKey(this);
		}
		finishIfNotLoggedIn();
	}
	
	@Override
	protected void onResume() {
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onResume");
		super.onResume();
		finishIfNotLoggedIn();
	}

	protected void finishIfNotLoggedIn() {
		String currentLoginKey = PrefsUtils.getUniqueLoginKey(this);
		if(currentLoginKey == null || !currentLoginKey.equals(uniqueLoginKey)) {
			Log.d( this.getClass().getName(), "This activity was for a different login. finishing it.");
			finish();
		}
	}
	
	@Override
	protected void onSaveInstanceState(Bundle savedInstanceState) {
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onSave");
		savedInstanceState.putString(UNIQUE_LOGIN_KEY, uniqueLoginKey);
		super.onSaveInstanceState(savedInstanceState);
	}

}
