package com.newsblur.fragment;

import com.newsblur.R;
import com.newsblur.activity.Main;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.LoginResponse;
import com.newsblur.service.DetachableResultReceiver;
import com.newsblur.service.SyncService;
import com.newsblur.service.DetachableResultReceiver.Receiver;
import com.newsblur.util.PrefsUtil;

import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.view.animation.AnimationUtils;
import android.view.animation.Animation.AnimationListener;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.ViewSwitcher;

public class LoginProgressFragment extends Fragment implements Receiver {

	private APIManager apiManager;
	private DetachableResultReceiver receiver;
	private String TAG = "LoginProgress";
	private TextView updateStatus, retrievingFeeds, letsGo;
	private ImageView loginProfilePicture;
	private int CURRENT_STATUS = -1;
	private ProgressBar feedProgress;
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
		receiver = new DetachableResultReceiver(new Handler());
		receiver.setReceiver(this);
		Log.d(TAG , "Creating new fragment instance");
		
		username = getArguments().getString("username");
		password = getArguments().getString("password");
		
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_loginprogress, null);
		
		updateStatus = (TextView) v.findViewById(R.id.login_logging_in);
		retrievingFeeds = (TextView) v.findViewById(R.id.login_retrieving_feeds);
		letsGo = (TextView) v.findViewById(R.id.login_lets_go);
		feedProgress = (ProgressBar) v.findViewById(R.id.login_feed_progress);
		loginProfilePicture = (ImageView) v.findViewById(R.id.login_profile_picture);
		// password.setOnEditorActionListener(this);
		
		if (loginTask != null) {
			refreshUI();
		} else {
			loginTask = new LoginTask();
			loginTask.execute();
		}
		
		return v;
	}
	
	private class LoginTask extends AsyncTask<String, Void, LoginResponse> {

		private static final String TAG = "LoginTask";

		@Override
		protected void onPreExecute() {
			Animation a = AnimationUtils.loadAnimation(getActivity(), R.anim.text_up);
			updateStatus.startAnimation(a);
		}

		@Override
		protected LoginResponse doInBackground(String... params) {
			LoginResponse response = apiManager.login(username, password);
			apiManager.updateUserProfile();
			try {
				// We include this wait simply as a small UX convenience. Otherwise the user could be met with a disconcerting flicker when attempting to log in and failing.
				Thread.sleep(700);
			} catch (InterruptedException e) {
				Log.d(TAG, "Error sleeping during login.");
			}
			return response;
		}

		@Override
		protected void onPostExecute(LoginResponse result) {
			if (result.authenticated) {
				final Animation a = AnimationUtils.loadAnimation(getActivity(), R.anim.text_down);
				updateStatus.setText(R.string.login_logged_in);
				updateStatus.startAnimation(a);
				
				loginProfilePicture.setImageBitmap(PrefsUtil.getUserImage(getActivity()));
				feedProgress.setVisibility(View.VISIBLE);
				
				Log.d(TAG, "Authenticated. Starting receiver.");
				final Animation b = AnimationUtils.loadAnimation(getActivity(), R.anim.text_up);
				retrievingFeeds.setText(R.string.login_retrieving_feeds);
				retrievingFeeds.startAnimation(b);

				Log.d(TAG, "Synchronisation finished.");
				final Intent intent = new Intent(Intent.ACTION_SYNC, null, getActivity(), SyncService.class);
				intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, receiver);
				intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_FOLDER_UPDATE);
				getActivity().startService(intent);
			} else {
				if (result.errors != null && result.errors.message != null) {
						Toast.makeText(getActivity(), result.errors.message[0], Toast.LENGTH_LONG).show();
					} else {
						Toast.makeText(getActivity(), getResources().getString(R.string.login_message_error), Toast.LENGTH_LONG).show();
					}
				}
			}
		}


	private void refreshUI() {
		switch (CURRENT_STATUS) {
		case SyncService.NOT_RUNNING:
			break;
		case SyncService.STATUS_FINISHED:
			final Animation b = AnimationUtils.loadAnimation(getActivity(), R.anim.text_down);
			retrievingFeeds.setText(R.string.login_retrieved_feeds);
			retrievingFeeds.startAnimation(b);

			final Animation c = AnimationUtils.loadAnimation(getActivity(), R.anim.text_up);
			letsGo.setText(R.string.login_lets_go);
			c.setAnimationListener(new AnimationListener() {
				@Override
				public void onAnimationEnd(Animation animation) {
					Intent startMain = new Intent(getActivity(), Main.class);
					getActivity().startActivity(startMain);
				}

				@Override
				public void onAnimationRepeat(Animation animation) { }

				@Override
				public void onAnimationStart(Animation animation) { }				
			});
			letsGo.startAnimation(c);
			break;
		case SyncService.STATUS_RUNNING:
			break;
		case SyncService.STATUS_ERROR:
			Log.d(TAG, "Error synchronising feeds.");
			updateStatus.setText("Error synchronising.");
			break;
		}
	}
	

	// Interface for Host 
	public interface LoginFragmentInterface {
		public void loginSuccessful();
		public void loginUnsuccessful();
		public void syncSuccessful();
	}

	@Override
	public void onReceiverResult(int resultCode, Bundle resultData) {
		Log.d(TAG, "Received result");
		CURRENT_STATUS = resultCode;
		refreshUI();
	}
	
}
