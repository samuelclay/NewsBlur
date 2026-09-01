package com.newsblur.askai

// AskAiModels.kt: Android's single place to update when AI models change.
// Raw values are stable vendor keys understood by the backend registry in
// apps/ask_ai/providers.py — only the display/short names change on upgrades.
enum class AskAiProvider(
    val rawValue: String,
    val displayName: String,
    val shortName: String,
    val providerName: String,
    val colorHex: Long,
) {
    ANTHROPIC(
        rawValue = "anthropic",
        displayName = "Anthropic Claude Sonnet 5",
        shortName = "Sonnet 5",
        providerName = "anthropic",
        colorHex = 0xFFD9735F,
    ),
    OPENAI(
        rawValue = "openai",
        displayName = "OpenAI GPT-5.6 Luna",
        shortName = "GPT-5.6 Luna",
        providerName = "openai",
        colorHex = 0xFF33A673,
    ),
    GOOGLE(
        rawValue = "google",
        displayName = "Google Gemini 3.6 Flash",
        shortName = "Gemini 3.6",
        providerName = "google",
        colorHex = 0xFF4384F5,
    ),
    XAI(
        rawValue = "xai",
        displayName = "xAI Grok 4.6",
        shortName = "Grok 4.6",
        providerName = "xai",
        colorHex = 0xFF171717,
    ),
    ;

    companion object {
        // Legacy model-specific keys ("opus", "gpt-5.2", ...) saved before
        // keys became vendor slugs (Aug 2026).
        private val legacyKeys =
            mapOf(
                "opus" to ANTHROPIC,
                "haiku" to ANTHROPIC,
                "gpt-5.2" to OPENAI,
                "gpt-5-mini" to OPENAI,
                "gemini-3" to GOOGLE,
                "gemini-flash-lite" to GOOGLE,
                "grok-4.1" to XAI,
                "grok-4.1-fast" to XAI,
            )

        fun fromRawValue(value: String?): AskAiProvider =
            entries.firstOrNull { it.rawValue == value } ?: legacyKeys[value] ?: ANTHROPIC
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
    val selectedModel: AskAiProvider = AskAiProvider.ANTHROPIC,
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
