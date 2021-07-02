package com.newsblur.fragment;

import android.os.Bundle;
import androidx.fragment.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;

import com.newsblur.R;
import com.newsblur.databinding.StoryorderDialogBinding;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.StoryOrderChangedListener;

public class StoryOrderDialogFragment extends DialogFragment {
	
	private static String CURRENT_ORDER = "currentOrder";
	private StoryOrder currentValue;

	public static StoryOrderDialogFragment newInstance(StoryOrder currentValue) {
		StoryOrderDialogFragment dialog = new StoryOrderDialogFragment();
		Bundle args = new Bundle();
		args.putSerializable(CURRENT_ORDER, currentValue);
		dialog.setArguments(args);
		
		return dialog;
	}
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		currentValue = (StoryOrder) getArguments().getSerializable(CURRENT_ORDER);
		View v = inflater.inflate(R.layout.storyorder_dialog, null);
		StoryorderDialogBinding binding = StoryorderDialogBinding.bind(v);

		binding.radioNewest.setChecked(currentValue == StoryOrder.NEWEST);
		binding.radioOldest.setChecked(currentValue == StoryOrder.OLDEST);
		
		getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
		getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;

		binding.radioNewest.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View v) {
				selectNewest();
			}
		});
		binding.radioOldest.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View v) {
				selectOldest();
			}
		});
		
		return v;
	}

    private void selectNewest() {
        if (currentValue != StoryOrder.NEWEST) {
            ((StoryOrderChangedListener) getActivity()).storyOrderChanged(StoryOrder.NEWEST);
        }
        dismiss();
    }

    private void selectOldest() {
        if (currentValue != StoryOrder.OLDEST) {
            ((StoryOrderChangedListener) getActivity()).storyOrderChanged(StoryOrder.OLDEST);
        }
        dismiss();
    }

}
