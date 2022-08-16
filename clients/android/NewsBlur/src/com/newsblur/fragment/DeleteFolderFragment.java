package com.newsblur.fragment;

import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import android.text.TextUtils;

import com.newsblur.R;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class DeleteFolderFragment extends DialogFragment {

    @Inject
    FeedUtils feedUtils;

    private static final String FOLDER_NAME = "folder_name";
    private static final String FOLDER_PARENT = "folder_parent";

    public static DeleteFolderFragment newInstance(String folderName, String folderParent) {
        DeleteFolderFragment frag = new DeleteFolderFragment();
        Bundle args = new Bundle();
        args.putString(FOLDER_NAME, folderName);
        args.putString(FOLDER_PARENT, folderParent);
        frag.setArguments(args);
        return frag;
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(@Nullable Bundle savedInstanceState) {
        final String folderName = getArguments().getString(FOLDER_NAME);
        final String folderParent = getArguments().getString(FOLDER_PARENT);
        AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
        builder.setMessage(getResources().getString(R.string.delete_folder_message, folderName));
        builder.setPositiveButton(R.string.alert_dialog_ok, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                String inFolder = "";
                if (!TextUtils.isEmpty(folderParent) && !folderParent.equals(AppConstants.ROOT_FOLDER)) {
                    inFolder = folderParent;
                }
                feedUtils.deleteFolder(folderName, inFolder, getActivity());
                DeleteFolderFragment.this.dismiss();
            }
        });
        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                DeleteFolderFragment.this.dismiss();
            }
        });
        return builder.create();
    }
}