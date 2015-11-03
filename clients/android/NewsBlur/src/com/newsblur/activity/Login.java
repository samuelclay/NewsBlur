package com.newsblur.activity;

import android.os.Bundle;
import android.app.Activity;
import android.app.FragmentManager;
import android.app.FragmentTransaction;
import android.view.Window;

import com.newsblur.R;
import com.newsblur.fragment.LoginRegisterFragment;

public class Login extends Activity {
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

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

}
