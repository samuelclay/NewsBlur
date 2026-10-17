package com.newsblur.fragment;

import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import androidx.fragment.app.FragmentActivity;

import com.newsblur.util.FeedUtils;
import com.newsblur.util.ReadingAction;
import com.newsblur.util.ReadingActionListener;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class ReadingActionConfirmationFragment extends DialogFragment {

    @Inject
    FeedUtils feedUtils;

    private static final String READING_ACTION = "reading_action";
    private static final String DIALOG_TITLE = "dialog_title";
    private static final String DIALOG_MESSAGE = "dialog_message";
    private static final String DIALOG_CHOICES_RID = "dialog_choices_rid";
    private static final String NOTIFY_HOST = "notify_host";

    public static ReadingActionConfirmationFragment newInstance(ReadingAction ra, CharSequence title, CharSequence message, int choicesId, @Nullable ReadingActionListener callback) {
        ReadingActionConfirmationFragment fragment = new ReadingActionConfirmationFragment();
        Bundle args = new Bundle();
        args.putSerializable(READING_ACTION, ra);
        args.putCharSequence(DIALOG_TITLE, title);
        args.putCharSequence(DIALOG_MESSAGE, message);
        args.putInt(DIALOG_CHOICES_RID, choicesId);
        args.putBoolean(NOTIFY_HOST, callback != null);
        fragment.setArguments(args);
        return fragment;
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        AlertDialog.Builder builder = new AlertDialog.Builder(requireActivity());

        final ReadingAction ra = (ReadingAction) getArguments().getSerializable(READING_ACTION);
        CharSequence title = getArguments().getCharSequence(DIALOG_TITLE);
        CharSequence message = getArguments().getCharSequence(DIALOG_MESSAGE);
        int choicesId = getArguments().getInt(DIALOG_CHOICES_RID);

        builder.setTitle(title);
        // NB: setting a message will override the display of the buttons, making the dialogue a no-op
        if (message != null) builder.setMessage(message);
        builder.setItems(choicesId, new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int which) {
                if (which == 0) {
                    feedUtils.doAction(ra, requireContext());
                    notifyReadingActionCompleted(requireArguments(), getActivity());
                }
            }
        });
        return builder.create();
    }

    static void notifyReadingActionCompleted(Bundle arguments, @Nullable FragmentActivity activity) {
        // ReadingActionConfirmationFragment.java stores only the request, never the Activity callback.
        if (arguments.getBoolean(NOTIFY_HOST) && activity instanceof ReadingActionListener) {
            ((ReadingActionListener) activity).onReadingActionCompleted();
        }
    }
}
