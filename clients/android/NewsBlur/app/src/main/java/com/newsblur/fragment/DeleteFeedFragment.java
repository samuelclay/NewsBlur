package com.newsblur.fragment;

import android.app.Activity;
import android.app.Dialog;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import androidx.lifecycle.ViewModelProvider;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SavedSearch;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.UIUtils;
import com.newsblur.viewModel.DeleteFeedViewModel;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class DeleteFeedFragment extends DialogFragment {

    private static final String FEED_TYPE = "feed_type";
    private static final String FEED_ID = "feed_id";
    private static final String FEED_NAME = "feed_name";
    private static final String FOLDER_NAME = "folder_name";
    private static final String NORMAL_FEED = "normal";
    private static final String SOCIAL_FEED = "social";
    private static final String SAVED_SEARCH_FEED = "saved_search";
    private static final String QUERY = "query";

    private DeleteFeedViewModel viewModel;

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
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        viewModel = new ViewModelProvider(this).get(DeleteFeedViewModel.class);
    }

    @NonNull
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
        builder.setPositiveButton(R.string.alert_dialog_ok, (dialogInterface, i) -> {
            if (getArguments().getString(FEED_TYPE).equals(NORMAL_FEED)) {
                viewModel.deleteFeed(getArguments().getString(FEED_ID), getArguments().getString(FOLDER_NAME));
            } else if (getArguments().getString(FEED_TYPE).equals(SAVED_SEARCH_FEED)) {
                viewModel.deleteSavedSearch(getArguments().getString(FEED_ID), getArguments().getString(QUERY));
            } else {
                viewModel.deleteSocialFeed(getArguments().getString(FEED_ID));
            }
            // if called from a feed view, end it
            Activity activity = DeleteFeedFragment.this.getActivity();
            if (activity instanceof ItemsList) {
                activity.finish();
            }
            DeleteFeedFragment.this.dismiss();
        });
        builder.setNegativeButton(R.string.alert_dialog_cancel, (dialogInterface, i) -> DeleteFeedFragment.this.dismiss());
        return builder.create();
    }
}
