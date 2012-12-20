package com.newsblur.activity;

import java.util.ArrayList;

import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.newsblur.R;
import com.newsblur.fragment.AddSitesListFragment;
import com.newsblur.network.APIManager;

public class AddSites extends SherlockFragmentActivity {

	private FragmentManager fragmentManager;
	private String currentTag = "addsitesFragment";
	private AddSitesListFragment sitesList;
	private APIManager apiManager;
	
	@Override
	protected void onCreate(Bundle arg0) {
		super.onCreate(arg0);
		setContentView(R.layout.activity_addsites);
		apiManager = new APIManager(this);
		
		fragmentManager = getSupportFragmentManager();

		if (fragmentManager.findFragmentByTag(currentTag ) == null) {
			FragmentTransaction transaction = fragmentManager.beginTransaction();
			sitesList = new AddSitesListFragment();
			transaction.add(R.id.addsites_container, sitesList, currentTag);
			transaction.commit();
		}

		Button nextStep = (Button) findViewById(R.id.login_addsites_nextstep);
		nextStep.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				new AsyncTask<Void, Void, Void>() {

					@Override
					protected Void doInBackground(Void... params) {
						final ArrayList<String> categories = sitesList.getSelectedCategories();
						apiManager.addCategories(categories);
						return null;
					}
				}.execute();
				
				Intent i = new Intent(AddSites.this, AddSocial.class);
				startActivity(i);
			}
		});

	}
	
	@Override
	protected void onActivityResult(int requestCode, int resultCode, Intent i) {
		if (resultCode == RESULT_OK) {
			sitesList.setGoogleReaderImported();
		}
	}


}
