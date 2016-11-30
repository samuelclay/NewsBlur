package com.newsblur.fragment;

import com.newsblur.R;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;

import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.app.DialogFragment;

public class MarkAllReadDialogFragment extends DialogFragment {
    private static final String FEED_SET = "feed_set";
    
    public interface MarkAllReadDialogListener {
        void onMarkAllRead(FeedSet feedSet);
    }
    
    public static MarkAllReadDialogFragment newInstance(FeedSet feedSet) {
        MarkAllReadDialogFragment fragment = new MarkAllReadDialogFragment();
        Bundle args = new Bundle();
        args.putSerializable(FEED_SET, feedSet);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());

        final FeedSet feedSet = (FeedSet)getArguments().getSerializable(FEED_SET);
        String title = null;
        if (feedSet.isAllNormal()) {
            title = getResources().getString(R.string.all_stories);
        } else if (feedSet.isFolder()) {
            title = feedSet.getFolderName();
        } else if (feedSet.isSingleSocial()) {
            title = FeedUtils.getSocialFeed(feedSet.getSingleSocialFeed().getKey()).feedTitle;
        } else {
            title = FeedUtils.getFeed(feedSet.getSingleFeed()).title;
        }

        final MarkAllReadDialogListener listener = (MarkAllReadDialogListener) getActivity();
        builder.setTitle(title)
               .setItems(R.array.mark_all_read_options, new DialogInterface.OnClickListener() {
                   public void onClick(DialogInterface dialog, int which) {
                       if (which == 0) {
                           listener.onMarkAllRead(feedSet);
                       }
               }
        });
        return builder.create();
    }
}
