package com.newsblur.fragment;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.DialogFragment;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.Main;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.AddFeedResponse;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.UIUtils;

public class AddFeedFragment extends DialogFragment {

	private static final String FEED_URI = "feed_url";
	private static final String FEED_NAME = "feed_name";

	public static AddFeedFragment newInstance(String feedUri, String feedName) {
		AddFeedFragment frag = new AddFeedFragment();
		Bundle args = new Bundle();
		args.putString(FEED_URI, feedUri);
		args.putString(FEED_NAME, feedName);
		frag.setArguments(args);
		return frag;
	}

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        final String addFeedString = getResources().getString(R.string.add_feed_message);
        final Activity activity = getActivity();
        final APIManager apiManager = new APIManager(activity);
        final Intent intent = new Intent(activity, Main.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setMessage(String.format(addFeedString, getArguments().getString(FEED_NAME)));
        builder.setPositiveButton(R.string.alert_dialog_ok, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                
                new AsyncTask<Void, Void, AddFeedResponse>() {
                    @Override
                    protected AddFeedResponse doInBackground(Void... arg) {
                        ((AddFeedProgressListener) activity).addFeedStarted();
                        return apiManager.addFeed(getArguments().getString(FEED_URI));
                    }

                    @Override
                    protected void onPostExecute(AddFeedResponse result) {
                        if (!result.isError()) {
                            // trigger a sync when we return to Main so that the new feed will show up
                            NBSyncService.forceFeedsFolders();
                            intent.putExtra(Main.EXTRA_FORCE_SHOW_FEED_ID, result.feed.feedId);
                        } else {
                            UIUtils.safeToast(activity, R.string.add_feed_error, Toast.LENGTH_SHORT);
                        }
                        activity.startActivity(intent);
                        activity.finish();
                        AddFeedFragment.this.dismiss();
                    };
                }.execute();
            }
        });
        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                AddFeedFragment.this.dismiss();
                activity.startActivity(intent);
                activity.finish();
            }
        });
        return builder.create();
    }

    public interface AddFeedProgressListener {
        public abstract void addFeedStarted();
    }
}
