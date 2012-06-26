package com.newsblur.fragment;

import android.content.res.Resources;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;
import android.widget.ViewSwitcher;

import com.newsblur.R;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.LoginResponse;

public class LoginFragment extends Fragment implements OnClickListener {

	public APIManager apiManager;
	private EditText username, password;
	private ViewSwitcher viewSwitcher;
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		final View v = inflater.inflate(R.layout.fragment_login, container, false);
		
		Button loginButton = (Button) v.findViewById(R.id.login_button);
		loginButton.setOnClickListener(this);
		
		viewSwitcher = (ViewSwitcher) v.findViewById(R.id.login_viewswitcher);
		
		username = (EditText) v.findViewById(R.id.login_username);
		password = (EditText) v.findViewById(R.id.login_password);
		
		return v;
	}
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		apiManager = new APIManager(getActivity().getApplicationContext());
	}

	@Override
	public void onClick(View viewClicked) {
		switch (viewClicked.getId()) {
		case R.id.login_button: 
			new LoginTask().execute(username.getText().toString(), password.getText().toString());
		}
	}	

	private class LoginTask extends AsyncTask<String, Void, LoginResponse> {

		@Override
		protected void onPreExecute() {
			viewSwitcher.showNext();
		}

		@Override
		protected LoginResponse doInBackground(String... params) {
			final String username = params[0];
			final String password = params[1];
			return apiManager.login(username, password);
		}

		@Override
		protected void onPostExecute(LoginResponse result) {
			if (result.authenticated) {
				((LoginFragmentInterface) getActivity()).loginSuccessful();
			} else {
				viewSwitcher.showPrevious();
				if (result.errors != null && result.errors.message.length > 0) {
					Toast.makeText(getActivity(), result.errors.message[0], Toast.LENGTH_LONG).show();
				} else {
					Toast.makeText(getActivity(), Resources.getSystem().getString(R.string.login_message_error), Toast.LENGTH_LONG).show();
				}
				((LoginFragmentInterface) getActivity()).loginUnsuccessful();
			}
		}
	}
	
	// Interface for Host 
	public interface LoginFragmentInterface {
		public void loginSuccessful();
		public void loginUnsuccessful();
	}
	
}
