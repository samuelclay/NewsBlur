package com.newsblur.fragment;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.view.LayoutInflater;
import android.view.View;

import com.newsblur.R;
import com.newsblur.databinding.DialogRenameFeedBinding;
import com.newsblur.domain.Feed;
import com.newsblur.util.FeedUtils;

public class RenameFeedFragment extends DialogFragment {

	private Feed feed;
	private DialogRenameFeedBinding binding;

    public static RenameFeedFragment newInstance(Feed feed) {
		RenameFeedFragment fragment = new RenameFeedFragment();
		Bundle args = new Bundle();
		args.putSerializable("feed", feed);
		fragment.setArguments(args);
		return fragment;
	}

	@Override
	public Dialog onCreateDialog(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		feed = (Feed) getArguments().getSerializable("feed");

        final Activity activity = getActivity();
        LayoutInflater inflater = LayoutInflater.from(activity);
        View v = inflater.inflate(R.layout.dialog_rename_feed, null);
        binding = DialogRenameFeedBinding.bind(v);

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle(String.format(getResources().getString(R.string.title_rename_feed), feed.title));
        builder.setView(v);

        binding.feedNameField.setText(feed.title);

        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                RenameFeedFragment.this.dismiss();
            }
        });
        builder.setPositiveButton(R.string.feed_name_save, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                FeedUtils.renameFeed(activity, feed.feedId, binding.feedNameField.getText().toString());
                RenameFeedFragment.this.dismiss();
            }
        });

        Dialog dialog = builder.create();
        return dialog;
	}

}

