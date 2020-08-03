package com.newsblur.fragment;

import android.content.Intent;
import android.os.Bundle;
import android.net.Uri;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import android.text.TextUtils;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.widget.TextView;
import android.widget.TextView.OnEditorActionListener;

import com.newsblur.R;
import com.newsblur.activity.LoginProgress;
import com.newsblur.activity.RegisterProgress;
import com.newsblur.databinding.FragmentLoginregisterBinding;
import com.newsblur.network.APIConstants;
import com.newsblur.util.AppConstants;
import com.newsblur.util.PrefsUtils;

public class LoginRegisterFragment extends Fragment {

	private FragmentLoginregisterBinding binding;

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		final View v = inflater.inflate(R.layout.fragment_loginregister, container, false);
		binding = FragmentLoginregisterBinding.bind(v);

		binding.loginPassword.setOnEditorActionListener(new OnEditorActionListener() {
			@Override
			public boolean onEditorAction(TextView arg0, int actionId, KeyEvent event) {
				if (actionId == EditorInfo.IME_ACTION_DONE ) { 
					logIn();
				}
				return false;
			}
		});

		binding.registrationEmail.setOnEditorActionListener(new OnEditorActionListener() {
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

	@Override
	public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
		super.onViewCreated(view, savedInstanceState);
		binding.loginButton.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View v) {
				logIn();
			}
		});
		binding.registrationButton.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View v) {
				signUp();
			}
		});
		binding.loginChangeToLogin.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View v) {
				showLogin();
			}
		});
		binding.loginChangeToRegister.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View v) {
				showRegister();
			}
		});
		binding.loginForgotPassword.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View v) {
				launchForgotPasswordPage();
			}
		});
		binding.loginCustomServer.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View v) {
				showCustomServer();
			}
		});
	}

	private void logIn() {
		if (!TextUtils.isEmpty(binding.loginUsername.getText().toString())) {
            // set the custom server endpoint before any API access, even the cookie fetch.
            APIConstants.setCustomServer(binding.loginCustomServerValue.getText().toString());
            PrefsUtils.saveCustomServer(getActivity(), binding.loginCustomServerValue.getText().toString());

			Intent i = new Intent(getActivity(), LoginProgress.class);
			i.putExtra("username", binding.loginUsername.getText().toString());
			i.putExtra("password", binding.loginUsername.getText().toString());
			startActivity(i);
		}
	}

    private void signUp() {
		Intent i = new Intent(getActivity(), RegisterProgress.class);
		i.putExtra("username", binding.registrationUsername.getText().toString());
		i.putExtra("password", binding.registrationPassword.getText().toString());
		i.putExtra("email", binding.registrationEmail.getText().toString());
		startActivity(i);
	}

    private void showLogin() {
        binding.loginViewswitcher.showPrevious();
    }

    private void showRegister() {
        binding.loginViewswitcher.showNext();
    }

    private void launchForgotPasswordPage() {
        try {
            Intent i = new Intent(Intent.ACTION_VIEW);
            i.setData(Uri.parse(AppConstants.FORGOT_PASWORD_URL));
            startActivity(i);
        } catch (Exception e) {
            android.util.Log.wtf(this.getClass().getName(), "device cannot even open URLs to report feedback");
        }
    }

    private void showCustomServer() {
        binding.loginCustomServer.setVisibility(View.GONE);
        binding.loginCustomServerValue.setVisibility(View.VISIBLE);
    }
}