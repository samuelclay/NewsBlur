package com.newsblur.fragment;

import android.content.Intent;
import android.content.SharedPreferences;
import android.database.sqlite.SQLiteDatabase;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.Login;
import com.newsblur.database.BlurDatabase;
import com.newsblur.network.APIManager;
import com.newsblur.util.PrefConstants;

public class LogoutDialogFragment extends DialogFragment {

	protected static final String TAG = "LogoutDialogFragment";
	private APIManager apiManager;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		setStyle(DialogFragment.STYLE_NO_TITLE, R.style.dialog);
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		
		apiManager = new APIManager(getActivity());
		View v = inflater.inflate(R.layout.fragment_logout_dialog, container, false);
		final TextView message = (TextView) v.findViewById(R.id.dialog_message);
		message.setText(getActivity().getResources().getString(R.string.logout_warning));
		
		Button okayButton = (Button) v.findViewById(R.id.dialog_button_okay);
		okayButton.setOnClickListener(new OnClickListener() {
			public void onClick(final View v) {
				SharedPreferences preferences = getActivity().getSharedPreferences(PrefConstants.PREFERENCES, 0);
				preferences.edit().clear().commit();
				
				BlurDatabase databaseHelper = new BlurDatabase(getActivity().getApplicationContext());
				databaseHelper.dropAndRecreateTables();
				
				Intent i = new Intent(getActivity(), Login.class);
				i.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
				startActivity(i);
			}
		});
		
		Button cancelButton = (Button) v.findViewById(R.id.dialog_button_cancel);
		cancelButton.setOnClickListener(new OnClickListener() {
			public void onClick(View v) {
				LogoutDialogFragment.this.dismiss();
			}
		});

		return v;
	}

}
