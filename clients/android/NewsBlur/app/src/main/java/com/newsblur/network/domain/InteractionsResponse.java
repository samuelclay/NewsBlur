package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.ActivityDetails;

/**
 * Response for /social/interactions endpoint
 */
public class InteractionsResponse extends NewsBlurResponse {

    @SerializedName("interactions")
    public ActivityDetails[] interactions;
}
