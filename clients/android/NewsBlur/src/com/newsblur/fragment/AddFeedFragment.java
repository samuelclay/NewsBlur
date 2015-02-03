package com.newsblur.fragment;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.DialogFragment;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.network.APIManager;
import com.newsblur.service.NBSyncService;

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
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        final String addFeedString = getResources().getString(R.string.add_feed_message);
        final Activity activity = getActivity();
        apiManager = new APIManager(activity);

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setMessage(String.format(addFeedString, getArguments().getString(FEED_NAME)));
        builder.setPositiveButton(R.string.alert_dialog_ok, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                
                new AsyncTask<Void, Void, Boolean>() {
                    @Override
                    protected Boolean doInBackground(Void... arg) {
                        return apiManager.addFeed(getArguments().getString(FEED_ID), null);
                    }

                    @Override
                    protected void onPostExecute(Boolean result) {
                        if (result) {
                            activity.finish();
                            // trigger a sync when we return to Main so that the new feed will show up
                            NBSyncService.forceFeedsFolders();
                            AddFeedFragment.this.dismiss();
                        } else {
                            AddFeedFragment.this.dismiss();
                            Toast.makeText(activity, "Error adding feed", Toast.LENGTH_SHORT).show();
                        }
                    };
                }.execute();
            }
        });
        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                AddFeedFragment.this.dismiss();
            }
        });
        return builder.create();
    }
}
