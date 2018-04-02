package com.newsblur.fragment;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.Fragment;

import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;

public class NbFragment extends Fragment {

    /**
     * Pokes the sync service to perform any pending sync actions.
     */
    protected void triggerSync() {
        Activity a = getActivity();
        if (a != null) {
            Intent i = new Intent(a, NBSyncService.class);
            a.startService(i);
        }
	}

    @Override
    public void onStart() {
        if (AppConstants.VERBOSE_LOG) com.newsblur.util.Log.d(this, "onStart");
        super.onStart();
    }

    @Override
    public void onActivityCreated(Bundle savedInstanceState) {
        if (AppConstants.VERBOSE_LOG) com.newsblur.util.Log.d(this, "onActivityCreated");
        super.onActivityCreated(savedInstanceState);
    }

    @Override
    public void onResume() {
        if (AppConstants.VERBOSE_LOG) com.newsblur.util.Log.d(this, "onResume");
        super.onResume();
    }

}
