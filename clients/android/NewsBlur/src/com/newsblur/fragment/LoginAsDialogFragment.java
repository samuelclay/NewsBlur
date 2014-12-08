package com.newsblur.fragment;

import android.app.AlertDialog;
import android.app.Dialog;
import android.app.DialogFragment;
import android.content.DialogInterface;
import android.os.AsyncTask;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.EditText;

import com.newsblur.R;

/**
 * Created by mark on 08/12/2014.
 */
public class LoginAsDialogFragment extends DialogFragment {

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
        builder.setTitle(R.string.loginas_title);

        LayoutInflater layoutInflater = LayoutInflater.from(getActivity());
        View usernameView = layoutInflater.inflate(R.layout.loginas_dialog, null);
        builder.setView(usernameView);
        final EditText username = (EditText) usernameView.findViewById(R.id.username_field);

        builder.setPositiveButton(R.string.alert_dialog_ok, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {

                // TODO
                LoginAsDialogFragment.this.dismiss();
            }
        });
        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                LoginAsDialogFragment.this.dismiss();
            }
        });
        return builder.create();
    }
}
