package com.newsblur.fragment;

import android.content.Context;

import com.newsblur.domain.ActivityDetails;
import com.newsblur.domain.UserDetails;
import com.newsblur.network.domain.ActivitiesResponse;
import com.newsblur.util.ImageLoader;
import com.newsblur.view.ActivitiesAdapter;
import com.newsblur.view.ActivityDetailsAdapter;

/**
 * Created by mark on 15/06/15.
 */
public class ProfileActivitiesFragment extends ProfileActivityDetailsFragment {

    @Override
    protected ActivityDetailsAdapter createAdapter(Context context, UserDetails user, ImageLoader imageLoader) {
        return new ActivitiesAdapter(context, user, iconLoader);
    }

    @Override
    protected ActivityDetails[] loadActivityDetails(String id, int pageNumber) {
        ActivitiesResponse activitiesResponse = apiManager.getActivities(id, pageNumber);
        if (activitiesResponse != null) {
            return activitiesResponse.activities;
        } else {
            return new ActivityDetails[0];
        }
    }
}
