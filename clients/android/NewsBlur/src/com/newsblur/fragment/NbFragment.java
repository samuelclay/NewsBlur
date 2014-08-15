package com.newsblur.fragment;

import android.app.Fragment;
import android.os.Bundle;

import com.newsblur.database.BlurDatabaseHelper;

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

}
