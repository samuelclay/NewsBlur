package com.newsblur.fragment;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.EditText;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.Main;
import com.newsblur.network.APIManager;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

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

                APIManager apiManager = new APIManager(getActivity());
                LoginAsTask loginTask = new LoginAsTask(apiManager, username.getText().toString(), getActivity());
                loginTask.execute();

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

    private class LoginAsTask extends AsyncTask<Void, Void, Boolean> {

        private final APIManager apiManager;
        private final String username;
        private final Activity activity;

        public LoginAsTask(APIManager apiManager, String username, Activity activity) {
            this.apiManager = apiManager;
            this.username = username;
            this.activity = activity;
        }

        @Override
        protected Boolean doInBackground(Void... params) {
            boolean result = apiManager.loginAs(username);
            if (result) {
                PrefsUtils.clearPrefsAndDbForLoginAs(activity);
                apiManager.updateUserProfile();
            }
            return result;
        }

        @Override
        protected void onPostExecute(Boolean result) {
            if (result) {
                Intent startMain = new Intent(activity, Main.class);
                activity.startActivity(startMain);
            } else {
                UIUtils.safeToast(activity, "Login as " + username + " failed", Toast.LENGTH_LONG);
            }
        }
    }
}
