package com.newsblur.util

import android.content.Context
import android.content.res.Configuration
import androidx.core.content.ContextCompat
import com.newsblur.R
import com.newsblur.preference.PrefsRepo

data class DiscoverThemePalette(
    val backgroundColor: Int,
    val surfaceColor: Int,
    val borderColor: Int,
    val textPrimaryColor: Int,
    val textSecondaryColor: Int,
    val accentColor: Int,
    val accentTextColor: Int,
    val secondaryButtonBackgroundColor: Int,
    val secondaryButtonTextColor: Int,
    val segmentedBackgroundColor: Int,
    val segmentedSelectedColor: Int,
    val segmentedTextColor: Int,
    val segmentedSelectedTextColor: Int,
    val segmentedBorderColor: Int,
    val freshnessActiveColor: Int,
    val freshnessStaleColor: Int,
    val tryFeedBannerBackgroundColor: Int,
    val tryFeedBannerBorderColor: Int,
    val tryFeedBannerTitleColor: Int,
    val tryFeedBannerSubtitleColor: Int,
    val tryFeedButtonBackgroundColor: Int,
    val tryFeedButtonTextColor: Int,
)

fun discoverThemePalette(
    context: Context,
    prefsRepo: PrefsRepo,
): DiscoverThemePalette {
    var theme = prefsRepo.getSelectedTheme()
    if (theme == PrefConstants.ThemeValue.AUTO) {
        val nightModeFlags = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        theme =
            if (nightModeFlags == Configuration.UI_MODE_NIGHT_YES) {
                PrefConstants.ThemeValue.DARK
            } else {
                PrefConstants.ThemeValue.LIGHT
            }
    }

    return when (theme) {
        PrefConstants.ThemeValue.SEPIA ->
            DiscoverThemePalette(
                backgroundColor = color(context, R.color.bar_background_sepia),
                surfaceColor = 0xFFFAF5ED.toInt(),
                borderColor = 0xFFD4C8B8.toInt(),
                textPrimaryColor = 0xFF5C4A3D.toInt(),
                textSecondaryColor = 0xFF8B7B6B.toInt(),
                accentColor = 0xFF6AA84F.toInt(),
                accentTextColor = 0xFFFFFFFF.toInt(),
                secondaryButtonBackgroundColor = 0xFFF0E8DC.toInt(),
                secondaryButtonTextColor = 0xFF5C4A3D.toInt(),
                segmentedBackgroundColor = color(context, R.color.segmented_control_background_sepia),
                segmentedSelectedColor = color(context, R.color.segmented_control_selected_sepia),
                segmentedTextColor = color(context, R.color.segmented_control_text_sepia),
                segmentedSelectedTextColor = color(context, R.color.segmented_control_selected_text_sepia),
                segmentedBorderColor = color(context, R.color.segmented_control_border_sepia),
                freshnessActiveColor = 0xFF4CAF50.toInt(),
                freshnessStaleColor = 0xFFF9A825.toInt(),
                tryFeedBannerBackgroundColor = 0xFFE8DED0.toInt(),
                tryFeedBannerBorderColor = 0xFFD4C8B8.toInt(),
                tryFeedBannerTitleColor = 0xFF5C4A3D.toInt(),
                tryFeedBannerSubtitleColor = 0xFF8B7B6B.toInt(),
                tryFeedButtonBackgroundColor = 0xFF6AA84F.toInt(),
                tryFeedButtonTextColor = 0xFFFFFFFF.toInt(),
            )

        PrefConstants.ThemeValue.DARK ->
            DiscoverThemePalette(
                backgroundColor = color(context, R.color.dark_bar_background),
                surfaceColor = 0xFF2A2A2A.toInt(),
                borderColor = 0xFF404040.toInt(),
                textPrimaryColor = 0xFFE8E8E8.toInt(),
                textSecondaryColor = 0xFFB0B0B0.toInt(),
                accentColor = 0xFF6AA84F.toInt(),
                accentTextColor = 0xFFFFFFFF.toInt(),
                secondaryButtonBackgroundColor = 0xFF3A3A3A.toInt(),
                secondaryButtonTextColor = 0xFFD8D8D8.toInt(),
                segmentedBackgroundColor = color(context, R.color.segmented_control_background_dark),
                segmentedSelectedColor = color(context, R.color.segmented_control_selected_dark),
                segmentedTextColor = color(context, R.color.segmented_control_text_dark),
                segmentedSelectedTextColor = color(context, R.color.segmented_control_selected_text_dark),
                segmentedBorderColor = color(context, R.color.segmented_control_border_dark),
                freshnessActiveColor = 0xFF4CAF50.toInt(),
                freshnessStaleColor = 0xFFF9A825.toInt(),
                tryFeedBannerBackgroundColor = 0xFF2A3A28.toInt(),
                tryFeedBannerBorderColor = 0xFF4A5A48.toInt(),
                tryFeedBannerTitleColor = 0xFFC0D8B8.toInt(),
                tryFeedBannerSubtitleColor = 0xFF90B088.toInt(),
                tryFeedButtonBackgroundColor = 0xFF6AA84F.toInt(),
                tryFeedButtonTextColor = 0xFFFFFFFF.toInt(),
            )

        PrefConstants.ThemeValue.BLACK ->
            DiscoverThemePalette(
                backgroundColor = color(context, R.color.black),
                surfaceColor = 0xFF1D1D1D.toInt(),
                borderColor = 0xFF353535.toInt(),
                textPrimaryColor = 0xFFF0F0F0.toInt(),
                textSecondaryColor = 0xFFB8B8B8.toInt(),
                accentColor = 0xFF6AA84F.toInt(),
                accentTextColor = 0xFFFFFFFF.toInt(),
                secondaryButtonBackgroundColor = 0xFF2A2A2A.toInt(),
                secondaryButtonTextColor = 0xFFE0E0E0.toInt(),
                segmentedBackgroundColor = color(context, R.color.segmented_control_background_black),
                segmentedSelectedColor = color(context, R.color.segmented_control_selected_black),
                segmentedTextColor = color(context, R.color.segmented_control_text_black),
                segmentedSelectedTextColor = color(context, R.color.segmented_control_selected_text_black),
                segmentedBorderColor = color(context, R.color.segmented_control_border_black),
                freshnessActiveColor = 0xFF4CAF50.toInt(),
                freshnessStaleColor = 0xFFF9A825.toInt(),
                tryFeedBannerBackgroundColor = 0xFF223020.toInt(),
                tryFeedBannerBorderColor = 0xFF384836.toInt(),
                tryFeedBannerTitleColor = 0xFFC8E0C2.toInt(),
                tryFeedBannerSubtitleColor = 0xFF97B592.toInt(),
                tryFeedButtonBackgroundColor = 0xFF6AA84F.toInt(),
                tryFeedButtonTextColor = 0xFFFFFFFF.toInt(),
            )

        else ->
            DiscoverThemePalette(
                backgroundColor = color(context, R.color.bar_background),
                surfaceColor = 0xFFFFFFFF.toInt(),
                borderColor = 0xFFD0D2CC.toInt(),
                textPrimaryColor = 0xFF5E6267.toInt(),
                textSecondaryColor = 0xFF90928B.toInt(),
                accentColor = 0xFF6AA84F.toInt(),
                accentTextColor = 0xFFFFFFFF.toInt(),
                secondaryButtonBackgroundColor = 0xFFF0F1ED.toInt(),
                secondaryButtonTextColor = 0xFF5E6267.toInt(),
                segmentedBackgroundColor = color(context, R.color.segmented_control_background_light),
                segmentedSelectedColor = color(context, R.color.segmented_control_selected_light),
                segmentedTextColor = color(context, R.color.segmented_control_text_light),
                segmentedSelectedTextColor = color(context, R.color.segmented_control_selected_text_light),
                segmentedBorderColor = color(context, R.color.segmented_control_border_light),
                freshnessActiveColor = 0xFF4CAF50.toInt(),
                freshnessStaleColor = 0xFFF9A825.toInt(),
                tryFeedBannerBackgroundColor = 0xFFE8F0E6.toInt(),
                tryFeedBannerBorderColor = 0xFFC8D8C0.toInt(),
                tryFeedBannerTitleColor = 0xFF3D5C2E.toInt(),
                tryFeedBannerSubtitleColor = 0xFF6A8A5C.toInt(),
                tryFeedButtonBackgroundColor = 0xFF6AA84F.toInt(),
                tryFeedButtonTextColor = 0xFFFFFFFF.toInt(),
            )
    }
}

private fun color(
    context: Context,
    colorRes: Int,
): Int = ContextCompat.getColor(context, colorRes)
