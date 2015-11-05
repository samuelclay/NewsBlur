package com.newsblur.view;

import android.content.Context;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.LinearLayout;

import com.newsblur.R;
import com.newsblur.util.StateFilter;

public class StateToggleButton extends LinearLayout implements OnClickListener {

	private StateFilter currentState = StateFilter.SOME;

	private Context context;
	private StateChangedListener stateChangedListener;

	private LayoutInflater inflater;

	private View view;

	private View allButton;

	private View someButton;

	private View focusButton;

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
		allButton = (View) view.findViewById(R.id.toggle_all);
		someButton = (View) view.findViewById(R.id.toggle_some);
		focusButton = (View) view.findViewById(R.id.toggle_focus);
		allButton.setOnClickListener(this);
		someButton.setOnClickListener(this);
		focusButton.setOnClickListener(this);
		
		setState(currentState);
	}

	@Override
	public void onClick(View v) {
        if (v.getId() == R.id.toggle_all) {
		    changeState(StateFilter.ALL);
        } else if (v.getId() == R.id.toggle_some) {
            changeState(StateFilter.SOME);
        } else if (v.getId() == R.id.toggle_focus) {
            changeState(StateFilter.BEST);
        }
	}

	public void changeState(StateFilter state) {
		setState(state);
		if (stateChangedListener != null) {
			stateChangedListener.changedState(currentState);
		}
	}

	public void setState(StateFilter state) {
        currentState = state;
		if (state == StateFilter.ALL) {
			allButton.setEnabled(false);
			someButton.setEnabled(true);
			focusButton.setEnabled(true);
		} else if (state == StateFilter.SOME) {
			allButton.setEnabled(true);
			someButton.setEnabled(false);
			focusButton.setEnabled(true);
		} else if (state == StateFilter.BEST) {
			allButton.setEnabled(true);
			someButton.setEnabled(true);
			focusButton.setEnabled(false);
		}
	}

	public interface StateChangedListener {
		public void changedState(StateFilter state);
	}

}
