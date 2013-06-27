package com.newsblur.fragment;

import com.newsblur.R;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;

public class MarkAllReadDialogFragment extends DialogFragment {
    private static final String FOLDER_NAME = "folder_name";
    
    public interface MarkAllReadDialogListener {
        public void onMarkAllRead();
        public void onCancel();
    }
    
    private MarkAllReadDialogListener listener;
    
    public static MarkAllReadDialogFragment newInstance(String folderName) {
        MarkAllReadDialogFragment fragment = new MarkAllReadDialogFragment();
        Bundle args = new Bundle();
        args.putString(FOLDER_NAME, folderName);
        fragment.setArguments(args);
        return fragment;
    }
    
    @Override
    public void onAttach(Activity activity) {
        super.onAttach(activity);
        listener = (MarkAllReadDialogListener)activity;
    }

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
        builder.setTitle(getArguments().getString(FOLDER_NAME))
               .setItems(R.array.mark_all_read_options, new DialogInterface.OnClickListener() {
                   public void onClick(DialogInterface dialog, int which) {
                       if (which == 0) {
                           listener.onMarkAllRead();
                       } else {
                           listener.onCancel();
                       }

               }
        });
        return builder.create();
    }
}
