package com.newsblur.fragment;


import android.os.Bundle;
import android.app.DialogFragment;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;

import com.newsblur.R;
import com.newsblur.util.AppConstants;

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

        int currentSizeIndex = 0;
        for (int i=0; i<AppConstants.READING_FONT_SIZE.length; i++) {
            if (currentValue >= AppConstants.READING_FONT_SIZE[i]) currentSizeIndex = i;
        }
		seekBar = (SeekBar) v.findViewById(R.id.textSizeSlider);
		seekBar.setProgress(currentSizeIndex);
		
		getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
		getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;
		
		seekBar.setOnSeekBarChangeListener((OnSeekBarChangeListener) getActivity());
		
		return v;
	}
	
}
