package com.newsblur.fragment;

import com.newsblur.R;
import com.newsblur.activity.Main;
import com.newsblur.database.FeedProvider;
import com.newsblur.network.APIManager;
import com.newsblur.util.FeedUtils;

import android.app.Activity;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentManager;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

public class DeleteFeedFragment extends DialogFragment {
	private static final String FEED_ID = "feed_url";
	private static final String FEED_NAME = "feed_name";
	private static final String FOLDER_NAME = "folder_name";
    
    public static DeleteFeedFragment newInstance(final long feedId, final String feedName, final String folderName) {
    	DeleteFeedFragment frag = new DeleteFeedFragment();
		Bundle args = new Bundle();
		args.putLong(FEED_ID, feedId);
		args.putString(FEED_NAME, feedName);
		args.putString(FOLDER_NAME, folderName);
		frag.setArguments(args);
		return frag;
	}

	private FragmentManager fragmentManager;
	private SyncUpdateFragment syncFragment;	
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		setStyle(DialogFragment.STYLE_NO_TITLE, R.style.dialog);
		super.onCreate(savedInstanceState);

		fragmentManager = super.getFragmentManager();
		
		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
		}
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		
		View v = inflater.inflate(R.layout.fragment_confirm_dialog, null);
		TextView messageView = (TextView) v.findViewById(R.id.dialog_message);
		messageView.setText(String.format(getResources().getString(R.string.delete_feed_message), getArguments().getString(FEED_NAME)));
		
		Button okayButton = (Button) v.findViewById(R.id.dialog_button_okay);
        okayButton.setOnClickListener(new OnClickListener() {
			public void onClick(final View v) {
                FeedUtils.deleteFeed(getArguments().getLong(FEED_ID), getArguments().getString(FOLDER_NAME), getActivity(), new APIManager(getActivity()));
                // if called from main view then refresh otherwise it was
                // called from the feed view so finish
                Activity activity = DeleteFeedFragment.this.getActivity();
                if (activity instanceof Main) {
                   ((Main)activity).updateAfterSync();
                } else {
                   activity.finish();
                }
                DeleteFeedFragment.this.dismiss();
            }
				
		});
		
		Button cancelButton = (Button) v.findViewById(R.id.dialog_button_cancel);
		cancelButton.setOnClickListener(new OnClickListener() {
			public void onClick(View v) {
				DeleteFeedFragment.this.dismiss();
			}
		});

		return v;
	}

}
