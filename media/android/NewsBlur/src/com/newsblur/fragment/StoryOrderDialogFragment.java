package com.newsblur.fragment;


import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.RadioButton;

import com.newsblur.R;
import com.newsblur.util.StoryOrder;

public class StoryOrderDialogFragment extends DialogFragment {
	
	private static String CURRENT_ORDER = "currentOrder";

	public static StoryOrderDialogFragment newInstance(StoryOrder currentValue) {
		StoryOrderDialogFragment dialog = new StoryOrderDialogFragment();
		Bundle args = new Bundle();
		args.putSerializable(CURRENT_ORDER, currentValue);
		dialog.setArguments(args);
		
		return dialog;
	}
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		StoryOrder currentValue = (StoryOrder) getArguments().getSerializable(CURRENT_ORDER);
		View v = inflater.inflate(R.layout.storyorder_dialog, null);
		RadioButton newestButton = (RadioButton) v.findViewById(R.id.radio_newest);
		RadioButton oldestButton = (RadioButton) v.findViewById(R.id.radio_oldest);
		if (currentValue == StoryOrder.NEWEST) {
		    newestButton.setChecked(true);
		} else {
            oldestButton.setChecked(true);
		}
		
		getDialog().getWindow().setFlags(WindowManager.LayoutParams.FLAG_DITHER, WindowManager.LayoutParams.FLAG_DITHER);
		getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
		getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;
		
		//seekBar.setOnSeekBarChangeListener((OnSeekBarChangeListener) getActivity());
		
		return v;
	}
	
}
