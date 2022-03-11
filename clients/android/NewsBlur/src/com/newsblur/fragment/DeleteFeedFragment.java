package com.newsblur.fragment;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SavedSearch;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;

import android.app.Activity;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;

import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class DeleteFeedFragment extends DialogFragment {

    @Inject
    FeedUtils feedUtils;

    private static final String FEED_TYPE = "feed_type";
	private static final String FEED_ID = "feed_id";
	private static final String FEED_NAME = "feed_name";
	private static final String FOLDER_NAME = "folder_name";
    private static final String NORMAL_FEED = "normal";
    private static final String SOCIAL_FEED = "social";
    private static final String SAVED_SEARCH_FEED = "saved_search";
    private static final String QUERY = "query";

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

	public static DeleteFeedFragment newInstance(SavedSearch savedSearch) {
        DeleteFeedFragment frag = new DeleteFeedFragment();
        Bundle args = new Bundle();
        args.putString(FEED_TYPE, SAVED_SEARCH_FEED);
        args.putString(FEED_ID, savedSearch.feedId);
        args.putString(FEED_NAME, savedSearch.feedTitle);
        args.putString(QUERY, savedSearch.query);
        frag.setArguments(args);
        return frag;
    }

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
        if (getArguments().getString(FEED_TYPE).equals(NORMAL_FEED)) {
            builder.setMessage(String.format(getResources().getString(R.string.delete_feed_message), getArguments().getString(FEED_NAME)));
        } else if (getArguments().getString(FEED_TYPE).equals(SAVED_SEARCH_FEED)) {
            String message = String.format(getResources().getString(R.string.delete_saved_search_message), getArguments().getString(FEED_NAME));
            builder.setMessage(UIUtils.fromHtml(message));
        } else {
            builder.setMessage(String.format(getResources().getString(R.string.unfollow_message), getArguments().getString(FEED_NAME)));
        }
        builder.setPositiveButton(R.string.alert_dialog_ok, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                if (getArguments().getString(FEED_TYPE).equals(NORMAL_FEED)) {
                    feedUtils.deleteFeed(getArguments().getString(FEED_ID), getArguments().getString(FOLDER_NAME), getActivity());
                } else if (getArguments().getString(FEED_TYPE).equals(SAVED_SEARCH_FEED)) {
                    feedUtils.deleteSavedSearch(getArguments().getString(FEED_ID), getArguments().getString(QUERY), getActivity());
                } else {
                    feedUtils.deleteSocialFeed(getArguments().getString(FEED_ID), getActivity());
                }
                // if called from a feed view, end it
                Activity activity = DeleteFeedFragment.this.getActivity();
                if (activity instanceof ItemsList) {
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
