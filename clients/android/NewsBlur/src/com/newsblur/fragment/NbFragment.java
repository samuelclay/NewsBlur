package com.newsblur.fragment;

import android.app.Activity;
import androidx.fragment.app.Fragment;

import com.newsblur.util.FeedUtils;

public class NbFragment extends Fragment {

    /**
     * Pokes the sync service to perform any pending sync actions.
     */
    protected void triggerSync() {
        Activity a = getActivity();
        if (a != null) {
            FeedUtils.triggerSync(a);
        }
	}

}
