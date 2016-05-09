package com.newsblur.fragment;

import android.os.Bundle;
import android.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.RadioButton;

import butterknife.ButterKnife;
import butterknife.Bind;
import butterknife.OnClick;

import com.newsblur.R;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.ReadFilterChangedListener;

public class ReadFilterDialogFragment extends DialogFragment {
	
	private static String CURRENT_FILTER = "currentFilter";
	private ReadFilter currentValue;
    @Bind(R.id.radio_all) RadioButton allButton;
    @Bind(R.id.radio_unread) RadioButton unreadButton;

	public static ReadFilterDialogFragment newInstance(ReadFilter currentValue) {
		ReadFilterDialogFragment dialog = new ReadFilterDialogFragment();
		Bundle args = new Bundle();
		args.putSerializable(CURRENT_FILTER, currentValue);
		dialog.setArguments(args);
		
		return dialog;
	}
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		currentValue = (ReadFilter) getArguments().getSerializable(CURRENT_FILTER);
		View v = inflater.inflate(R.layout.readfilter_dialog, null);
        ButterKnife.bind(this, v);

		allButton.setChecked(currentValue == ReadFilter.ALL);
		unreadButton.setChecked(currentValue == ReadFilter.UNREAD);
		
		getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
		getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;
		
		return v;
	}

    @OnClick(R.id.radio_all) void selectAll() {
        if (currentValue != ReadFilter.ALL) {
            ((ReadFilterChangedListener) getActivity()).readFilterChanged(ReadFilter.ALL);
        }
        dismiss();
    }

    @OnClick(R.id.radio_unread) void selectUnread() {
        if (currentValue != ReadFilter.UNREAD) {
            ((ReadFilterChangedListener) getActivity()).readFilterChanged(ReadFilter.UNREAD);
        }
        dismiss();
    }

}
