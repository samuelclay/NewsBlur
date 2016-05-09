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
import com.newsblur.util.StoryOrder;
import com.newsblur.util.StoryOrderChangedListener;

public class StoryOrderDialogFragment extends DialogFragment {
	
	private static String CURRENT_ORDER = "currentOrder";
	private StoryOrder currentValue;
    @Bind(R.id.radio_newest) RadioButton newestButton;
    @Bind(R.id.radio_oldest) RadioButton oldestButton;

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
        ButterKnife.bind(this, v);

		newestButton.setChecked(currentValue == StoryOrder.NEWEST);
		oldestButton.setChecked(currentValue == StoryOrder.OLDEST);
		
		getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
		getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;
		
		return v;
	}

    @OnClick(R.id.radio_newest) void selectNewest() {
        if (currentValue != StoryOrder.NEWEST) {
            ((StoryOrderChangedListener) getActivity()).storyOrderChanged(StoryOrder.NEWEST);
        }
        dismiss();
    }

    @OnClick(R.id.radio_oldest) void selectOldest() {
        if (currentValue != StoryOrder.OLDEST) {
            ((StoryOrderChangedListener) getActivity()).storyOrderChanged(StoryOrder.OLDEST);
        }
        dismiss();
    }

}
