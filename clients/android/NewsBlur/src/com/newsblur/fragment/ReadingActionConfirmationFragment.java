package com.newsblur.fragment;

import com.newsblur.util.FeedUtils;
import com.newsblur.util.ReadingAction;

import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;

public class ReadingActionConfirmationFragment extends DialogFragment {

    private static final String READING_ACTION = "reading_action";
    private static final String DIALOG_TITLE = "dialog_title";
    private static final String DIALOG_MESSAGE = "dialog_message";
    private static final String DIALOG_CHOICES_RID = "dialog_choices_rid";
    private static final String FINISH_AFTER = "finish_after";
    
    public static ReadingActionConfirmationFragment newInstance(ReadingAction ra, CharSequence title, CharSequence message, int choicesId, boolean finishAfter) {
        ReadingActionConfirmationFragment fragment = new ReadingActionConfirmationFragment();
        Bundle args = new Bundle();
        args.putSerializable(READING_ACTION, ra);
        args.putCharSequence(DIALOG_TITLE, title);
        args.putCharSequence(DIALOG_MESSAGE, message);
        args.putInt(DIALOG_CHOICES_RID, choicesId);
        args.putBoolean(FINISH_AFTER, finishAfter);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());

        final ReadingAction ra = (ReadingAction)getArguments().getSerializable(READING_ACTION);
        CharSequence title = getArguments().getCharSequence(DIALOG_TITLE);
        CharSequence message = getArguments().getCharSequence(DIALOG_MESSAGE);
        int choicesId = getArguments().getInt(DIALOG_CHOICES_RID);
        final boolean finishAfter = getArguments().getBoolean(FINISH_AFTER);
        
        builder.setTitle(title);
        // NB: setting a message will override the display of the buttons, making the dialogue a no-op
        if (message != null) builder.setMessage(message);
        builder.setItems(choicesId, new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int which) {
                if (which == 0) {
                    FeedUtils.doAction(ra, getActivity());
                    if (finishAfter) {
                        getActivity().finish();
                    }
                }
            }
        });
        return builder.create();
    }
}
