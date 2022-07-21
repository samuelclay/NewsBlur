package com.newsblur.view;

import android.content.Context;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.LinearLayout;

import com.newsblur.R;
import com.newsblur.databinding.StateToggleBinding;
import com.newsblur.util.StateFilter;

public class StateToggleButton extends LinearLayout {

    private StateFilter state = StateFilter.SOME;
    private StateChangedListener stateChangedListener;
    private final StateToggleBinding binding;

    public StateToggleButton(Context context, AttributeSet art) {
        super(context, art);
        LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        View view = inflater.inflate(R.layout.state_toggle, this);
        binding = StateToggleBinding.bind(view);
        setState(state);

        binding.toggleAll.setOnClickListener(v -> setState(StateFilter.ALL));
        binding.toggleSome.setOnClickListener(v -> setState(StateFilter.SOME));
        binding.toggleFocus.setOnClickListener(v -> setState(StateFilter.BEST));
        binding.toggleSaved.setOnClickListener(v -> setState(StateFilter.SAVED));
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

    public void updateButtonStates() {
        binding.toggleAll.setEnabled(state != StateFilter.ALL);

        binding.toggleSome.setEnabled(state != StateFilter.SOME);
        binding.toggleSomeIcon.setAlpha(state == StateFilter.SOME ? 1.0f : 0.6f);

        binding.toggleFocus.setEnabled(state != StateFilter.BEST);
        binding.toggleFocusIcon.setAlpha(state == StateFilter.BEST ? 1.0f : 0.6f);

        binding.toggleSaved.setEnabled(state != StateFilter.SAVED);
        binding.toggleSavedIcon.setAlpha(state == StateFilter.SAVED ? 1.0f : 0.6f);
    }

    public interface StateChangedListener {
        void changedState(StateFilter state);
    }
}
