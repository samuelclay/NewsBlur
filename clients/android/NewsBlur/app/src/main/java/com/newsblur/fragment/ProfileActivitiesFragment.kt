package com.newsblur.fragment

import android.content.Context
import com.newsblur.domain.ActivityDetails
import com.newsblur.domain.UserDetails
import com.newsblur.util.ImageLoader
import com.newsblur.view.ActivitiesAdapter
import com.newsblur.view.ActivityDetailsAdapter

/**
 * Created by mark on 15/06/15.
 */
class ProfileActivitiesFragment : ProfileActivityDetailsFragment() {
    override fun createAdapter(
        context: Context?,
        user: UserDetails?,
        iconLoader: ImageLoader,
    ): ActivityDetailsAdapter? = ActivitiesAdapter(context, user, iconLoader)

    override suspend fun loadActivityDetails(
        id: String,
        pageNumber: Int,
    ): Array<ActivityDetails>? {
        val activitiesResponse = userApi.getActivities(id, pageNumber)
        return activitiesResponse?.activities
    }
}
