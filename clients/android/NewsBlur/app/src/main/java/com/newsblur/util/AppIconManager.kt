package com.newsblur.util

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import androidx.annotation.DrawableRes
import androidx.annotation.StringRes
import com.newsblur.R

/**
 * Whether the launcher icon follows the device's light/dark setting or stays
 * pinned to a single appearance. Each flavor has three activity-aliases (auto,
 * light, dark); the enabled alias is the source of truth, so no extra
 * persistence is needed. See AppIconManager.kt.
 */
enum class AppIconAppearanceMode(
    @StringRes val titleRes: Int,
    @StringRes val captionRes: Int,
    /** Suffix appended to a flavor's activity-alias name; empty for the auto alias. */
    val componentSuffix: String,
) {
    LIGHT(
        R.string.settings_app_icon_appearance_light,
        R.string.settings_app_icon_appearance_light_caption,
        "Light",
    ),
    AUTO(
        R.string.settings_app_icon_appearance_auto,
        R.string.settings_app_icon_appearance_auto_caption,
        "",
    ),
    DARK(
        R.string.settings_app_icon_appearance_dark,
        R.string.settings_app_icon_appearance_dark_caption,
        "Dark",
    ),
}

/** A resolved flavor + appearance mode pair, as read back from the active alias. */
data class AppIconSelection(
    val flavor: AppIconFlavor,
    val mode: AppIconAppearanceMode,
)

data class AppIconFlavor(
    val id: String,
    val title: String,
    val aliasSuffix: String,
    val launcherIconRes: Int,
    val options: List<AppIconOption>,
)

data class AppIconOption(
    val id: String,
    val title: String,
    val flavor: String,
    val appearance: String,
    val previewRes: Int,
    val tintColor: Int,
)

object AppIconManager {
    const val LIGHT_APPEARANCE = "Light"
    const val DARK_APPEARANCE = "Dark"

    val flavors: List<AppIconFlavor> =
        listOf(
            flavor(
                id = "sunrise-gold",
                title = "Sunrise Gold",
                aliasSuffix = ".activity.LauncherSunriseGold",
                launcherIconRes = R.mipmap.app_icon_sunrise_gold,
                lightPreviewRes = R.drawable.app_icon_sunrise_gold_light,
                darkPreviewRes = R.drawable.app_icon_sunrise_gold_dark,
                lightTint = 0xD88A26,
                darkTint = 0xDDA033,
            ),
            flavor(
                id = "meadow-sage",
                title = "Meadow Sage",
                aliasSuffix = ".activity.LauncherMeadowSage",
                launcherIconRes = R.mipmap.app_icon_meadow_sage,
                lightPreviewRes = R.drawable.app_icon_meadow_sage_light,
                darkPreviewRes = R.drawable.app_icon_meadow_sage_dark,
                lightTint = 0x6F9E5B,
                darkTint = 0x7DBD63,
            ),
            flavor(
                id = "atlantic-blue",
                title = "Atlantic Blue",
                aliasSuffix = ".activity.LauncherAtlanticBlue",
                launcherIconRes = R.mipmap.app_icon_atlantic_blue,
                lightPreviewRes = R.drawable.app_icon_atlantic_blue_light,
                darkPreviewRes = R.drawable.app_icon_atlantic_blue_dark,
                lightTint = 0x3F85BC,
                darkTint = 0x4FA2D9,
            ),
            flavor(
                id = "coral-rose",
                title = "Coral Rose",
                aliasSuffix = ".activity.LauncherCoralRose",
                launcherIconRes = R.mipmap.app_icon_coral_rose,
                lightPreviewRes = R.drawable.app_icon_coral_rose_light,
                darkPreviewRes = R.drawable.app_icon_coral_rose_dark,
                lightTint = 0xD86868,
                darkTint = 0xE96E76,
            ),
            flavor(
                id = "ruby-red",
                title = "Ruby Red",
                aliasSuffix = ".activity.LauncherRubyRed",
                launcherIconRes = R.mipmap.app_icon_ruby_red,
                lightPreviewRes = R.drawable.app_icon_ruby_red_light,
                darkPreviewRes = R.drawable.app_icon_ruby_red_dark,
                lightTint = 0xCC3147,
                darkTint = 0xE5475C,
            ),
            flavor(
                id = "ember-orange",
                title = "Ember Orange",
                aliasSuffix = ".activity.LauncherEmberOrange",
                launcherIconRes = R.mipmap.app_icon_ember_orange,
                lightPreviewRes = R.drawable.app_icon_ember_orange_light,
                darkPreviewRes = R.drawable.app_icon_ember_orange_dark,
                lightTint = 0xD96B27,
                darkTint = 0xE56F28,
            ),
            flavor(
                id = "teal-mint",
                title = "Teal Mint",
                aliasSuffix = ".activity.LauncherTealMint",
                launcherIconRes = R.mipmap.app_icon_teal_mint,
                lightPreviewRes = R.drawable.app_icon_teal_mint_light,
                darkPreviewRes = R.drawable.app_icon_teal_mint_dark,
                lightTint = 0x2FA28E,
                darkTint = 0x3CC3AD,
            ),
            flavor(
                id = "lavender-iris",
                title = "Lavender Iris",
                aliasSuffix = ".activity.LauncherLavenderIris",
                launcherIconRes = R.mipmap.app_icon_lavender_iris,
                lightPreviewRes = R.drawable.app_icon_lavender_iris_light,
                darkPreviewRes = R.drawable.app_icon_lavender_iris_dark,
                lightTint = 0x8261CE,
                darkTint = 0x9879EA,
            ),
            flavor(
                id = "slate-gray",
                title = "Slate Gray",
                aliasSuffix = ".activity.LauncherSlateGray",
                launcherIconRes = R.mipmap.app_icon_slate_gray,
                lightPreviewRes = R.drawable.app_icon_slate_gray_light,
                darkPreviewRes = R.drawable.app_icon_slate_gray_dark,
                lightTint = 0x6C7D8A,
                darkTint = 0x81919D,
            ),
            flavor(
                id = "sepia-cocoa",
                title = "Sepia Cocoa",
                aliasSuffix = ".activity.LauncherSepiaCocoa",
                launcherIconRes = R.mipmap.app_icon_sepia_cocoa,
                lightPreviewRes = R.drawable.app_icon_sepia_cocoa_light,
                darkPreviewRes = R.drawable.app_icon_sepia_cocoa_dark,
                lightTint = 0xA16E44,
                darkTint = 0xB87945,
            ),
            flavor(
                id = "arctic-cyan",
                title = "Arctic Cyan",
                aliasSuffix = ".activity.LauncherArcticCyan",
                launcherIconRes = R.mipmap.app_icon_arctic_cyan,
                lightPreviewRes = R.drawable.app_icon_arctic_cyan_light,
                darkPreviewRes = R.drawable.app_icon_arctic_cyan_dark,
                lightTint = 0x37A8CA,
                darkTint = 0x44BADB,
            ),
            flavor(
                id = "plum-berry",
                title = "Plum Berry",
                aliasSuffix = ".activity.LauncherPlumBerry",
                launcherIconRes = R.mipmap.app_icon_plum_berry,
                lightPreviewRes = R.drawable.app_icon_plum_berry_light,
                darkPreviewRes = R.drawable.app_icon_plum_berry_dark,
                lightTint = 0xA74A98,
                darkTint = 0xC060B2,
            ),
        )

    val defaultFlavor: AppIconFlavor = flavors[0]

    fun flavorById(id: String?): AppIconFlavor = flavors.firstOrNull { it.id == id } ?: defaultFlavor

    /** Preview option for a flavor given the chosen mode and the system appearance. */
    fun displayOption(
        flavor: AppIconFlavor,
        mode: AppIconAppearanceMode,
        isSystemDark: Boolean,
    ): AppIconOption {
        val useDark =
            when (mode) {
                AppIconAppearanceMode.LIGHT -> false
                AppIconAppearanceMode.DARK -> true
                AppIconAppearanceMode.AUTO -> isSystemDark
            }
        val appearance = if (useDark) DARK_APPEARANCE else LIGHT_APPEARANCE
        return flavor.options.firstOrNull { it.appearance == appearance } ?: flavor.options[0]
    }

    /** Resolves which flavor + appearance mode is currently active. */
    fun currentSelection(context: Context): AppIconSelection {
        val packageManager = context.packageManager
        for (flavor in flavors) {
            for (mode in AppIconAppearanceMode.entries) {
                val state = packageManager.getComponentEnabledSetting(componentName(context, flavor, mode))
                if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                    return AppIconSelection(flavor, mode)
                }
            }
        }
        // Nothing is explicitly enabled, so the manifest default (Sunrise Gold, auto) is live.
        return AppIconSelection(defaultFlavor, AppIconAppearanceMode.AUTO)
    }

    fun currentFlavor(context: Context): AppIconFlavor = currentSelection(context).flavor

    fun currentMode(context: Context): AppIconAppearanceMode = currentSelection(context).mode

    /** Enables the alias for [flavor] + [mode] and disables every other launcher alias. */
    fun setAppIcon(
        context: Context,
        flavor: AppIconFlavor,
        mode: AppIconAppearanceMode,
    ) {
        val packageManager = context.packageManager
        packageManager.setComponentEnabledSetting(
            componentName(context, flavor, mode),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (otherFlavor in flavors) {
            for (otherMode in AppIconAppearanceMode.entries) {
                if (otherFlavor.id == flavor.id && otherMode == mode) continue
                packageManager.setComponentEnabledSetting(
                    componentName(context, otherFlavor, otherMode),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
        }
    }

    fun componentName(
        context: Context,
        flavor: AppIconFlavor,
        mode: AppIconAppearanceMode,
    ): ComponentName =
        ComponentName(
            context.packageName,
            context.packageName + flavor.aliasSuffix + mode.componentSuffix,
        )

    private fun flavor(
        id: String,
        title: String,
        aliasSuffix: String,
        @DrawableRes launcherIconRes: Int,
        @DrawableRes lightPreviewRes: Int,
        @DrawableRes darkPreviewRes: Int,
        lightTint: Int,
        darkTint: Int,
    ): AppIconFlavor =
        AppIconFlavor(
            id = id,
            title = title,
            aliasSuffix = aliasSuffix,
            launcherIconRes = launcherIconRes,
            options =
                listOf(
                    AppIconOption(
                        id = "$id-light",
                        title = "$title Light",
                        flavor = title,
                        appearance = LIGHT_APPEARANCE,
                        previewRes = lightPreviewRes,
                        tintColor = 0xFF000000.toInt() or lightTint,
                    ),
                    AppIconOption(
                        id = "$id-dark",
                        title = "$title Dark",
                        flavor = title,
                        appearance = DARK_APPEARANCE,
                        previewRes = darkPreviewRes,
                        tintColor = 0xFF000000.toInt() or darkTint,
                    ),
                ),
        )
}
