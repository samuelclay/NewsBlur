package com.newsblur.fragment;

import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;

import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;

import com.newsblur.R;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class AlertDialogFragment extends DialogFragment {
    private static final String MESSAGE = "message";

    public static AlertDialogFragment newAlertDialogFragment(String message) {
        AlertDialogFragment fragment = new AlertDialogFragment();
        Bundle args = new Bundle();
        args.putString(MESSAGE, message);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
        builder.setMessage(getArguments().getString(MESSAGE));
        builder.setPositiveButton(R.string.alert_dialog_ok, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                AlertDialogFragment.this.dismiss();
            }
        });
        return builder.create();
    }
}
