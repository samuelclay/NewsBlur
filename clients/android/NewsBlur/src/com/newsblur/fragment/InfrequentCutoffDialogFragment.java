package com.newsblur.fragment;

import android.os.Bundle;
import android.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RadioButton;

import butterknife.ButterKnife;
import butterknife.Bind;
import butterknife.OnClick;

import com.newsblur.R;

public class InfrequentCutoffDialogFragment extends DialogFragment {
	
	private static String CURRENT_CUTOFF = "currentCutoff";
	private int currentValue;
    @Bind(R.id.radio_5) RadioButton button5;
    @Bind(R.id.radio_15) RadioButton button15;
    @Bind(R.id.radio_30) RadioButton button30;
    @Bind(R.id.radio_60) RadioButton button60;
    @Bind(R.id.radio_90) RadioButton button90;

	public static InfrequentCutoffDialogFragment newInstance(int currentValue) {
		InfrequentCutoffDialogFragment dialog = new InfrequentCutoffDialogFragment();
		Bundle args = new Bundle();
		args.putInt(CURRENT_CUTOFF, currentValue);
		dialog.setArguments(args);
		
		return dialog;
	}
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		currentValue = getArguments().getInt(CURRENT_CUTOFF);
		View v = inflater.inflate(R.layout.infrequent_cutoff_dialog, null);
        ButterKnife.bind(this, v);

		button5.setChecked(currentValue == 5);
		button15.setChecked(currentValue == 15);
		button30.setChecked(currentValue == 30);
		button60.setChecked(currentValue == 60);
		button90.setChecked(currentValue == 90);
		
		getDialog().setTitle(R.string.infrequent_choice_title);
		getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;
		
		return v;
	}

    @OnClick(R.id.radio_5) void select5() {
        if (currentValue != 5) {
            ((InfrequentCutoffChangedListener) getActivity()).infrequentCutoffChanged(5);
        }
        dismiss();
    }
    @OnClick(R.id.radio_15) void select15() {
        if (currentValue != 15) {
            ((InfrequentCutoffChangedListener) getActivity()).infrequentCutoffChanged(15);
        }
        dismiss();
    }
    @OnClick(R.id.radio_30) void select30() {
        if (currentValue != 30) {
            ((InfrequentCutoffChangedListener) getActivity()).infrequentCutoffChanged(30);
        }
        dismiss();
    }
    @OnClick(R.id.radio_60) void select60() {
        if (currentValue != 60) {
            ((InfrequentCutoffChangedListener) getActivity()).infrequentCutoffChanged(60);
        }
        dismiss();
    }
    @OnClick(R.id.radio_90) void select90() {
        if (currentValue != 90) {
            ((InfrequentCutoffChangedListener) getActivity()).infrequentCutoffChanged(90);
        }
        dismiss();
    }

    public interface InfrequentCutoffChangedListener {
        void infrequentCutoffChanged(int newValue);
    }

}
