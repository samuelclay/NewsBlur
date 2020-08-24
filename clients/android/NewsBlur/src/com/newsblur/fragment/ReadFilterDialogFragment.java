package com.newsblur.fragment;

import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;

import com.newsblur.R;
import com.newsblur.databinding.ReadfilterDialogBinding;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.ReadFilterChangedListener;

public class ReadFilterDialogFragment extends DialogFragment {
	
	private static String CURRENT_FILTER = "currentFilter";
	private ReadFilter currentValue;
	private ReadfilterDialogBinding binding;

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
		binding = ReadfilterDialogBinding.bind(v);

		binding.radioAll.setChecked(currentValue == ReadFilter.ALL);
		binding.radioUnread.setChecked(currentValue == ReadFilter.UNREAD);
		
		getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
		getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;
		
		return v;
	}

	@Override
	public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
		super.onViewCreated(view, savedInstanceState);
		binding.radioAll.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View v) {
				selectAll();
			}
		});
		binding.radioUnread.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View v) {
				selectUnread();
			}
		});
	}

	private void selectAll() {
        if (currentValue != ReadFilter.ALL) {
            ((ReadFilterChangedListener) getActivity()).readFilterChanged(ReadFilter.ALL);
        }
        dismiss();
    }

    private void selectUnread() {
        if (currentValue != ReadFilter.UNREAD) {
            ((ReadFilterChangedListener) getActivity()).readFilterChanged(ReadFilter.UNREAD);
        }
        dismiss();
    }

}
