package com.newsblur.fragment;

import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;

import com.newsblur.R;
import com.newsblur.util.FeedUtils;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class SaveSearchFragment extends DialogFragment {

    @Inject
    FeedUtils feedUtils;

    private static final String FEED_ID = "feed_id";
    private static final String QUERY = "query";

    public static SaveSearchFragment newInstance(String feedId, String query) {
        SaveSearchFragment frag = new SaveSearchFragment();
        Bundle args = new Bundle();
        args.putString(FEED_ID, feedId);
        args.putString(QUERY, query);
        frag.setArguments(args);
        return frag;
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
        builder.setMessage(String.format(getResources().getString(R.string.add_saved_search_message), getArguments().getString(QUERY)));
        builder.setPositiveButton(R.string.alert_dialog_ok, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                feedUtils.saveSearch(getArguments().getString(FEED_ID), getArguments().getString(QUERY), getActivity());
                SaveSearchFragment.this.dismiss();
            }
        });
        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                SaveSearchFragment.this.dismiss();
            }
        });
        return builder.create();
    }
}