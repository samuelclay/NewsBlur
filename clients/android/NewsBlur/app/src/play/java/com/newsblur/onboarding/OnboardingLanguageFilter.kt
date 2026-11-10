package com.newsblur.onboarding

import com.google.mlkit.nl.languageid.LanguageIdentification
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Preserves SetupViewModel.kt's English-only recommendation checks in the Play distribution. */
class OnboardingLanguageFilter : AutoCloseable {
    private val language = LanguageIdentification.getClient()

    suspend fun accepts(titles: List<String>): Boolean {
        val dominant = identify(titles.joinToString(". ")).maxByOrNull { it.second }
        if (dominant == null || dominant.first != "en" || dominant.second < .6f) return false
        for (title in titles.filter { it.split(" ").size >= 4 }) {
            val detected = identify(title).maxByOrNull { it.second }
            if (detected != null && detected.first != "en" && detected.first != "und" && detected.second >= .7f) {
                return false
            }
        }
        return true
    }

    private suspend fun identify(text: String): List<Pair<String, Float>> =
        suspendCancellableCoroutine { continuation ->
            language
                .identifyPossibleLanguages(text)
                .addOnSuccessListener { results ->
                    if (continuation.isActive) continuation.resume(results.map { it.languageTag to it.confidence })
                }.addOnFailureListener { if (continuation.isActive) continuation.resumeWithException(it) }
        }

    override fun close() = language.close()
}
