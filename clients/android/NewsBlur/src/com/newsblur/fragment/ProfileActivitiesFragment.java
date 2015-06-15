package com.newsblur.fragment;

import com.newsblur.domain.ActivityDetails;
import com.newsblur.network.domain.ActivitiesResponse;

/**
 * Created by mark on 15/06/15.
 */
public class ProfileActivitiesFragment extends ProfileActivityDetailsFragment {

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
