package com.newsblur.view;

import android.animation.LayoutTransition;
import android.content.Context;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.LinearLayout;

import com.newsblur.R;
import com.newsblur.databinding.StateToggleBinding;
import com.newsblur.util.StateFilter;
import com.newsblur.util.UIUtils;

public class StateToggleButton extends LinearLayout {

    /** the parent width in dp under which the widget will auto-collapse to a compact form */
    private final static int COLLAPSE_WIDTH_DP = 450;

	private StateFilter state = StateFilter.SOME;

	private StateChangedListener stateChangedListener;

    private int parentWidthPX = 0;

    private StateToggleBinding binding;

	public StateToggleButton(Context context, AttributeSet art) {
		super(context, art);
		LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
		View view = inflater.inflate(R.layout.state_toggle, this);
        binding = StateToggleBinding.bind(view);

        // smooth layout transitions are enabled in our layout XML; this smooths out toggle
        // transitions on newer devices
        binding.toggleAll.getLayoutTransition().enableTransitionType(LayoutTransition.CHANGING);
        binding.toggleSome.getLayoutTransition().enableTransitionType(LayoutTransition.CHANGING);
        binding.toggleFocus.getLayoutTransition().enableTransitionType(LayoutTransition.CHANGING);
        binding.toggleSaved.getLayoutTransition().enableTransitionType(LayoutTransition.CHANGING);

		setState(state);

		binding.toggleAll.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                setState(StateFilter.ALL);
            }
        });
		binding.toggleSome.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                setState(StateFilter.SOME);
            }
        });
		binding.toggleFocus.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                setState(StateFilter.BEST);
            }
        });
		binding.toggleSaved.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                setState(StateFilter.SAVED);
            }
        });
	}

	public void setStateListener(final StateChangedListener stateChangedListener) {
		this.stateChangedListener = stateChangedListener;
	}

	public void setState(StateFilter state) {
        this.state = state;
        updateButtonStates();
		if (stateChangedListener != null) {
			stateChangedListener.changedState(this.state);
		}
    }

    public void setParentWidthPX(int parentWidthPX) {
        this.parentWidthPX = parentWidthPX;
        updateButtonStates();
    }

    public void updateButtonStates() {
        boolean compactMode = true;
        if (parentWidthPX > 0) {
            float widthDP = UIUtils.px2dp(getContext(), parentWidthPX);
            if (widthDP > COLLAPSE_WIDTH_DP) compactMode = false;
        }

        binding.toggleAllText.setVisibility((!compactMode || state == StateFilter.ALL) ? View.VISIBLE : View.GONE);
        binding.toggleAll.setEnabled(state != StateFilter.ALL);
        binding.toggleAllIcon.setAlpha(state == StateFilter.ALL ? 1.0f : 0.6f);

        binding.toggleSomeText.setVisibility((!compactMode || state == StateFilter.SOME) ? View.VISIBLE : View.GONE);
        binding.toggleSome.setEnabled(state != StateFilter.SOME);
        binding.toggleSomeIcon.setAlpha(state == StateFilter.SOME ? 1.0f : 0.6f);

        binding.toggleFocusText.setVisibility((!compactMode || state == StateFilter.BEST) ? View.VISIBLE : View.GONE);
        binding.toggleFocus.setEnabled(state != StateFilter.BEST);
        binding.toggleFocusIcon.setAlpha(state == StateFilter.BEST ? 1.0f : 0.6f);

        binding.toggleSavedText.setVisibility((!compactMode || state == StateFilter.SAVED) ? View.VISIBLE : View.GONE);
        binding.toggleSaved.setEnabled(state != StateFilter.SAVED);
        binding.toggleSavedIcon.setAlpha(state == StateFilter.SAVED ? 1.0f : 0.6f);
	}

	public interface StateChangedListener {
		public void changedState(StateFilter state);
	}

}
