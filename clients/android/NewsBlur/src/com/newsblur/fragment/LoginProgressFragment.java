package com.newsblur.fragment;

import android.app.Activity;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.graphics.Bitmap;
import androidx.fragment.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.view.animation.AnimationUtils;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.Login;
import com.newsblur.activity.Main;
import com.newsblur.databinding.FragmentLoginprogressBinding;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.LoginResponse;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

public class LoginProgressFragment extends Fragment {

	private APIManager apiManager;
	private LoginTask loginTask;
	private String username;
	private String password;
	private FragmentLoginprogressBinding binding;

	public static LoginProgressFragment getInstance(String username, String password) {
		LoginProgressFragment fragment = new LoginProgressFragment();
		Bundle bundle = new Bundle();
		bundle.putString("username", username);
		bundle.putString("password", password);
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
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_loginprogress, null);
        binding = FragmentLoginprogressBinding.bind(v);

        loginTask = new LoginTask();
        loginTask.execute();

		return v;
	}

	private class LoginTask extends AsyncTask<Void, Void, LoginResponse> {
		@Override
		protected void onPreExecute() {
			Animation a = AnimationUtils.loadAnimation(getActivity(), R.anim.text_up);
			binding.loginLoggingIn.startAnimation(a);
		}

		@Override
		protected LoginResponse doInBackground(Void... params) {
			LoginResponse response = apiManager.login(username, password);
            // pre-load the profile iff the login was good
			if (!response.isError()) apiManager.updateUserProfile();
			return response;
		}

		@Override
		protected void onPostExecute(LoginResponse result) {
            Activity c = getActivity();
            if (c == null) return; // we might have run past the lifecycle of the activity
			if (!result.isError()) {
				final Animation a = AnimationUtils.loadAnimation(c, R.anim.text_down);
				binding.loginLoggingIn.setText(R.string.login_logged_in);
				binding.loginLoggingInProgress.setVisibility(View.GONE);
				binding.loginLoggingIn.startAnimation(a);

                Bitmap userImage = PrefsUtils.getUserImage(c);
                if (userImage != null ) {
                    binding.loginProfilePicture.setVisibility(View.VISIBLE);
                    binding.loginProfilePicture.setImageBitmap(UIUtils.clipAndRound(userImage, 10f, false));
                }
				binding.loginFeedProgress.setVisibility(View.VISIBLE);

				final Animation b = AnimationUtils.loadAnimation(c, R.anim.text_up);
				binding.loginRetrievingFeeds.setText(R.string.login_retrieving_feeds);
				binding.loginFeedProgress.startAnimation(b);

                Intent startMain = new Intent(getActivity(), Main.class);
                c.startActivity(startMain);
			} else {
                UIUtils.safeToast(c, result.getErrorMessage(c.getString(R.string.login_message_error)), Toast.LENGTH_LONG);
				startActivity(new Intent(c, Login.class));
			}
		}
	}

}
