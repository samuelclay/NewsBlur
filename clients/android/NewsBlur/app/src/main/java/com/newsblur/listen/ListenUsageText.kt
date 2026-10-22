package com.newsblur.listen

import android.text.format.DateFormat
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.newsblur.R
import com.newsblur.design.ListenPalette
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.Locale
import kotlin.math.floor
import kotlin.math.max

/**
 * ListenUsageText.kt words the usage line the same way as the web player: minutes of new audio left this month for
 * Premium Archive and Pro, or the free story and voice previews left today for everyone else.
 */
@Composable
fun listenUsageSummary(usage: ListenUsage?): String? {
    usage ?: return null
    val parts = mutableListOf<String>()
    if (usage.isArchiveTier) {
        val remaining = usage.secondsRemaining ?: return null
        val minutes = floor(max(0.0, remaining) / 60.0).toInt()
        parts += pluralStringResource(R.plurals.listen_minutes_left, minutes, minutes)
        listenResetDate(usage.resetsAt)?.let { parts += stringResource(R.string.listen_resets_on, it) }
    } else {
        usage.samplesLimit?.let { limit ->
            val left = max(0, limit - usage.samplesUsed)
            parts += pluralStringResource(R.plurals.listen_story_previews_left, left, left)
        }
        usage.previewsLimit?.let { limit ->
            val left = max(0, limit - usage.previewsUsed)
            parts += pluralStringResource(R.plurals.listen_voice_previews_left, left, left)
        }
    }
    return parts.takeIf { it.isNotEmpty() }?.joinToString(" · ")
}

/** The usage line as a quiet footer, with an Upgrade link for people without Premium Archive. */
@Composable
fun ListenUsageFooter(
    usage: ListenUsage?,
    colors: ListenPalette.Colors,
    onUpgrade: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val summary = listenUsageSummary(usage) ?: return
    Row(modifier = modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text = summary, color = colors.textSecondary, fontSize = 12.sp, modifier = Modifier.weight(1f, fill = false))
        if (usage?.isArchiveTier != true) {
            Spacer(Modifier.width(8.dp))
            Text(
                text = stringResource(R.string.listen_upgrade),
                color = colors.textPrimary,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.clickable(role = Role.Button, onClick = onUpgrade).padding(vertical = 4.dp),
            )
        }
    }
}

/**
 * "Nov 1" (or "1. Nov." in German) for the date the monthly allowance resets, in the reader's own date order.
 * The server sends midnight in the account's timezone (apps/listen/usage.py), so the date is read in that offset
 * rather than the device's, matching the web.
 */
internal fun listenResetDate(
    resetsAt: String?,
    locale: Locale = Locale.getDefault(),
    pattern: String = DateFormat.getBestDateTimePattern(locale, MONTH_DAY_SKELETON),
): String? {
    if (resetsAt.isNullOrBlank()) return null
    val resetsAtTime =
        try {
            OffsetDateTime.parse(resetsAt)
        } catch (_: DateTimeParseException) {
            return null
        }
    return DateTimeFormatter.ofPattern(pattern, locale).format(resetsAtTime)
}

private const val MONTH_DAY_SKELETON = "MMMd"
