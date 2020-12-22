package com.newsblur.network.domain

import com.google.gson.annotations.SerializedName
import com.newsblur.domain.Story

data class StoryChangesResponse(
        @SerializedName("story")
        val story: Story? = null) : NewsBlurResponse()
