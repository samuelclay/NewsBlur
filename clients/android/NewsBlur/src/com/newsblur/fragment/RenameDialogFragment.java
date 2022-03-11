package com.newsblur.fragment;

import android.app.Activity;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.databinding.DialogRenameBinding;
import com.newsblur.domain.Feed;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class RenameDialogFragment extends DialogFragment {

    @Inject
    FeedUtils feedUtils;

    private static final String FEED = "feed";
    private static final String FOLDER = "folder";
    private static final String FOLDER_NAME = "folder_name";
    private static final String FOLDER_PARENT = "folder_parent";
    private static final String RENAME_TYPE = "rename_type";

    public static RenameDialogFragment newInstance(Feed feed) {
        RenameDialogFragment fragment = new RenameDialogFragment();
        Bundle args = new Bundle();
        args.putSerializable(FEED, feed);
        args.putString(RENAME_TYPE, FEED);
        fragment.setArguments(args);
        return fragment;
    }

    public static RenameDialogFragment newInstance(String folderName, String folderParent) {
        RenameDialogFragment fragment = new RenameDialogFragment();
        Bundle args = new Bundle();
        args.putString(FOLDER_NAME, folderName);
        args.putString(FOLDER_PARENT, folderParent);
        args.putString(RENAME_TYPE, FOLDER);
        fragment.setArguments(args);
        return fragment;
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        final Activity activity = getActivity();
        LayoutInflater inflater = LayoutInflater.from(activity);
        View v = inflater.inflate(R.layout.dialog_rename, null);
        final DialogRenameBinding binding = DialogRenameBinding.bind(v);

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setView(v);
        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                RenameDialogFragment.this.dismiss();
            }
        });
        if (getArguments().getString(RENAME_TYPE).equals(FEED)) {
            final Feed feed = (Feed) getArguments().getSerializable(FEED);
            builder.setTitle(String.format(getResources().getString(R.string.title_rename_feed), feed.title));
            binding.inputName.setText(feed.title);
            builder.setPositiveButton(R.string.feed_name_save, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialogInterface, int i) {
                    feedUtils.renameFeed(activity, feed.feedId, binding.inputName.getText().toString());
                    RenameDialogFragment.this.dismiss();
                }
            });
        } else { // FOLDER
            final String folderName = getArguments().getString(FOLDER_NAME);
            final String folderParentName = getArguments().getString(FOLDER_PARENT);

            builder.setTitle(String.format(getResources().getString(R.string.title_rename_folder), folderName));
            binding.inputName.setText(folderName);

            builder.setPositiveButton(R.string.folder_name_save, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialogInterface, int i) {
                    String newFolderName = binding.inputName.getText().toString();
                    if (TextUtils.isEmpty(newFolderName)) {
                        Toast.makeText(activity, R.string.add_folder_name, Toast.LENGTH_SHORT).show();
                        return;
                    }

                    String inFolder = "";
                    if (!TextUtils.isEmpty(folderParentName) && !folderParentName.equals(AppConstants.ROOT_FOLDER)) {
                        inFolder = folderParentName;
                    }
                    feedUtils.renameFolder(folderName, newFolderName, inFolder, activity);
                    RenameDialogFragment.this.dismiss();
                }
            });
        }

        return builder.create();
    }
}
