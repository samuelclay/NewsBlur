package com.newsblur.view;

import android.content.Context;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.LinearLayout;

import butterknife.ButterKnife;
import butterknife.FindView;
import butterknife.OnClick;

import com.newsblur.R;
import com.newsblur.util.StateFilter;

public class StateToggleButton extends LinearLayout {

	private StateFilter currentState = StateFilter.SOME;

	private StateChangedListener stateChangedListener;

	@FindView(R.id.toggle_all) View allButton;
	@FindView(R.id.toggle_some) View someButton;
	@FindView(R.id.toggle_focus) View focusButton;
    @FindView(R.id.toggle_saved) View savedButton;

	public StateToggleButton(Context context, AttributeSet art) {
		super(context, art);
		LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
		View view = inflater.inflate(R.layout.state_toggle, this);
        ButterKnife.bind(this, view);
		setState(currentState);
	}

	public void setStateListener(final StateChangedListener stateChangedListener) {
		this.stateChangedListener = stateChangedListener;
	}

	@OnClick({R.id.toggle_all, R.id.toggle_some, R.id.toggle_focus, R.id.toggle_saved})
	public void onClickToggle(View v) {
        if (v.getId() == R.id.toggle_all) {
		    changeState(StateFilter.ALL);
        } else if (v.getId() == R.id.toggle_some) {
            changeState(StateFilter.SOME);
        } else if (v.getId() == R.id.toggle_focus) {
            changeState(StateFilter.BEST);
        } else if (v.getId() == R.id.toggle_saved) {
            changeState(StateFilter.SAVED);
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
            savedButton.setEnabled(true);
		} else if (state == StateFilter.SOME) {
			allButton.setEnabled(true);
			someButton.setEnabled(false);
			focusButton.setEnabled(true);
            savedButton.setEnabled(true);
		} else if (state == StateFilter.BEST) {
			allButton.setEnabled(true);
			someButton.setEnabled(true);
			focusButton.setEnabled(false);
            savedButton.setEnabled(true);
		} else if (state == StateFilter.SAVED) {
			allButton.setEnabled(true);
			someButton.setEnabled(true);
			focusButton.setEnabled(true);
            savedButton.setEnabled(false);
        }
	}

	public interface StateChangedListener {
		public void changedState(StateFilter state);
	}

}
