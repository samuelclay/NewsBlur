package com.newsblur.fragment;

import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.network.APIManager;

public class AddFeedFragment extends DialogFragment {

	private static final String FEED_ID = "feed_url";
	private static final String FEED_NAME = "feed_name";
	private APIManager apiManager;


	public static AddFeedFragment newInstance(final String feedId, final String feedName) {
		AddFeedFragment frag = new AddFeedFragment();
		Bundle args = new Bundle();
		args.putString(FEED_ID, feedId);
		args.putString(FEED_NAME, feedName);
		frag.setArguments(args);
		return frag;
	}	
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		setStyle(DialogFragment.STYLE_NO_TITLE, R.style.dialog);
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		final String addFeedString = getResources().getString(R.string.add_feed_message);
		
		apiManager = new APIManager(getActivity());
		View v = inflater.inflate(R.layout.fragment_confirm_dialog, container, false);
		final TextView message = (TextView) v.findViewById(R.id.dialog_message);
		message.setText(String.format(addFeedString, getArguments().getString(FEED_NAME)));
		
		Button okayButton = (Button) v.findViewById(R.id.dialog_button_okay);
		okayButton.setOnClickListener(new OnClickListener() {
			public void onClick(final View v) {
				v.setEnabled(false);
				
				new AsyncTask<Void, Void, Boolean>() {
					@Override
					protected Boolean doInBackground(Void... arg) {
						return apiManager.addFeed(getArguments().getString(FEED_ID), null);
					}
					
					@Override
					protected void onPostExecute(Boolean result) {
						if (result) {
							AddFeedFragment.this.dismiss();
							AddFeedFragment.this.getActivity().finish();
						} else {
							AddFeedFragment.this.dismiss();
							Toast.makeText(getActivity(), "Error adding feed", Toast.LENGTH_SHORT).show();
						}
					};
				}.execute();
				
			}
		});
		
		Button cancelButton = (Button) v.findViewById(R.id.dialog_button_cancel);
		cancelButton.setOnClickListener(new OnClickListener() {
			public void onClick(View v) {
				AddFeedFragment.this.dismiss();
			}
		});

		return v;
	}

}
