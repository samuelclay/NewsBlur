package com.newsblur.fragment;

import android.app.DialogFragment;
import android.os.Bundle;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.RadioButton;

import com.newsblur.R;
import com.newsblur.util.ReadingFontChangedListener;

import butterknife.Bind;
import butterknife.ButterKnife;
import butterknife.OnClick;

/**
 * Created by mark on 02/05/2017.
 */

public class ReadingFontDialogFragment extends DialogFragment {

    private static String SELECTED_FONT = "selectedFont";

    private String currentValue;

    @Bind(R.id.radio_anonymous) RadioButton anonymousButton;
    @Bind(R.id.radio_chronicle) RadioButton chronicleButton;
    @Bind(R.id.radio_default) RadioButton defaultButton;
    @Bind(R.id.radio_gotham) RadioButton gothamButton;
    @Bind(R.id.radio_noto_sans) RadioButton notoSansButton;
    @Bind(R.id.radio_noto_serif) RadioButton notoSerifButton;
    @Bind(R.id.radio_open_sans_condensed) RadioButton openSansCondensedButton;
    @Bind(R.id.radio_whitney) RadioButton whitneyButton;

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
        ButterKnife.bind(this, v);

        anonymousButton.setChecked(currentValue.equals(getString(R.string.anonymous_pro_font_prefvalue)));
        chronicleButton.setChecked(currentValue.equals(getString(R.string.chronicle_font_prefvalue)));
        defaultButton.setChecked(currentValue.equals(getString(R.string.default_font_prefvalue)));
        gothamButton.setChecked(currentValue.equals(getString(R.string.gotham_narrow_font_prefvalue)));
        notoSansButton.setChecked(currentValue.equals(getString(R.string.noto_sans_font_prefvalue)));
        notoSerifButton.setChecked(currentValue.equals(getString(R.string.noto_serif_font_prefvalue)));
        openSansCondensedButton.setChecked(currentValue.equals(getString(R.string.open_sans_condensed_font_prefvalue)));
        whitneyButton.setChecked(currentValue.equals(getString(R.string.whitney_font_prefvalue)));

        getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
        getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;

        return v;
    }

    @OnClick(R.id.radio_anonymous) void selectAnonymousPro() {
        switchFont(getString(R.string.anonymous_pro_font_prefvalue));
    }

    private void switchFont(String newValue) {
        if (!currentValue.equals(newValue)) {
            ((ReadingFontChangedListener)getActivity()).readingFontChanged(newValue);
            currentValue = newValue;
        }
    }

    @OnClick(R.id.radio_chronicle) void selectChronicle() {
        switchFont(getString(R.string.chronicle_font_prefvalue));
    }

    @OnClick(R.id.radio_default) void selectDefault() {
        switchFont(getString(R.string.default_font_prefvalue));
    }

    @OnClick(R.id.radio_gotham) void selectGotham() {
        switchFont(getString(R.string.gotham_narrow_font_prefvalue));
    }

    @OnClick(R.id.radio_noto_sans) void selectNotoSans() {
        switchFont(getString(R.string.noto_sans_font_prefvalue));
    }

    @OnClick(R.id.radio_noto_serif) void selectNotoSerif() {
        switchFont(getString(R.string.noto_serif_font_prefvalue));
    }

    @OnClick(R.id.radio_open_sans_condensed) void selectOpenSansCondensed() {
        switchFont(getString(R.string.open_sans_condensed_font_prefvalue));
    }

    @OnClick(R.id.radio_whitney) void selectWhitney() {
        switchFont(getString(R.string.whitney_font_prefvalue));
    }
}
