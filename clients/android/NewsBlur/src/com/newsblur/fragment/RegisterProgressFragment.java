package com.newsblur.fragment;

import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.AnimationUtils;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.Toast;
import android.widget.ViewSwitcher;

import butterknife.ButterKnife;
import butterknife.Bind;
import butterknife.OnClick;

import com.newsblur.R;
import com.newsblur.activity.AddSocial;
import com.newsblur.activity.Login;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.RegisterResponse;

public class RegisterProgressFragment extends Fragment {

    private APIManager apiManager;

    private String username;
    private String password;
    private String email;
    private RegisterTask registerTask;
    @Bind(R.id.register_viewswitcher) ViewSwitcher switcher;
    @Bind(R.id.registering_next_1) Button next;
    @Bind(R.id.registerprogress_logo) ImageView registerProgressLogo;

    public static RegisterProgressFragment getInstance(String username, String password, String email) {
        RegisterProgressFragment fragment = new RegisterProgressFragment();
        Bundle bundle = new Bundle();
        bundle.putString("username", username);
        bundle.putString("password", password);
        bundle.putString("email", email);
        fragment.setArguments(bundle);
        return fragment;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setRetainInstance(true);
        apiManager = new APIManager(getActivity());

        username = getArguments().getString("username");
        password = getArguments().getString("password");
        email = getArguments().getString("email");
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View v = inflater.inflate(R.layout.fragment_registerprogress, null);
        ButterKnife.bind(this, v);

        registerProgressLogo.startAnimation(AnimationUtils.loadAnimation(getActivity(), R.anim.rotate));

        if (registerTask != null) {
            switcher.showNext();
        } else {
            registerTask = new RegisterTask();
            registerTask.execute();
        }

        return v;
    }

    @OnClick(R.id.registering_next_1) void next() {
        Intent i = new Intent(getActivity(), AddSocial.class);
        startActivity(i);
    }

    private class RegisterTask extends AsyncTask<Void, Void, RegisterResponse> {

        @Override
        protected RegisterResponse doInBackground(Void... params) {
            return apiManager.signup(username, password, email);
        }

        @Override
        protected void onPostExecute(RegisterResponse response) {
            if (response.authenticated) {
                switcher.showNext();
            } else {
                String errorMessage = response.getErrorMessage();
                if(errorMessage == null) {
                    errorMessage = getResources().getString(R.string.register_message_error);
                }
                Toast.makeText(getActivity(), errorMessage, Toast.LENGTH_LONG).show();
                startActivity(new Intent(getActivity(), Login.class));
            }
        }

    }


}
