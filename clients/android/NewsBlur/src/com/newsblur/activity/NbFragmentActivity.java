package com.newsblur.activity;

import android.os.Bundle;
import android.util.Log;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.newsblur.util.PrefsUtils;

public class NbFragmentActivity extends SherlockFragmentActivity {

	private final static String UNIQUE_LOGIN_KEY = "uniqueLoginKey";
	private String uniqueLoginKey;
	
	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

		if(bundle == null) {
			uniqueLoginKey = PrefsUtils.getUniqueLoginKey(this);
		} else {
			uniqueLoginKey = bundle.getString(UNIQUE_LOGIN_KEY);
		}
		finishIfNotLoggedIn();
	}
	
	@Override
	protected void onResume() {
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
	public void onSaveInstanceState(Bundle savedInstanceState) {
		savedInstanceState.putString(UNIQUE_LOGIN_KEY, uniqueLoginKey);
		
		super.onSaveInstanceState(savedInstanceState);
	}

}
