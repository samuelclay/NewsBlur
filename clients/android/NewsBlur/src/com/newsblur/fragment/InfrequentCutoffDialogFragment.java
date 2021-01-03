package com.newsblur.fragment;

import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.newsblur.R;
import com.newsblur.databinding.InfrequentCutoffDialogBinding;

public class InfrequentCutoffDialogFragment extends DialogFragment {
	
	private static String CURRENT_CUTOFF = "currentCutoff";
	private int currentValue;
    private InfrequentCutoffDialogBinding binding;

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
        binding = InfrequentCutoffDialogBinding.bind(v);

		binding.radio5.setChecked(currentValue == 5);
		binding.radio15.setChecked(currentValue == 15);
		binding.radio30.setChecked(currentValue == 30);
		binding.radio60.setChecked(currentValue == 60);
		binding.radio90.setChecked(currentValue == 90);

		getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;
		
		return v;
	}

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        binding.radio5.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                select5();
            }
        });
        binding.radio15.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                select15();
            }
        });
        binding.radio30.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                select30();
            }
        });
        binding.radio60.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                select60();
            }
        });
        binding.radio90.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                select90();
            }
        });
    }

    private void select5() {
        if (currentValue != 5) {
            ((InfrequentCutoffChangedListener) getActivity()).infrequentCutoffChanged(5);
        }
        dismiss();
    }
    private void select15() {
        if (currentValue != 15) {
            ((InfrequentCutoffChangedListener) getActivity()).infrequentCutoffChanged(15);
        }
        dismiss();
    }
    private void select30() {
        if (currentValue != 30) {
            ((InfrequentCutoffChangedListener) getActivity()).infrequentCutoffChanged(30);
        }
        dismiss();
    }
    private void select60() {
        if (currentValue != 60) {
            ((InfrequentCutoffChangedListener) getActivity()).infrequentCutoffChanged(60);
        }
        dismiss();
    }
    private void select90() {
        if (currentValue != 90) {
            ((InfrequentCutoffChangedListener) getActivity()).infrequentCutoffChanged(90);
        }
        dismiss();
    }

    public interface InfrequentCutoffChangedListener {
        void infrequentCutoffChanged(int newValue);
    }

}
