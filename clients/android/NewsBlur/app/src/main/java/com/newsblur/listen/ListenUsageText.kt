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
 * ListenUsageText.kt words the usage line the same way as the web player: the hours and minutes of new audio left
 * this month for Premium Archive and Archive Extra or this week for Pro (usage.period, apps/listen/usage.py), or
 * the free story and voice previews left today for everyone else.
 */
@Composable
fun listenUsageSummary(usage: ListenUsage?): String? {
    usage ?: return null
    val parts = mutableListOf<String>()
    if (usage.hasTimeAllowance) {
        val remaining = usage.secondsRemaining ?: return null
        val timeLeft = listenDurationText(listenHoursAndMinutes(remaining))
        parts +=
            stringResource(
                if (usage.isMonthly) R.string.listen_time_left_this_month else R.string.listen_time_left_this_week,
                timeLeft,
            )
        listenResetDate(usage.resetsAt, usage.period)?.let { parts += stringResource(R.string.listen_resets_on, it) }
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
        if (usage?.hasTimeAllowance != true) {
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

/** Whole hours and the minutes left over in a number of seconds, never negative: 35,880 seconds is 9 hours 58 minutes. */
internal fun listenHoursAndMinutes(seconds: Double): Pair<Int, Int> {
    val minutes = floor(max(0.0, seconds) / 60.0).toInt()
    return minutes / 60 to minutes % 60
}

/** "9 hours 58 minutes", "1 hour" or "45 minutes": a zero part is left out, and nothing left reads "0 minutes". */
@Composable
private fun listenDurationText(hoursAndMinutes: Pair<Int, Int>): String {
    val (hours, minutes) = hoursAndMinutes
    val hoursText = pluralStringResource(R.plurals.listen_hours, hours, hours)
    val minutesText = pluralStringResource(R.plurals.listen_minutes, minutes, minutes)
    return when {
        hours > 0 && minutes > 0 -> stringResource(R.string.listen_hours_and_minutes, hoursText, minutesText)
        hours > 0 -> hoursText
        else -> minutesText
    }
}

/**
 * When the allowance resets, in the reader's own language: "December 1" (or "1. Dezember" in German) for a monthly
 * allowance, "Sunday" (or "Sonntag") for a weekly one. The server sends midnight at the start of the next period in
 * the account's timezone (apps/listen/usage.py), so the date is read in that offset rather than the device's,
 * matching the web. bestPattern turns a skeleton into the locale's pattern, android.text.format.DateFormat on a
 * device.
 */
internal fun listenResetDate(
    resetsAt: String?,
    period: String?,
    locale: Locale = Locale.getDefault(),
    bestPattern: (skeleton: String) -> String = { DateFormat.getBestDateTimePattern(locale, it) },
): String? {
    if (resetsAt.isNullOrBlank()) return null
    val resetsAtTime =
        try {
            OffsetDateTime.parse(resetsAt)
        } catch (_: DateTimeParseException) {
            return null
        }
    val skeleton = if (period == ListenUsage.PERIOD_MONTH) MONTH_DAY_SKELETON else WEEKDAY_SKELETON
    return DateTimeFormatter.ofPattern(bestPattern(skeleton), locale).format(resetsAtTime)
}

private const val WEEKDAY_SKELETON = "EEEE"
private const val MONTH_DAY_SKELETON = "MMMMd"
