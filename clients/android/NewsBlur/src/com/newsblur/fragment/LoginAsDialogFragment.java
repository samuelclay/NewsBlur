package com.newsblur.fragment;

import android.app.AlertDialog;
import android.app.Dialog;
import android.app.DialogFragment;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.EditText;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.Login;
import com.newsblur.activity.Main;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.NewsBlurResponse;
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
                PrefsUtils.logoutForLoginAs(getActivity());

                APIManager apiManager = new APIManager(getActivity());
                LoginAsTask loginTask = new LoginAsTask(apiManager, username.getText().toString());
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

    private class LoginAsTask extends AsyncTask<Void, Void, NewsBlurResponse> {

        private final APIManager apiManager;
        private final String username;

        public LoginAsTask(APIManager apiManager, String username) {
            this.apiManager = apiManager;
            this.username = username;
        }

        @Override
        protected NewsBlurResponse doInBackground(Void... params) {
            return apiManager.loginAs(username);
        }

        @Override
        protected void onPostExecute(NewsBlurResponse result) {
            if (!result.isError()) {
                apiManager.updateUserProfile();

                Intent startMain = new Intent(getActivity(), Main.class);
                getActivity().startActivity(startMain);
            } else {
                UIUtils.safeToast(getActivity(), result.getErrorMessage(), Toast.LENGTH_LONG);

                // TODO we should be able to restart main since our login cookie still exists but
                // this fails
                Intent startMain = new Intent(getActivity(), Main.class);
                getActivity().startActivity(startMain);
            }
        }
    }
}
