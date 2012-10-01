package com.newsblur.fragment;


import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;

import com.newsblur.R;

public class TextSizeDialogFragment extends DialogFragment {
	
	private static String CURRENT_SIZE = "currentSize";
	private static String LISTENER = "listener";
	private float currentValue = 1.0f;
	private SeekBar seekBar;

	public static TextSizeDialogFragment newInstance(float currentValue) {
		TextSizeDialogFragment dialog = new TextSizeDialogFragment();
		Bundle args = new Bundle();
		args.putFloat(CURRENT_SIZE, currentValue);
		dialog.setArguments(args);
		
		return dialog;
	}
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		this.currentValue = getArguments().getFloat(CURRENT_SIZE);
		View v = inflater.inflate(R.layout.textsize_slider_dialog, null);
		seekBar = (SeekBar) v.findViewById(R.id.textSizeSlider);
		seekBar.setProgress((int) (currentValue * 2));
		
		getDialog().getWindow().setFlags(WindowManager.LayoutParams.FLAG_DITHER, WindowManager.LayoutParams.FLAG_DITHER);
		getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
		getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;
		
		seekBar.setOnSeekBarChangeListener((OnSeekBarChangeListener) getActivity());
		
		return v;
	}
	
}
