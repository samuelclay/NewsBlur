package com.newsblur.fragment;

import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.view.animation.Animation.AnimationListener;
import android.view.animation.AnimationUtils;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.ViewSwitcher;

import com.newsblur.R;
import com.newsblur.activity.Main;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.LoginResponse;
import com.newsblur.service.DetachableResultReceiver;
import com.newsblur.service.DetachableResultReceiver.Receiver;
import com.newsblur.service.SyncService;

public class LoginFragment extends Fragment implements OnClickListener, Receiver, TextView.OnEditorActionListener {

	private static final String TAG = "LoginFragment";
	private String VIEWSWITCHER_CHILD = "viewSwitcherChild";

	public APIManager apiManager;
	private EditText username, password;
	private ViewSwitcher viewSwitcher;
	private LoginTask loginTask;
	DetachableResultReceiver receiver;
	private TextView updateStatus, retrievingFeeds, letsGo;
	private int CURRENT_STATUS = -1;

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		final View v = inflater.inflate(R.layout.fragment_login, container, false);
		Log.d(TAG, "Creating login fragment view");
		Button loginButton = (Button) v.findViewById(R.id.login_button);
		loginButton.setOnClickListener(this);

		viewSwitcher = (ViewSwitcher) v.findViewById(R.id.login_viewswitcher);

		updateStatus = (TextView) v.findViewById(R.id.login_logging_in);
		retrievingFeeds = (TextView) v.findViewById(R.id.login_retrieving_feeds);
		letsGo = (TextView) v.findViewById(R.id.login_lets_go);
		username = (EditText) v.findViewById(R.id.login_username);
		password = (EditText) v.findViewById(R.id.login_password);
		password.setOnEditorActionListener(this);

		if (loginTask != null) {
			loginTask.viewSwitcher = viewSwitcher;
			viewSwitcher.setDisplayedChild(1);
			refreshUI();
		}

		return v;
	}

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setRetainInstance(true);
		apiManager = new APIManager(getActivity());
		receiver = new DetachableResultReceiver(new Handler());
		receiver.setReceiver(this);
		Log.d(TAG, "Creating new fragment instance");
	}

	@Override
	public void onClick(View viewClicked) {
		switch (viewClicked.getId()) {
		case R.id.login_button: 
			logIn();
		}
	}

	private void logIn() {
		loginTask = new LoginTask();
		loginTask.viewSwitcher = viewSwitcher;
		loginTask.execute(username.getText().toString(), password.getText().toString());
	}	

	@Override
	public void onSaveInstanceState(Bundle outState) {
		outState.putInt(VIEWSWITCHER_CHILD , viewSwitcher.getDisplayedChild());
		if (loginTask != null) {
			loginTask.viewSwitcher = null;
		}
		super.onSaveInstanceState(outState);
	}

	private class LoginTask extends AsyncTask<String, Void, LoginResponse> {

		private static final String TAG = "LoginTask";
		public ViewSwitcher viewSwitcher;

		@Override
		protected void onPreExecute() {
			viewSwitcher.showNext();
			Animation a = AnimationUtils.loadAnimation(getActivity(), R.anim.text_up);
			updateStatus.startAnimation(a);
		}

		@Override
		protected LoginResponse doInBackground(String... params) {
			final String username = params[0];
			final String password = params[1];
			LoginResponse response = apiManager.login(username, password);
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
				
				Log.d(TAG, "Authenticated. Starting receiver.");
				final Animation b = AnimationUtils.loadAnimation(getActivity(), R.anim.text_up);
				retrievingFeeds.setText(R.string.login_retrieving_feeds);
				retrievingFeeds.startAnimation(b);
				
				Log.d(TAG, "Synchronisation finished.");
				final Intent intent = new Intent(Intent.ACTION_SYNC, null, getActivity(), SyncService.class);
				intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, receiver);
				getActivity().startService(intent);
			} else {
				if (viewSwitcher != null) {
					viewSwitcher.showPrevious();
					if (result.errors != null && result.errors.message != null) {
						Toast.makeText(getActivity(), result.errors.message[0], Toast.LENGTH_LONG).show();
					} else {
						Toast.makeText(getActivity(), getResources().getString(R.string.login_message_error), Toast.LENGTH_LONG).show();
					}
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

	@Override public boolean onEditorAction(TextView v, int actionId, KeyEvent event) {
		if (actionId == EditorInfo.IME_ACTION_DONE) {
			logIn();
			InputMethodManager imm = (InputMethodManager) getActivity().getSystemService(Context.INPUT_METHOD_SERVICE);
			imm.hideSoftInputFromWindow(v.getWindowToken(), 0);
			return true;
		}
		return false;
	}

}
