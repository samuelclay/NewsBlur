package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.newsblur.R;
import com.newsblur.fragment.AddFollowFragment;

public class AddFollow extends SherlockFragmentActivity {

	private FragmentManager fragmentManager;
	private String currentTag = "addFollowFragment";
	private AddFollowFragment addFollowFragment;

	public void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		setContentView(R.layout.activity_addfollow);

		fragmentManager = getSupportFragmentManager();
		
		if (fragmentManager.findFragmentByTag(currentTag ) == null) {
			FragmentTransaction transaction = fragmentManager.beginTransaction();
			addFollowFragment = new AddFollowFragment();
			transaction.add(R.id.addfollow_container, addFollowFragment, currentTag);
			transaction.commit();
		}
		
		Button startReading = (Button) findViewById(R.id.login_addfollow_startreading);
		startReading.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
			Intent i = new Intent(AddFollow.this, Main.class);
			i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
			startActivity(i);
			}
		});
	};
	
}
