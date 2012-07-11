package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.util.Log;

import com.actionbarsherlock.app.ActionBar;
import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.newsblur.R;
import com.newsblur.fragment.FolderFeedListFragment;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public class Main extends SherlockFragmentActivity implements StateChangedListener {
    
	private ActionBar actionBar;
	private FolderFeedListFragment folderFeedList;
	private FragmentManager fragmentManager;
	private static final String TAG = "MainActivity";

	@Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        setContentView(R.layout.activity_main);
        setupActionBar();
        
        fragmentManager = getSupportFragmentManager();
        folderFeedList = (FolderFeedListFragment) fragmentManager.findFragmentByTag("folderFeedListFragment");
    }
	
	private void setupActionBar() {
        actionBar = getSupportActionBar();
		actionBar.setNavigationMode(ActionBar.NAVIGATION_MODE_STANDARD);
	}
	
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getSupportMenuInflater();
	    inflater.inflate(R.menu.main, menu);
	    return true;
	}
	
	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		case R.id.menu_profile:
			Intent profileIntent = new Intent(this, Profile.class);
			startActivity(profileIntent);
			return true;
		}
		return super.onOptionsItemSelected(item);
	}

	@Override
	public void changedState(int state) {
		Log.d(TAG, "State changed");
		
		folderFeedList.changeState(state);
	}
	
}