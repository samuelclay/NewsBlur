package com.newsblur.activity;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.app.Activity;
import android.view.Window;

import com.newsblur.R;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;

/**
 * The very first activity we launch. Checks to see if there is a user logged in yet and then
 * either loads the Main UI or a Login screen as needed.  Also responsible for warming up the
 * DB connection used by all other Activities.
 */
public class InitActivity extends Activity {
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // this is the first Activity launched; use it to init the global singletons in FeedUtils
        FeedUtils.offerInitContext(this);

        // see if a user is already logged in; if so, jump to the Main activity
        preferenceCheck();
    }

    private void preferenceCheck() {
        SharedPreferences preferences = getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE);
        if (preferences.getString(PrefConstants.PREF_COOKIE, null) != null) {
            Intent mainIntent = new Intent(this, Main.class);
            startActivity(mainIntent);
        } else {
            Intent loginIntent = new Intent(this, Login.class);
            startActivity(loginIntent);
        }
    }

}
