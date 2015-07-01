package com.newsblur.fragment;

import com.newsblur.R;
import com.newsblur.activity.Main;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;
import com.newsblur.network.APIManager;
import com.newsblur.util.FeedUtils;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.app.DialogFragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

public class DeleteFeedFragment extends DialogFragment {
    private static final String FEED_TYPE = "feed_type";
	private static final String FEED_ID = "feed_id";
	private static final String FEED_NAME = "feed_name";
	private static final String FOLDER_NAME = "folder_name";
    private static final String NORMAL_FEED = "normal";
    private static final String SOCIAL_FEED = "social";
    
    public static DeleteFeedFragment newInstance(Feed feed, String folderName) {
    	DeleteFeedFragment frag = new DeleteFeedFragment();
		Bundle args = new Bundle();
        args.putString(FEED_TYPE, NORMAL_FEED);
		args.putString(FEED_ID, feed.feedId);
		args.putString(FEED_NAME, feed.title);
		args.putString(FOLDER_NAME, folderName);
		frag.setArguments(args);
		return frag;
	}

    public static DeleteFeedFragment newInstance(SocialFeed feed) {
    	DeleteFeedFragment frag = new DeleteFeedFragment();
		Bundle args = new Bundle();
        args.putString(FEED_TYPE, SOCIAL_FEED);
		args.putString(FEED_ID, feed.userId);
		args.putString(FEED_NAME, feed.username);
		frag.setArguments(args);
		return frag;
	}

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
        if (getArguments().getString(FEED_TYPE).equals(NORMAL_FEED)) {
            builder.setMessage(String.format(getResources().getString(R.string.delete_feed_message), getArguments().getString(FEED_NAME)));
        } else {
            builder.setMessage(String.format(getResources().getString(R.string.unfollow_message), getArguments().getString(FEED_NAME)));
        }
        builder.setPositiveButton(R.string.alert_dialog_ok, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                if (getArguments().getString(FEED_TYPE).equals(NORMAL_FEED)) {
                    FeedUtils.deleteFeed(getArguments().getString(FEED_ID), getArguments().getString(FOLDER_NAME), getActivity(), new APIManager(getActivity()));
                } else {
                    FeedUtils.deleteSocialFeed(getArguments().getString(FEED_ID), getActivity(), new APIManager(getActivity()));
                }
                // if called from main view then refresh otherwise it was
                // called from the feed view so finish
                Activity activity = DeleteFeedFragment.this.getActivity();
                if (activity instanceof Main) {
                    ((Main)activity).handleUpdate(true);
                } else {
                    activity.finish();
                }
                DeleteFeedFragment.this.dismiss();
            }
        });
        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                DeleteFeedFragment.this.dismiss();
            }
        });
        return builder.create();
    }
}
