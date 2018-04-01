package com.newsblur.fragment;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.NbActivity;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;
import com.newsblur.network.APIManager;
import com.newsblur.util.FeedUtils;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;

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
                // if called from a feed view, end it
                Activity activity = DeleteFeedFragment.this.getActivity();
                if (activity instanceof ItemsList) {
                    activity.finish();
                }
                NbActivity.updateAllActivities(NbActivity.UPDATE_METADATA);
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
