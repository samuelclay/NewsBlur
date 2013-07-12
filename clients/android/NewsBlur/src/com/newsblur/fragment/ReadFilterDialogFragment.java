package com.newsblur.fragment;


import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.RadioButton;

import com.newsblur.R;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.ReadFilterChangedListener;

public class ReadFilterDialogFragment extends DialogFragment implements OnClickListener {
	
	private static String CURRENT_FILTER = "currentFilter";
	private ReadFilter currentValue;

	public static ReadFilterDialogFragment newInstance(ReadFilter currentValue) {
		ReadFilterDialogFragment dialog = new ReadFilterDialogFragment();
		Bundle args = new Bundle();
		args.putSerializable(CURRENT_FILTER, currentValue);
		dialog.setArguments(args);
		
		return dialog;
	}
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		currentValue = (ReadFilter) getArguments().getSerializable(CURRENT_FILTER);
		View v = inflater.inflate(R.layout.readfilter_dialog, null);
		RadioButton allButton = (RadioButton) v.findViewById(R.id.radio_all);
		allButton.setOnClickListener(this);
		allButton.setChecked(currentValue == ReadFilter.ALL);
		RadioButton unreadButton = (RadioButton) v.findViewById(R.id.radio_unread);
		unreadButton.setOnClickListener(this);
		unreadButton.setChecked(currentValue == ReadFilter.UNREAD);
		
		getDialog().getWindow().setFlags(WindowManager.LayoutParams.FLAG_DITHER, WindowManager.LayoutParams.FLAG_DITHER);
		getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
		getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;
		
		return v;
	}

    @Override
    public void onClick(View v) {
        ReadFilterChangedListener listener = (ReadFilterChangedListener)getActivity();
        if (v.getId() == R.id.radio_all) {
            if (currentValue == ReadFilter.UNREAD) {
                listener.readFilterChanged(ReadFilter.ALL);
            }
        } else {
            if (currentValue == ReadFilter.ALL) {
                listener.readFilterChanged(ReadFilter.UNREAD);
            }
        }
        
        dismiss();
    }
}
