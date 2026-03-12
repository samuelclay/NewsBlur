package com.newsblur.askai

enum class AskAiProvider(
    val rawValue: String,
    val displayName: String,
    val shortName: String,
    val providerName: String,
    val colorHex: Long,
) {
    OPUS(
        rawValue = "opus",
        displayName = "Anthropic Claude Opus 4.5",
        shortName = "Opus 4.5",
        providerName = "anthropic",
        colorHex = 0xFFD9735F,
    ),
    GPT(
        rawValue = "gpt-5.2",
        displayName = "OpenAI GPT 5.2",
        shortName = "GPT 5.2",
        providerName = "openai",
        colorHex = 0xFF33A673,
    ),
    GEMINI(
        rawValue = "gemini-3",
        displayName = "Google Gemini 3 Pro",
        shortName = "Gemini 3",
        providerName = "google",
        colorHex = 0xFF4384F5,
    ),
    GROK(
        rawValue = "grok-4.1",
        displayName = "xAI Grok 4.1 Fast",
        shortName = "Grok 4.1",
        providerName = "xai",
        colorHex = 0xFF171717,
    ),
    ;

    companion object {
        fun fromRawValue(value: String?): AskAiProvider =
            entries.firstOrNull { it.rawValue == value } ?: OPUS
    }
}

enum class AskAiQuestionType(
    val rawValue: String,
    val displayTitle: String,
    val subtitle: String = "",
    val questionDescription: String,
) {
    SENTENCE(
        rawValue = "sentence",
        displayTitle = "Brief",
        subtitle = "One sentence",
        questionDescription = "Summarize in one sentence",
    ),
    BULLETS(
        rawValue = "bullets",
        displayTitle = "Medium",
        subtitle = "Bullet points",
        questionDescription = "Summarize in bullet points",
    ),
    PARAGRAPH(
        rawValue = "paragraph",
        displayTitle = "Detailed",
        subtitle = "Full paragraph",
        questionDescription = "Give a detailed summary",
    ),
    CONTEXT(
        rawValue = "context",
        displayTitle = "What's the context and background?",
        questionDescription = "What's the context and background?",
    ),
    PEOPLE(
        rawValue = "people",
        displayTitle = "Identify key people and relationships",
        questionDescription = "Identify key people and relationships",
    ),
    ARGUMENTS(
        rawValue = "arguments",
        displayTitle = "What are the main arguments?",
        questionDescription = "What are the main arguments?",
    ),
    FACTCHECK(
        rawValue = "factcheck",
        displayTitle = "Fact check this story",
        questionDescription = "Fact check this story",
    ),
    CUSTOM(
        rawValue = "custom",
        displayTitle = "Custom question",
        questionDescription = "Custom question",
    ),
    ;

    val isSummarize: Boolean
        get() = this == SENTENCE || this == BULLETS || this == PARAGRAPH
}

data class AskAiMessage(
    val role: String,
    val content: String,
)

data class AskAiResponseBlock(
    val questionText: String,
    val model: AskAiProvider,
    val responseText: String,
    val isFollowUp: Boolean,
)

data class AskAiStory(
    val storyHash: String,
    val storyTitle: String,
)

data class AskAiUiState(
    val story: AskAiStory? = null,
    val selectedModel: AskAiProvider = AskAiProvider.OPUS,
    val customQuestion: String = "",
    val completedBlocks: List<AskAiResponseBlock> = emptyList(),
    val currentQuestionId: String = "",
    val currentQuestionText: String = "",
    val currentRequestId: String = "",
    val currentResponseText: String = "",
    val isStreaming: Boolean = false,
    val isComplete: Boolean = false,
    val hasAskedQuestion: Boolean = false,
    val usageMessage: String? = null,
    val errorMessage: String? = null,
    val isRecording: Boolean = false,
    val isTranscribing: Boolean = false,
    val showAskAi: Boolean = true,
    val isArchiveTier: Boolean = false,
)
