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
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;

public class Login extends Activity {
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // this is the first Activity launched; use it to init the global singletons in FeedUtils
        FeedUtils.offerInitContext(this);

        // see if a user is already logged in; if so, jump to the Main activity
        preferenceCheck();

        requestWindowFeature(Window.FEATURE_NO_TITLE);
        setContentView(R.layout.activity_login);
        FragmentManager fragmentManager = getFragmentManager();
        
        if (fragmentManager.findFragmentByTag(LoginRegisterFragment.class.getName()) == null) {
            FragmentTransaction transaction = fragmentManager.beginTransaction();
            LoginRegisterFragment login = new LoginRegisterFragment();
            transaction.add(R.id.login_container, login, LoginRegisterFragment.class.getName());
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
