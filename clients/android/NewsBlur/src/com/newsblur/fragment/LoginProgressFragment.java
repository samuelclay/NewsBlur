package com.newsblur.fragment;

import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.view.animation.AnimationUtils;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import butterknife.ButterKnife;
import butterknife.Bind;

import com.newsblur.R;
import com.newsblur.activity.Login;
import com.newsblur.activity.Main;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.LoginResponse;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

public class LoginProgressFragment extends Fragment {

	private APIManager apiManager;
	@Bind(R.id.login_logging_in) TextView updateStatus;
    @Bind(R.id.login_retrieving_feeds) TextView retrievingFeeds;
	@Bind(R.id.login_profile_picture) ImageView loginProfilePicture;
	@Bind(R.id.login_feed_progress) ProgressBar feedProgress;
    @Bind(R.id.login_logging_in_progress) ProgressBar loggingInProgress;
	private LoginTask loginTask;
	private String username;
	private String password;

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
        ButterKnife.bind(this, v);

        loginTask = new LoginTask();
        loginTask.execute();

		return v;
	}

	private class LoginTask extends AsyncTask<Void, Void, LoginResponse> {
		@Override
		protected void onPreExecute() {
			Animation a = AnimationUtils.loadAnimation(getActivity(), R.anim.text_up);
			updateStatus.startAnimation(a);
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
            Context c = getActivity();
            if (c == null) return; // we might have run past the lifecycle of the activity
			if (!result.isError()) {
				final Animation a = AnimationUtils.loadAnimation(c, R.anim.text_down);
				updateStatus.setText(R.string.login_logged_in);
				loggingInProgress.setVisibility(View.GONE);
				updateStatus.startAnimation(a);

				loginProfilePicture.setVisibility(View.VISIBLE);
				loginProfilePicture.setImageBitmap(UIUtils.clipAndRound(PrefsUtils.getUserImage(c), 10f, false));
				feedProgress.setVisibility(View.VISIBLE);

				final Animation b = AnimationUtils.loadAnimation(c, R.anim.text_up);
				retrievingFeeds.setText(R.string.login_retrieving_feeds);
				retrievingFeeds.startAnimation(b);

                Intent startMain = new Intent(getActivity(), Main.class);
                c.startActivity(startMain);
			} else {
                UIUtils.safeToast(c, result.getErrorMessage(c.getString(R.string.login_message_error)), Toast.LENGTH_LONG);
				startActivity(new Intent(c, Login.class));
			}
		}
	}

}
