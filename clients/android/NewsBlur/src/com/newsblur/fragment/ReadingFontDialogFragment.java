package com.newsblur.fragment;

import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;

import com.newsblur.R;
import com.newsblur.databinding.ReadingfontDialogBinding;
import com.newsblur.util.ReadingFontChangedListener;

/**
 * Created by mark on 02/05/2017.
 */

public class ReadingFontDialogFragment extends DialogFragment {

    private static String SELECTED_FONT = "selectedFont";

    private String currentValue;

    private ReadingfontDialogBinding binding;

    public static ReadingFontDialogFragment newInstance(String selectedFont) {
        ReadingFontDialogFragment dialog = new ReadingFontDialogFragment();
        Bundle args = new Bundle();
        args.putString(SELECTED_FONT, selectedFont);
        dialog.setArguments(args);
        return dialog;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
        currentValue = getArguments().getString(SELECTED_FONT);
        View v = inflater.inflate(R.layout.readingfont_dialog, null);
        binding = ReadingfontDialogBinding.bind(v);

        binding.radioAnonymous.setChecked(currentValue.equals(getString(R.string.anonymous_pro_font_prefvalue)));
        binding.radioChronicle.setChecked(currentValue.equals(getString(R.string.chronicle_font_prefvalue)));
        binding.radioDefault.setChecked(currentValue.equals(getString(R.string.default_font_prefvalue)));
        binding.radioGotham.setChecked(currentValue.equals(getString(R.string.gotham_narrow_font_prefvalue)));
        binding.radioNotoSans.setChecked(currentValue.equals(getString(R.string.noto_sans_font_prefvalue)));
        binding.radioNotoSerif.setChecked(currentValue.equals(getString(R.string.noto_serif_font_prefvalue)));
        binding.radioOpenSansCondensed.setChecked(currentValue.equals(getString(R.string.open_sans_condensed_font_prefvalue)));
        binding.radioWhitney.setChecked(currentValue.equals(getString(R.string.whitney_font_prefvalue)));

        getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
        getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;

        return v;
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        binding.radioAnonymous.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                switchFont(getString(R.string.anonymous_pro_font_prefvalue));
            }
        });
        binding.radioDefault.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                switchFont(getString(R.string.default_font_prefvalue));
            }
        });
        binding.radioChronicle.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                switchFont(getString(R.string.chronicle_font_prefvalue));
            }
        });
        binding.radioGotham.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                switchFont(getString(R.string.gotham_narrow_font_prefvalue));
            }
        });
        binding.radioNotoSans.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                switchFont(getString(R.string.noto_sans_font_prefvalue));
            }
        });
        binding.radioNotoSerif.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                switchFont(getString(R.string.noto_serif_font_prefvalue));
            }
        });
        binding.radioOpenSansCondensed.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                switchFont(getString(R.string.open_sans_condensed_font_prefvalue));
            }
        });
        binding.radioWhitney.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                switchFont(getString(R.string.whitney_font_prefvalue));
            }
        });
    }

    private void switchFont(String newValue) {
        if (!currentValue.equals(newValue)) {
            ((ReadingFontChangedListener)getActivity()).readingFontChanged(newValue);
            currentValue = newValue;
        }
    }
}