package com.newsblur.fragment;

import android.app.Dialog;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import androidx.lifecycle.ViewModelProvider;

import com.newsblur.R;
import com.newsblur.viewModel.SaveSearchViewModel;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class SaveSearchFragment extends DialogFragment {

    private static final String FEED_ID = "feed_id";
    private static final String QUERY = "query";

    private SaveSearchViewModel viewModel;

    public static SaveSearchFragment newInstance(String feedId, String query) {
        SaveSearchFragment frag = new SaveSearchFragment();
        Bundle args = new Bundle();
        args.putString(FEED_ID, feedId);
        args.putString(QUERY, query);
        frag.setArguments(args);
        return frag;
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        viewModel = new ViewModelProvider(this).get(SaveSearchViewModel.class);
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
        builder.setMessage(String.format(getResources().getString(R.string.add_saved_search_message), getArguments().getString(QUERY)));
        builder.setPositiveButton(R.string.alert_dialog_ok, (dialogInterface, i) -> {
            viewModel.saveSearch(requireContext(), getArguments().getString(FEED_ID), getArguments().getString(QUERY));
            SaveSearchFragment.this.dismiss();
        });
        builder.setNegativeButton(R.string.alert_dialog_cancel, (dialogInterface, i) -> SaveSearchFragment.this.dismiss());
        return builder.create();
    }
}