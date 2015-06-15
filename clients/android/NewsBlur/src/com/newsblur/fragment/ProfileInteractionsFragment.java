package com.newsblur.fragment;

import com.newsblur.domain.ActivityDetails;
import com.newsblur.network.domain.InteractionsResponse;

/**
 * Created by mark on 15/06/15.
 */
public class ProfileInteractionsFragment extends ProfileActivityDetailsFragment {

    @Override
    protected ActivityDetails[] loadActivityDetails(String id, int pageNumber) {
        InteractionsResponse interactionsResponse = apiManager.getInteractions(id, pageNumber);
        if (interactionsResponse != null) {
            return interactionsResponse.interactions;
        } else {
            return new ActivityDetails[0];
        }
    }
}

