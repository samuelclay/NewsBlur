package com.newsblur.fragment;

import android.app.Activity;
import android.app.Fragment;
import android.content.Intent;
import android.os.Bundle;

import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.service.NBSyncService;

public class NbFragment extends Fragment {

    protected BlurDatabaseHelper dbHelper;
    
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        dbHelper = new BlurDatabaseHelper(getActivity());
    }

    @Override
    public void onDestroy() {
        if (dbHelper != null) {
            try {
                dbHelper.close();
            } catch (Exception e) {
                ; // Fragment is already dead
            }
        }

        super.onDestroy();
    }

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

}
