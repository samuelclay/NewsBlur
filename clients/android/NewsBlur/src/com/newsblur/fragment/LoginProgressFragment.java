package com.newsblur.fragment;

import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.Fragment;
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

import com.newsblur.R;
import com.newsblur.activity.Login;
import com.newsblur.activity.Main;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

public class LoginProgressFragment extends Fragment {

	private APIManager apiManager;
	private TextView updateStatus, retrievingFeeds;
	private ImageView loginProfilePicture;
	private ProgressBar feedProgress, loggingInProgress;
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

		updateStatus = (TextView) v.findViewById(R.id.login_logging_in);
		retrievingFeeds = (TextView) v.findViewById(R.id.login_retrieving_feeds);
		feedProgress = (ProgressBar) v.findViewById(R.id.login_feed_progress);
		loggingInProgress = (ProgressBar) v.findViewById(R.id.login_logging_in_progress);
		loginProfilePicture = (ImageView) v.findViewById(R.id.login_profile_picture);

        loginTask = new LoginTask();
        loginTask.execute();

		return v;
	}

	private class LoginTask extends AsyncTask<Void, Void, NewsBlurResponse> {

		@Override
		protected void onPreExecute() {
			Animation a = AnimationUtils.loadAnimation(getActivity(), R.anim.text_up);
			updateStatus.startAnimation(a);
		}

		@Override
		protected NewsBlurResponse doInBackground(Void... params) {
			NewsBlurResponse response = apiManager.login(username, password);
			apiManager.updateUserProfile();
			return response;
		}

		@Override
		protected void onPostExecute(NewsBlurResponse result) {
			if (!result.isError()) {
				final Animation a = AnimationUtils.loadAnimation(getActivity(), R.anim.text_down);
				updateStatus.setText(R.string.login_logged_in);
				loggingInProgress.setVisibility(View.GONE);
				updateStatus.startAnimation(a);

				loginProfilePicture.setVisibility(View.VISIBLE);
				loginProfilePicture.setImageBitmap(UIUtils.roundCorners(PrefsUtils.getUserImage(getActivity()), 10f));
				feedProgress.setVisibility(View.VISIBLE);

				final Animation b = AnimationUtils.loadAnimation(getActivity(), R.anim.text_up);
				retrievingFeeds.setText(R.string.login_retrieving_feeds);
				retrievingFeeds.startAnimation(b);

                Intent startMain = new Intent(getActivity(), Main.class);
                getActivity().startActivity(startMain);

			} else {
                Toast.makeText(getActivity(), result.getErrorMessage(), Toast.LENGTH_LONG).show();
				startActivity(new Intent(getActivity(), Login.class));
			}
		}
	}

}
