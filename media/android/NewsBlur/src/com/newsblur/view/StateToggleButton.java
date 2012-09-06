package com.newsblur.view;

import android.content.Context;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.util.AppConstants;

public class StateToggleButton extends LinearLayout implements OnClickListener {

	private int CURRENT_STATE = AppConstants.STATE_SOME;

	private Context context;
	private StateChangedListener stateChangedListener;

	private LayoutInflater inflater;

	private View view;

	private TextView allButton;

	private TextView someButton;

	private TextView focusButton;

	public StateToggleButton(Context context, AttributeSet art) {
		super(context, art);
		this.context = context;
		setupContents();
	}

	public void setStateListener(final StateChangedListener stateChangedListener) {
		this.stateChangedListener = stateChangedListener;
	}

	public void setupContents() {
		inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
		view = inflater.inflate(R.layout.state_toggle, this);
		allButton = (TextView) view.findViewById(R.id.toggle_all);
		someButton = (TextView) view.findViewById(R.id.toggle_some);
		focusButton = (TextView) view.findViewById(R.id.toggle_focus);
		allButton.setOnClickListener(this);
		someButton.setOnClickListener(this);
		focusButton.setOnClickListener(this);
		
		setState(CURRENT_STATE);
	}

	@Override
	public void onClick(View v) {
		changeState(v.getId());
	}

	public void changeState(final int state) {
		setState(state);
		if (stateChangedListener != null) {
			stateChangedListener.changedState(CURRENT_STATE);
		}
	}

	public void setState(final int state) {
		switch (state) {
			case R.id.toggle_all:
				allButton.setEnabled(false);
				someButton.setEnabled(true);
				focusButton.setEnabled(true);
				CURRENT_STATE = AppConstants.STATE_ALL;
				break;
			case R.id.toggle_some:
				allButton.setEnabled(true);
				someButton.setEnabled(false);
				focusButton.setEnabled(true);
				CURRENT_STATE = AppConstants.STATE_SOME;
				break;
			case R.id.toggle_focus:
				allButton.setEnabled(true);
				someButton.setEnabled(true);
				focusButton.setEnabled(false);
				CURRENT_STATE = AppConstants.STATE_BEST;
				break;	
		}
	}

	public interface StateChangedListener {
		public void changedState(int state);
	}

}
