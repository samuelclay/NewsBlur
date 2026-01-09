package com.newsblur.design

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

data class NbExtendedColors(
    // action bar / subscription header backgrounds
    val barBackground: Color,
    // text roles used in XML styles
    val textDefault: Color,
    val textLink: Color,
    val textSnippet: Color,
    val textFeedTitle: Color,
    val textMeta: Color,
    // rows / dividers
    val rowBorder: Color,
    val commentDivider: Color,
    val delimiter: Color,
    // story/reading/list backgrounds
    val itemBackground: Color,
    val itemBackgroundDarkAlt: Color,
    // chip & buttons
    val chipContainer: Color,
    val chipLabel: Color,
    val buttonText: Color,
    val buttonBackground: Color,
    // share bar
    val shareBarBackground: Color,
    val shareBarText: Color,
    // snackbar
    val snackbarContainer: Color,
    // misc
    val overlayBg: Color,
)

val LocalNbColors =
    staticCompositionLocalOf<NbExtendedColors> {
        error("No NbExtendedColors provided")
    }

// Light mapping from your XML colors
private val LightExt =
    NbExtendedColors(
        barBackground = NbGreenGray91, // @color/bar_background
        textDefault = Gray20, // @color/text
        textLink = Color(0xFF405BA8), // @color/linkblue
        textSnippet = Color(0xFF404040), // @color/story_content_text
        textFeedTitle = Color(0xFF606060), // @color/story_feed_title_text
        textMeta = Color(0x77434343), // @color/half_darkgray
        rowBorder = Gray95, // @color/row_border
        commentDivider = Color(0xFFF0F0F0), // @color/story_comment_divider
        delimiter = Gray85, // @color/gray85
        itemBackground = Color(0xFFF4F4F4), // @color/item_background
        itemBackgroundDarkAlt = Color(0xFFF5F5EF), // @color/share_bar_background (alt)
        chipContainer = Color(0xFFE0E0DE), // @color/tag_gray
        chipLabel = Gray55, // @color/gray55
        buttonText = Color(0xFF757575), // @color/button_text
        buttonBackground = Gray90, // @color/col_button_background
        shareBarBackground = Color(0xFFF5F5EF), // @color/share_bar_background
        shareBarText = Gray55,
        snackbarContainer = NbGreenGray91, // materialSnackBarTheme
        overlayBg = Color(0xAA777777),
    )

private val DarkExt =
    NbExtendedColors(
        barBackground = Gray13, // @color/dark_bar_background
        textDefault = Gray85, // @color/dark_text
        textLink = Color(0xFF319DC5), // @color/dark_linkblue
        textSnippet = Color(0xFFCECECE), // @color/dark_story_content_text
        textFeedTitle = Gray55, // @color/dark_story_feed_title_text
        textMeta = Color(0x7FFFFFFF), // @color/half_white
        rowBorder = Gray10, // @color/dark_row_border
        commentDivider = Color(0xFF42453E), // @color/dark_story_comment_divider
        delimiter = Gray30,
        itemBackground = Gray10, // @color/dark_item_background
        itemBackgroundDarkAlt = Gray10,
        chipContainer = Color(0xFF757575), // @color/tag_bg_dark
        chipLabel = Color(0xFFE0E0DE), // @color/tag_gray
        buttonText = Color(0xFFBFBFBF), // @color/button_text_dark ~ gray75
        buttonBackground = Gray20, // @color/col_button_background_dark
        shareBarBackground = Color(0xFF303030), // @color/dark_share_bar_background
        shareBarText = Gray55,
        snackbarContainer = Gray13, // materialSnackBarTheme.dark
        overlayBg = Color(0xAA777777),
    )

private val BlackExt =
    DarkExt.copy(
        barBackground = Black,
        itemBackground = Black,
        itemBackgroundDarkAlt = Gray07,
    )

// Hook into your existing theme
@Composable
fun ProvideNbExtendedColors(
    variant: NbThemeVariant,
    content: @Composable () -> Unit,
) {
    val ext =
        when (variant) {
            NbThemeVariant.Light -> LightExt
            NbThemeVariant.Dark -> DarkExt
            NbThemeVariant.Black -> BlackExt
            NbThemeVariant.System ->
                if (androidx.compose.foundation.isSystemInDarkTheme()) DarkExt else LightExt
        }
    CompositionLocalProvider(LocalNbColors provides ext, content = content)
}
