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
import com.newsblur.fragment.AddSocialFragment;

public class AddSocial extends SherlockFragmentActivity {

	private FragmentManager fragmentManager;
	private String currentTag = "addSocialFragment";
	private AddSocialFragment addSocialFragment;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		setContentView(R.layout.activity_addsocial);
		
		fragmentManager = getSupportFragmentManager();

		if (fragmentManager.findFragmentByTag(currentTag) == null) {
			FragmentTransaction transaction = fragmentManager.beginTransaction();
			addSocialFragment = new AddSocialFragment();
			transaction.add(R.id.addsocial_container, addSocialFragment, currentTag);
			transaction.commit();
		}
		
		Button nextStep = (Button) findViewById(R.id.login_addsocial_nextstep);
		nextStep.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View arg0) {
				Intent i = new Intent(AddSocial.this, AddFollow.class);
				startActivity(i);
			}
		});
		
	}
	
	
	@Override
	protected void onActivityResult(int requestCode, int resultCode, Intent intent) {
		switch (resultCode) {
		case AddTwitter.TWITTER_AUTHED:
			addSocialFragment.setTwitterAuthed();
		case AddFacebook.FACEBOOK_AUTHED:
			addSocialFragment.setFacebookAuthed();	
		}
	}
}
