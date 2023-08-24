package com.newsblur.fragment;

import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;

import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.util.PrefsUtils;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class LogoutDialogFragment extends DialogFragment {

    @Inject
    BlurDatabaseHelper dbHelper;

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
        builder.setTitle(getResources().getString(R.string.logout_warning));
        builder.setPositiveButton(R.string.alert_dialog_ok, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                PrefsUtils.logout(getActivity(), dbHelper);
                // make sure the instance of Main that called us is killed now, or else the system
                // might try to recycle it with a stale login ID, which will cause it to self-destruct
                getActivity().finish();
            }
        });
        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                LogoutDialogFragment.this.dismiss();
            }
        });
        return builder.create();
    }

}
