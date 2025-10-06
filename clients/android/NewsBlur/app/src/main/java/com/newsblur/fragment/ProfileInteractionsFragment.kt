package com.newsblur.fragment

import android.content.Context
import com.newsblur.domain.ActivityDetails
import com.newsblur.domain.UserDetails
import com.newsblur.network.domain.InteractionsResponse
import com.newsblur.util.ImageLoader
import com.newsblur.view.ActivityDetailsAdapter
import com.newsblur.view.InteractionsAdapter

/**
 * Created by mark on 15/06/15.
 */
class ProfileInteractionsFragment : ProfileActivityDetailsFragment() {
    override fun createAdapter(context: Context?, user: UserDetails?, iconLoader: ImageLoader): ActivityDetailsAdapter? =
            InteractionsAdapter(context, user, iconLoader)

    override suspend fun loadActivityDetails(id: String, pageNumber: Int): Array<ActivityDetails>? {
        val interactionsResponse: InteractionsResponse? = userApi.getInteractions(id, pageNumber)
        return interactionsResponse?.interactions
    }
}

