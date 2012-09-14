package com.newsblur.fragment;

import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.network.APIManager;

public class LogoutDialogFragment extends DialogFragment {

	private APIManager apiManager;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		setStyle(DialogFragment.STYLE_NO_TITLE, R.style.dialog);
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		final String shareString = getResources().getString(R.string.share_newsblur);
		
		apiManager = new APIManager(getActivity());
		View v = inflater.inflate(R.layout.fragment_dialog, container, false);
		final TextView message = (TextView) v.findViewById(R.id.dialog_message);
		final EditText comment = (EditText) v.findViewById(R.id.dialog_share_comment);
		message.setText(getActivity().getResources().getString(R.string.logout_warning));
		
		Button okayButton = (Button) v.findViewById(R.id.dialog_button_okay);
		okayButton.setOnClickListener(new OnClickListener() {
			public void onClick(final View v) {
				
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
