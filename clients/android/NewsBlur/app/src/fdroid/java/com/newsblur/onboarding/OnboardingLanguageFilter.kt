package com.newsblur.onboarding

/** SetupViewModel.kt retains its quality checks; F-Droid does not classify or reject title languages. */
class OnboardingLanguageFilter : AutoCloseable {
    @Suppress("UNUSED_PARAMETER")
    suspend fun accepts(titles: List<String>): Boolean = true

    override fun close() = Unit
}
