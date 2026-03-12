package com.newsblur.askai

import androidx.compose.ui.graphics.toArgb
import com.newsblur.design.Black
import com.newsblur.design.Gray10
import com.newsblur.design.Gray96
import com.newsblur.design.NbSepiaSurface
import com.newsblur.util.PrefConstants.ThemeValue
import org.junit.Assert.assertEquals
import org.junit.Test

class AskAiSheetThemeTest {
    @Test
    fun askAiSheetBackgroundMatchesReaderThemeSurface() {
        assertEquals(Gray96.toArgb(), askAiSheetBackgroundColor(ThemeValue.LIGHT).toArgb())
        assertEquals(NbSepiaSurface.toArgb(), askAiSheetBackgroundColor(ThemeValue.SEPIA).toArgb())
        assertEquals(Gray10.toArgb(), askAiSheetBackgroundColor(ThemeValue.DARK).toArgb())
        assertEquals(Black.toArgb(), askAiSheetBackgroundColor(ThemeValue.BLACK).toArgb())
    }
}
