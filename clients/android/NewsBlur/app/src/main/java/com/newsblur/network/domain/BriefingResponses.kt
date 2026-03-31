package com.newsblur.network.domain

import com.google.gson.JsonObject
import com.google.gson.annotations.SerializedName
import com.newsblur.domain.Story

data class DailyBriefingStoriesResponseRaw(
    @SerializedName("briefings")
    val briefings: List<DailyBriefingBriefingRaw> = emptyList(),
    @SerializedName("is_preview")
    val isPreview: Boolean = false,
    @SerializedName("briefing_feed_id")
    val briefingFeedId: String? = null,
    @SerializedName("enabled")
    val enabled: Boolean = false,
    @SerializedName("section_definitions")
    val sectionDefinitions: Map<String, String> = emptyMap(),
    @SerializedName("has_next_page")
    val hasNextPage: Boolean = false,
    @SerializedName("page")
    val page: Int = 1,
    @SerializedName("preferences")
    val preferences: DailyBriefingPreferencesResponse? = null,
) : NewsBlurResponse()

data class DailyBriefingBriefingRaw(
    @SerializedName("briefing_id")
    val briefingId: String? = null,
    @SerializedName("briefing_date")
    val briefingDate: String? = null,
    @SerializedName("frequency")
    val frequency: String? = null,
    @SerializedName("slot")
    val slot: String? = null,
    @SerializedName("summary_story")
    val summaryStory: JsonObject? = null,
    @SerializedName("curated_stories")
    val curatedStories: List<JsonObject> = emptyList(),
)

data class DailyBriefingStoriesResponse(
    val briefings: List<DailyBriefingBriefing> = emptyList(),
    val isPreview: Boolean = false,
    val briefingFeedId: String? = null,
    val enabled: Boolean = false,
    val sectionDefinitions: Map<String, String> = emptyMap(),
    val hasNextPage: Boolean = false,
    val page: Int = 1,
    val preferences: DailyBriefingPreferencesResponse? = null,
) : NewsBlurResponse()

data class DailyBriefingBriefing(
    val briefingId: String,
    val briefingDate: String?,
    val frequency: String?,
    val slot: String?,
    val summaryStory: DailyBriefingStory?,
    val curatedStories: List<DailyBriefingStory>,
)

data class DailyBriefingStory(
    val story: Story,
    val feedTitle: String?,
    val faviconColor: String?,
    val explicitFeedId: String?,
    val isSummary: Boolean,
)

data class DailyBriefingPreferencesResponse(
    @SerializedName("frequency")
    val frequency: String = "daily",
    @SerializedName("preferred_time")
    val preferredTime: String = "morning",
    @SerializedName("preferred_day")
    val preferredDay: String = "sun",
    @SerializedName("enabled")
    val enabled: Boolean = false,
    @SerializedName("briefing_feed_id")
    val briefingFeedId: String? = null,
    @SerializedName("story_count")
    val storyCount: Int = 5,
    @SerializedName("summary_length")
    val summaryLength: String = "medium",
    @SerializedName("story_sources")
    val storySources: String = "all",
    @SerializedName("read_filter")
    val readFilter: String = "unread",
    @SerializedName("summary_style")
    val summaryStyle: String = "bullets",
    @SerializedName("include_read")
    val includeRead: Boolean = false,
    @SerializedName("sections")
    val sections: Map<String, Boolean> = emptyMap(),
    @SerializedName("section_order")
    val sectionOrder: List<String> = emptyList(),
    @SerializedName("custom_section_prompts")
    val customSectionPrompts: List<String> = emptyList(),
    @SerializedName("notification_types")
    val notificationTypes: List<String> = emptyList(),
    @SerializedName("briefing_model")
    val briefingModel: String = "",
    @SerializedName("briefing_models")
    val briefingModels: List<DailyBriefingModelOption> = emptyList(),
    @SerializedName("folders")
    val folders: List<String> = emptyList(),
) : NewsBlurResponse()

data class DailyBriefingModelOption(
    @SerializedName("key")
    val key: String,
    @SerializedName("display_name")
    val displayName: String,
    @SerializedName("vendor_display")
    val vendorDisplay: String = "",
)

data class DailyBriefingGenerateResponse(
    @SerializedName("status")
    val status: String? = null,
    @SerializedName("briefing_feed_id")
    val briefingFeedId: String? = null,
) : NewsBlurResponse()
