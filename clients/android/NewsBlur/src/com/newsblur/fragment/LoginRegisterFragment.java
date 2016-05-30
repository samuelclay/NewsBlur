package com.newsblur.fragment;

import android.content.Intent;
import android.os.Bundle;
import android.app.Fragment;
import android.net.Uri;
import android.text.TextUtils;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.TextView.OnEditorActionListener;
import android.widget.ViewSwitcher;

import butterknife.ButterKnife;
import butterknife.Bind;
import butterknife.OnClick;

import com.newsblur.R;
import com.newsblur.activity.LoginProgress;
import com.newsblur.activity.RegisterProgress;
import com.newsblur.util.AppConstants;

public class LoginRegisterFragment extends Fragment {

	@Bind(R.id.login_username) EditText username;
    @Bind(R.id.login_password) EditText password;
    @Bind(R.id.registration_username) EditText register_username;
    @Bind(R.id.registration_password) EditText register_password;
    @Bind(R.id.registration_email) EditText register_email;
	@Bind(R.id.login_viewswitcher) ViewSwitcher viewSwitcher;

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		final View v = inflater.inflate(R.layout.fragment_loginregister, container, false);
        ButterKnife.bind(this, v);

		password.setOnEditorActionListener(new OnEditorActionListener() {
			@Override
			public boolean onEditorAction(TextView arg0, int actionId, KeyEvent event) {
				if (actionId == EditorInfo.IME_ACTION_DONE ) { 
					logIn();
				}
				return false;
			}
		});

		register_email.setOnEditorActionListener(new OnEditorActionListener() {
			@Override
			public boolean onEditorAction(TextView arg0, int actionId, KeyEvent event) {
				if (actionId == EditorInfo.IME_ACTION_DONE ) { 
					signUp();
				}
				return false;
			}
		});

		return v;
	}

	@OnClick(R.id.login_button) void logIn() {
		if (!TextUtils.isEmpty(username.getText().toString())) {
			Intent i = new Intent(getActivity(), LoginProgress.class);
			i.putExtra("username", username.getText().toString());
			i.putExtra("password", password.getText().toString());
			startActivity(i);
		}
	}

    @OnClick(R.id.registration_button) void signUp() {
		Intent i = new Intent(getActivity(), RegisterProgress.class);
		i.putExtra("username", register_username.getText().toString());
		i.putExtra("password", register_password.getText().toString());
		i.putExtra("email", register_email.getText().toString());
		startActivity(i);
	}

    @OnClick(R.id.login_change_to_login) void showLogin() {
        viewSwitcher.showPrevious();
    }

    @OnClick(R.id.login_change_to_register) void showRegister() {
        viewSwitcher.showNext();
    }

    @OnClick(R.id.login_forgot_password) void launchForgotPasswordPage() {
        try {
            Intent i = new Intent(Intent.ACTION_VIEW);
            i.setData(Uri.parse(AppConstants.FORGOT_PASWORD_URL));
            startActivity(i);
        } catch (Exception e) {
            android.util.Log.wtf(this.getClass().getName(), "device cannot even open URLs to report feedback");
        }
    }

}
