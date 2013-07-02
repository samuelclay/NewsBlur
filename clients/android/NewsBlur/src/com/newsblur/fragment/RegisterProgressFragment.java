package com.newsblur.fragment;

import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.view.animation.AnimationUtils;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.Toast;
import android.widget.ViewSwitcher;

import com.newsblur.R;
import com.newsblur.activity.AddSites;
import com.newsblur.activity.Login;
import com.newsblur.activity.LoginProgress;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.RegisterResponse;

public class RegisterProgressFragment extends Fragment {

	private APIManager apiManager;

	private String username;
	private String password;
	private String email;
	private RegisterTask registerTask;
	private ViewSwitcher switcher;
	private Button next;
	private ImageView registerProgressLogo;

	public static RegisterProgressFragment getInstance(String username, String password, String email) {
		RegisterProgressFragment fragment = new RegisterProgressFragment();
		Bundle bundle = new Bundle();
		bundle.putString("username", username);
		bundle.putString("password", password);
		bundle.putString("email", email);
		fragment.setArguments(bundle);
		return fragment;
	}

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setRetainInstance(true);
		apiManager = new APIManager(getActivity());

		username = getArguments().getString("username");
		password = getArguments().getString("password");
		email = getArguments().getString("email");

	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_registerprogress, null);
		switcher = (ViewSwitcher) v.findViewById(R.id.register_viewswitcher);

		registerProgressLogo = (ImageView) v.findViewById(R.id.registerprogress_logo);
		registerProgressLogo.startAnimation(AnimationUtils.loadAnimation(getActivity(), R.anim.rotate));

		next = (Button) v.findViewById(R.id.registering_next_1);

		if (registerTask != null) {
			switcher.showNext();
		} else {
			registerTask = new RegisterTask();
			registerTask.execute();
		}

		next.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View arg0) {
				Intent i = new Intent(getActivity(), AddSites.class);
				startActivity(i);
			}
		});

		return v;
	}

	private class RegisterTask extends AsyncTask<Void, Void, RegisterResponse> {

		@Override
		protected RegisterResponse doInBackground(Void... params) {
			return apiManager.signup(username, password, email);
		}

		@Override
		protected void onPostExecute(RegisterResponse response) {
			if (response.authenticated) {
                switcher.showNext();
			} else {
				Toast.makeText(getActivity(), extractErrorMessage(response), Toast.LENGTH_LONG).show();
				startActivity(new Intent(getActivity(), Login.class));
			}
		}

		private String extractErrorMessage(RegisterResponse response) {
			// TODO: do we ever see these mysterious email/username messages in practice?
            String errorMessage = null;
            if(response.email != null && response.email.length > 0) {
                errorMessage = response.email[0];
            } else if(response.username != null && response.username.length > 0) {
                errorMessage = response.username[0];
            }
			if(errorMessage == null) {
				errorMessage = response.getErrorMessage(getResources().getString(R.string.login_message_error));
			}
			return errorMessage;
		}
	}


}
