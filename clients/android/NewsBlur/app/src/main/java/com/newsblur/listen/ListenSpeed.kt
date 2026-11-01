package com.newsblur.listen

import java.math.BigDecimal
import java.math.RoundingMode
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * ListenSpeed.kt is the speed control's math, shared with the web and iOS players: any rate from 0.5x to 3x
 * rounded to hundredths, a slider over SPEED_STOPS that gives the band around 1x about half its track, and the
 * preset buttons, which highlight only on an exact match.
 */
object ListenSpeed {
    const val MIN = 0.5
    const val MAX = 3.0

    /** 0.50 to 0.80 by 0.05, 0.81 to 1.20 by 0.01, then 1.25 to 3.00 by 0.05: 83 stops, in hundredths. */
    private val STOP_HUNDREDTHS: List<Int> = (50..80 step 5) + (81..120) + (125..300 step 5)

    val STOPS: List<Double> = STOP_HUNDREDTHS.map { it / 100.0 }

    val PRESETS: List<Double> = listOf(0.75, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0)

    val LAST_INDEX: Int
        get() = STOPS.lastIndex

    /** Rounds to hundredths and keeps the rate inside 0.5x to 3x. */
    fun clamp(value: Double): Double = hundredths(value) / 100.0

    /** The slider position for a rate: its own stop, or the nearest one when a typed rate falls between stops. */
    fun nearestStopIndex(value: Double): Int {
        val target = hundredths(value)
        return STOP_HUNDREDTHS.indices.minByOrNull { abs(STOP_HUNDREDTHS[it] - target) } ?: 0
    }

    fun stopAt(index: Int): Double = STOPS[index.coerceIn(0, LAST_INDEX)]

    fun stopAt(position: Float): Double = stopAt(position.roundToInt())

    /** Where 1x sits on the slider, from 0 to 1, for its tick mark. */
    val normalTickFraction: Float
        get() = nearestStopIndex(1.0).toFloat() / LAST_INDEX

    fun isSelected(
        preset: Double,
        value: Double,
    ): Boolean = hundredths(preset) == hundredths(value)

    /** Reads a typed rate like "1.05", "1,05" or "1.05×"; null when it isn't a number. */
    fun parse(text: String): Double? {
        val cleaned =
            text
                .trim()
                .removeSuffix("×")
                .removeSuffix("x")
                .removeSuffix("X")
                .trim()
                .replace(',', '.')
        if (cleaned.isEmpty()) return null
        return cleaned.toDoubleOrNull()?.takeIf { it.isFinite() }
    }

    /** Keeps what the exact value field accepts: digits and one decimal separator, at most four characters. */
    fun sanitizeInput(text: String): String {
        val kept = StringBuilder()
        var separator = false
        text.forEach { char ->
            when {
                char.isDigit() -> kept.append(char)
                (char == '.' || char == ',') && !separator -> {
                    separator = true
                    kept.append(char)
                }
            }
        }
        return kept.take(MAX_INPUT_LENGTH).toString()
    }

    /** "1", "1.1" or "1.05": up to two decimals, in the reader's own number format. */
    fun format(
        value: Double,
        locale: Locale = Locale.getDefault(),
    ): String {
        val format = DecimalFormat("0.##", DecimalFormatSymbols.getInstance(locale))
        return format.format(clamp(value))
    }

    /** The listen_speed preference value: a plain decimal string with up to two places, like "1.05". */
    fun prefString(value: Double): String =
        BigDecimal
            .valueOf(hundredths(value).toLong(), 2)
            .stripTrailingZeros()
            .toPlainString()

    /** A rate as whole hundredths, rounded half up from its decimal digits and kept inside 0.5x to 3x. */
    private fun hundredths(value: Double): Int {
        if (!value.isFinite()) return NORMAL_HUNDREDTHS
        val bounded = value.coerceIn(MIN, MAX)
        return BigDecimal
            .valueOf(bounded)
            .setScale(2, RoundingMode.HALF_UP)
            .movePointRight(2)
            .toInt()
    }

    private const val NORMAL_HUNDREDTHS = 100
    private const val MAX_INPUT_LENGTH = 4
}
