package com.newsblur.fragment;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.text.TextUtils;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.TextView.OnEditorActionListener;
import android.widget.ViewSwitcher;

import com.newsblur.R;
import com.newsblur.activity.LoginProgress;
import com.newsblur.activity.RegisterProgress;
import com.newsblur.network.APIManager;
import com.newsblur.service.DetachableResultReceiver;

public class LoginRegisterFragment extends Fragment implements OnClickListener {

	public APIManager apiManager;
	private EditText username, password;
	private ViewSwitcher viewSwitcher;

	DetachableResultReceiver receiver;
	private EditText register_username, register_password, register_email;


	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		final View v = inflater.inflate(R.layout.fragment_loginregister, container, false);

		final Button loginButton = (Button) v.findViewById(R.id.login_button);
		final Button registerButton = (Button) v.findViewById(R.id.registration_button);
		loginButton.setOnClickListener(this);
		registerButton.setOnClickListener(this);

		username = (EditText) v.findViewById(R.id.login_username);
		password = (EditText) v.findViewById(R.id.login_password);
		
		password.setOnEditorActionListener(new OnEditorActionListener() {
			@Override
			public boolean onEditorAction(TextView arg0, int actionId, KeyEvent event) {
				if (actionId == EditorInfo.IME_ACTION_DONE ) { 
					logIn();
				}
				return false;
			}
		});

		register_username = (EditText) v.findViewById(R.id.registration_username);
		register_password = (EditText) v.findViewById(R.id.registration_password);
		register_email = (EditText) v.findViewById(R.id.registration_email);

		register_email.setOnEditorActionListener(new OnEditorActionListener() {
			@Override
			public boolean onEditorAction(TextView arg0, int actionId, KeyEvent event) {
				if (actionId == EditorInfo.IME_ACTION_DONE ) { 
					signUp();
				}
				return false;
			}
		});

		viewSwitcher = (ViewSwitcher) v.findViewById(R.id.login_viewswitcher);

		TextView changeToLogin = (TextView) v.findViewById(R.id.login_change_to_login);
		TextView changeToRegister = (TextView) v.findViewById(R.id.login_change_to_register);

		changeToLogin.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View arg0) {
				viewSwitcher.showPrevious();
			}
		});

		changeToRegister.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View arg0) {
				viewSwitcher.showNext();
			}
		});

		return v;
	}

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

	}

	@Override
	public void onClick(View viewClicked) {
		switch (viewClicked.getId()) {
		case R.id.login_button: 
			logIn();
			break;
		case R.id.registration_button: 
			signUp();
			break;
		}
	}

	private void logIn() {
		if (!TextUtils.isEmpty(username.getText().toString())) {
			Intent i = new Intent(getActivity(), LoginProgress.class);
			i.putExtra("username", username.getText().toString());
			i.putExtra("password", password.getText().toString());
			startActivity(i);
		}
	}

	private void signUp() {
		Intent i = new Intent(getActivity(), RegisterProgress.class);
		i.putExtra("username", register_username.getText().toString());
		i.putExtra("password", register_password.getText().toString());
		i.putExtra("email", register_email.getText().toString());
		startActivity(i);
	}


}
