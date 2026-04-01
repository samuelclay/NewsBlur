package com.newsblur.util

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import com.newsblur.util.PrefConstants.ThemeValue

object StoryClusterThemeStyle {
    data class Palette(
        val listBackgroundColor: Int,
        val listCardColor: Int,
        val detailSectionColor: Int,
        val detailSectionBorderColor: Int,
        val detailRowBorderColor: Int,
        val titleColor: Int,
        val readTitleColor: Int,
        val metaColor: Int,
        val readMetaColor: Int,
        val upgradePillColor: Int,
        val upgradeTextColor: Int,
    )

    fun palette(theme: ThemeValue): Palette =
        when (theme) {
            ThemeValue.SEPIA ->
                Palette(
                    listBackgroundColor = Color.parseColor("#F3E2CB"),
                    listCardColor = Color.parseColor("#ECDEC9"),
                    detailSectionColor = Color.parseColor("#F5E6D1"),
                    detailSectionBorderColor = Color.parseColor("#D7C5AE"),
                    detailRowBorderColor = Color.parseColor("#DDCCB7"),
                    titleColor = Color.parseColor("#333333"),
                    readTitleColor = Color.parseColor("#585858"),
                    metaColor = Color.parseColor("#8B7B6B"),
                    readMetaColor = Color.parseColor("#8B7B6B"),
                    upgradePillColor = Color.parseColor("#E8D7C5"),
                    upgradeTextColor = Color.parseColor("#6A4B2C"),
                )
            ThemeValue.DARK ->
                Palette(
                    listBackgroundColor = Color.parseColor("#4F4F4F"),
                    listCardColor = Color.parseColor("#363C43"),
                    detailSectionColor = Color.parseColor("#111111"),
                    detailSectionBorderColor = Color.parseColor("#222222"),
                    detailRowBorderColor = Color.parseColor("#14FFFFFF"),
                    titleColor = Color.parseColor("#DDDDDD"),
                    readTitleColor = Color.parseColor("#8C8C8C"),
                    metaColor = Color.parseColor("#8E8E8E"),
                    readMetaColor = Color.parseColor("#8E8E8E"),
                    upgradePillColor = Color.parseColor("#2992CBE0"),
                    upgradeTextColor = Color.parseColor("#BEE8F5"),
                )
            ThemeValue.BLACK ->
                Palette(
                    listBackgroundColor = Color.parseColor("#000000"),
                    listCardColor = Color.parseColor("#101418"),
                    detailSectionColor = Color.parseColor("#050505"),
                    detailSectionBorderColor = Color.parseColor("#1A1A1A"),
                    detailRowBorderColor = Color.parseColor("#18FFFFFF"),
                    titleColor = Color.parseColor("#D0D0D0"),
                    readTitleColor = Color.parseColor("#888888"),
                    metaColor = Color.parseColor("#808080"),
                    readMetaColor = Color.parseColor("#707070"),
                    upgradePillColor = Color.parseColor("#223B5162"),
                    upgradeTextColor = Color.parseColor("#C5E8F7"),
                )
            else ->
                Palette(
                    listBackgroundColor = Color.parseColor("#F4F4F4"),
                    listCardColor = Color.parseColor("#E8F0F8"),
                    detailSectionColor = Color.parseColor("#F8F8F8"),
                    detailSectionBorderColor = Color.parseColor("#D6D6D6"),
                    detailRowBorderColor = Color.parseColor("#E9E9E9"),
                    titleColor = Color.parseColor("#202020"),
                    readTitleColor = Color.parseColor("#6E6E6E"),
                    metaColor = Color.parseColor("#7E7E7E"),
                    readMetaColor = Color.parseColor("#9A9A9A"),
                    upgradePillColor = Color.parseColor("#E9F3FF"),
                    upgradeTextColor = Color.parseColor("#1C5DAA"),
                )
        }

    fun roundedBackground(color: Int, radiusDp: Float): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radiusDp
            setColor(color)
        }
}
