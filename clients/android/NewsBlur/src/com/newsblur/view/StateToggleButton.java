package com.newsblur.view;

import android.animation.LayoutTransition;
import android.content.Context;
import android.os.Build;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;

import butterknife.ButterKnife;
import butterknife.Bind;
import butterknife.OnClick;

import com.newsblur.R;
import com.newsblur.util.StateFilter;

public class StateToggleButton extends LinearLayout {

	private StateFilter currentState = StateFilter.SOME;

	private StateChangedListener stateChangedListener;

	@Bind(R.id.toggle_all) ViewGroup allButton;
	@Bind(R.id.toggle_all_icon) View allButtonIcon;
	@Bind(R.id.toggle_all_text) View allButtonText;
	@Bind(R.id.toggle_some) ViewGroup someButton;
	@Bind(R.id.toggle_some_icon) View someButtonIcon;
	@Bind(R.id.toggle_some_text) View someButtonText;
	@Bind(R.id.toggle_focus) ViewGroup focusButton;
	@Bind(R.id.toggle_focus_icon) View focusButtonIcon;
	@Bind(R.id.toggle_focus_text) View focusButtonText;
    @Bind(R.id.toggle_saved) ViewGroup savedButton;
    @Bind(R.id.toggle_saved_icon) View savedButtonIcon;
    @Bind(R.id.toggle_saved_text) View savedButtonText;

	public StateToggleButton(Context context, AttributeSet art) {
		super(context, art);
		LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
		View view = inflater.inflate(R.layout.state_toggle, this);
        ButterKnife.bind(this, view);

        // this just smooths out toggle transitions on newer devices
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
            allButton.getLayoutTransition().enableTransitionType(LayoutTransition.CHANGING);
            someButton.getLayoutTransition().enableTransitionType(LayoutTransition.CHANGING);
            focusButton.getLayoutTransition().enableTransitionType(LayoutTransition.CHANGING);
            savedButton.getLayoutTransition().enableTransitionType(LayoutTransition.CHANGING);
        }

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

        allButtonText.setVisibility(state == StateFilter.ALL ? View.VISIBLE : View.GONE);
        allButton.setEnabled(state != StateFilter.ALL);
        allButtonIcon.setAlpha(state == StateFilter.ALL ? 1.0f : 0.6f);

        someButtonText.setVisibility(state == StateFilter.SOME ? View.VISIBLE : View.GONE);
        someButton.setEnabled(state != StateFilter.SOME);
        someButtonIcon.setAlpha(state == StateFilter.SOME ? 1.0f : 0.6f);

        focusButtonText.setVisibility(state == StateFilter.BEST ? View.VISIBLE : View.GONE);
        focusButton.setEnabled(state != StateFilter.BEST);
        focusButtonIcon.setAlpha(state == StateFilter.BEST ? 1.0f : 0.6f);

        savedButtonText.setVisibility(state == StateFilter.SAVED ? View.VISIBLE : View.GONE);
        savedButton.setEnabled(state != StateFilter.SAVED);
        savedButtonIcon.setAlpha(state == StateFilter.SAVED ? 1.0f : 0.6f);

	}

	public interface StateChangedListener {
		public void changedState(StateFilter state);
	}

}
