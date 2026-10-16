package com.newsblur.compose

import android.content.Context
import android.content.res.Configuration
import android.text.TextUtils
import android.view.View
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.intl.LocaleList
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.newsblur.R
import com.newsblur.design.NbSepiaLink
import com.newsblur.design.NbSepiaMutedText
import com.newsblur.design.NbSepiaSurface
import com.newsblur.design.NbSepiaText
import com.newsblur.onboarding.SetupPalette
import com.newsblur.util.LanguageChooserRules
import com.newsblur.util.LanguageSettings
import com.newsblur.util.PrefConstants.ThemeValue
import java.util.Locale

/*
 * LanguageChooser.kt asks which language NewsBlur should use. LanguageChooserDialog.kt shows it once over the feed
 * list and SetupLanguageStep.kt makes it the first page of setup. When the device language isn't English it is
 * parallel text: the same message in the detected language and in English, row for row, so someone who can't read
 * the detected language still recognizes the way back. English-detected people get a grid of every language.
 */

data class LanguageChooserColors(
    val surface: Color,
    val title: Color,
    val body: Color,
    val muted: Color,
    val rule: Color,
    val link: Color,
    // Selected grid option tint and check mark.
    val accent: Color,
    val button: Color = ChooserTeal,
    val buttonText: Color = Color.White,
    // Edge of the dialog card where the surface alone would vanish into the scrim (black theme).
    val outline: Color = Color.Transparent,
)

// SetupScreen.kt's primary button, so the dialog and the first setup page share one action color.
private val ChooserTeal = Color(0xFF406663)
private val ChooserTealOnDark = Color(0xFFA3CBC3)

object LanguageChooserPalette {
    /** LanguageChooserDialog.kt's card over the feed list. Light uses NewsBlur's ink, body and icon-gray roles. */
    fun dialog(theme: ThemeValue): LanguageChooserColors =
        when (theme) {
            ThemeValue.SEPIA ->
                LanguageChooserColors(
                    surface = NbSepiaSurface,
                    title = NbSepiaText,
                    body = Color(0xFF5C4A3D),
                    muted = NbSepiaMutedText,
                    rule = Color(0xFFE3D7C6),
                    link = NbSepiaLink,
                    accent = ChooserTeal,
                )

            ThemeValue.DARK ->
                LanguageChooserColors(
                    surface = Color(0xFF3D3D3D),
                    title = Color(0xFFE6E6E6),
                    body = Color(0xFFC4C4C4),
                    muted = Color(0xFFA0A09A),
                    rule = Color(0xFF555555),
                    link = Color(0xFFA3C3ED),
                    accent = ChooserTealOnDark,
                )

            ThemeValue.BLACK ->
                LanguageChooserColors(
                    surface = Color(0xFF1A1A1A),
                    title = Color(0xFFE8E8E8),
                    body = Color(0xFFBDBDBD),
                    muted = Color(0xFF9A9A94),
                    rule = Color(0xFF363636),
                    link = Color(0xFFA3C3ED),
                    accent = ChooserTealOnDark,
                    outline = Color(0xFF363636),
                )

            else ->
                LanguageChooserColors(
                    surface = Color.White,
                    title = Color(0xFF404040),
                    body = Color(0xFF606060),
                    muted = Color(0xFF95968E),
                    rule = Color(0xFFE3E1DA),
                    link = Color(0xFF405BA8),
                    accent = ChooserTeal,
                )
        }

    /** SetupLanguageStep.kt sets the chooser on a SetupPalette.kt card, like the other setup panels. */
    fun setup(theme: ThemeValue): LanguageChooserColors {
        val setup = SetupPalette.colors(theme)
        return dialog(theme).copy(surface = setup.cardBackground, rule = setup.border, outline = Color.Transparent)
    }
}

/**
 * [detected] is the language the interface resolved to while the account language is Automatic. [onKeep] keeps
 * Automatic; [onChoose] saves an explicit language. [scrolls] is false where a parent list already scrolls.
 */
@Composable
fun LanguageChooser(
    detected: String,
    colors: LanguageChooserColors,
    onKeep: () -> Unit,
    onChoose: (String) -> Unit,
    modifier: Modifier = Modifier,
    scrolls: Boolean = true,
) {
    val context = LocalContext.current
    val local = remember(context, detected) { chooserCopy(context, detected, detected) }
    val english = remember(context, detected) { chooserCopy(context, "en", detected) }
    val bilingual = detected != "en"
    var grid by rememberSaveable { mutableStateOf(!bilingual) }
    // Back from a grid opened by "Choose another language" returns to the parallel text.
    BackHandler(enabled = grid && bilingual) { grid = false }
    val label = stringResource(R.string.language_title)
    InLanguage(detected) {
        BoxWithConstraints(modifier.fillMaxWidth().semantics { paneTitle = label }) {
            val wide = maxWidth >= 560.dp
            if (grid) {
                LanguageGrid(local, english, colors, wide, scrolls, if (bilingual) ({ grid = false }) else null, onKeep, onChoose)
            } else {
                Bilingual(local, english, colors, wide, scrolls, onKeep, { onChoose("en") }) { grid = true }
            }
        }
    }
}

/** One column's text, loaded from that language's own resources so each column reads as a complete message. */
private class ChooserCopy(
    val language: String,
    val localized: Context,
    val tag: String,
    val title: String,
    val body: String,
    val note: String,
    val use: String,
    val another: String,
    val pick: String,
    val back: String,
)

private fun chooserCopy(
    context: Context,
    language: String,
    detected: String,
): ChooserCopy {
    val localized = localizedContext(context, language)
    val name = nativeName(language)
    // The detected column names its language natively ("Deutsch"); the English column says "German".
    val detectedName = if (language == detected) name else LanguageChooserRules.englishName(detected, nativeName(detected))
    return ChooserCopy(
        language = language,
        localized = localized,
        tag = name,
        title = localized.getString(R.string.language_dialog_title),
        body = localized.getString(R.string.language_dialog_detected, detectedName),
        note = localized.getString(R.string.language_dialog_note),
        use = localized.getString(R.string.language_dialog_use, name),
        another = localized.getString(R.string.language_dialog_choose_another),
        pick = localized.getString(R.string.language_dialog_pick),
        back = localized.getString(R.string.contact_back),
    )
}

private fun nativeName(language: String) = LanguageSettings.names[language] ?: language

private fun localizedContext(
    context: Context,
    language: String,
): Context {
    val configuration = Configuration(context.resources.configuration)
    configuration.setLocale(Locale.forLanguageTag(language))
    return context.createConfigurationContext(configuration)
}

private fun directionOf(language: String): LayoutDirection =
    if (TextUtils.getLayoutDirectionFromLocale(Locale.forLanguageTag(language)) == View.LAYOUT_DIRECTION_RTL) {
        LayoutDirection.Rtl
    } else {
        LayoutDirection.Ltr
    }

/** Each column and grid option lays out in its own language's direction, whatever the interface direction is. */
@Composable
private fun InLanguage(
    language: String,
    content: @Composable () -> Unit,
) {
    CompositionLocalProvider(LocalLayoutDirection provides directionOf(language), content = content)
}

/** Tags text with its language so line breaking, CJK glyph forms and TalkBack's voice follow it. */
private fun tagged(
    text: String,
    language: String,
): AnnotatedString = buildAnnotatedString { withStyle(SpanStyle(localeList = LocaleList(language))) { append(text) } }

private object ChooserType {
    val tag = TextStyle(fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.SemiBold)
    val body = TextStyle(fontSize = 15.sp, lineHeight = 22.sp)
    val note = TextStyle(fontSize = 14.sp, lineHeight = 20.sp)
    val button = TextStyle(fontSize = 15.sp, lineHeight = 20.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
    val link = TextStyle(fontSize = 15.sp, lineHeight = 20.sp)
    // No fixed line height: Thai and Devanagari names sit centered only at their font's natural height.
    val option = TextStyle(fontSize = 15.sp)
    val echoTitle = TextStyle(fontSize = 15.sp, lineHeight = 20.sp, fontWeight = FontWeight.SemiBold)

    fun title(wide: Boolean) =
        TextStyle(fontSize = if (wide) 22.sp else 20.sp, lineHeight = if (wide) 28.sp else 26.sp, fontWeight = FontWeight.SemiBold)
}

// Space above each row, shared by the side-by-side and stacked layouts so both halves read the same way.
private val TitleGap = 6.dp
private val BodyGap = 10.dp
private val NoteGap = 8.dp
private val ButtonGap = 20.dp
private val LinkGap = 4.dp
private val RuleGutter = 32.dp

@Composable
private fun Bilingual(
    local: ChooserCopy,
    english: ChooserCopy,
    colors: LanguageChooserColors,
    wide: Boolean,
    scrolls: Boolean,
    onKeep: () -> Unit,
    onEnglish: () -> Unit,
    onAnother: () -> Unit,
) {
    val scroll = if (scrolls) Modifier.verticalScroll(rememberScrollState()) else Modifier
    val title = ChooserType.title(wide)
    if (wide) {
        // Each row is one Row, so a title, body or button that runs longer in one language moves both columns
        // down together and the two messages stay aligned line for line.
        Column(scroll.fillMaxWidth().padding(horizontal = 28.dp, vertical = 24.dp)) {
            Paired(local, english, colors, 0.dp) { Tag(it, colors) }
            Paired(local, english, colors, TitleGap) { Title(it, title, colors) }
            Paired(local, english, colors, BodyGap) { Body(it, colors) }
            Paired(local, english, colors, NoteGap) { Note(it, colors) }
            Paired(local, english, colors, ButtonGap) {
                ChooserButton(it.use, it.language, colors, if (it === local) onKeep else onEnglish, Modifier.fillMaxWidth().fillMaxHeight())
            }
            Paired(local, english, colors, LinkGap) { Link(it.another, it.language, colors, onAnother) }
        }
    } else {
        Column(scroll.fillMaxWidth()) {
            Half(local, colors, title, onKeep, onAnother)
            HorizontalDivider(thickness = 1.dp, color = colors.rule)
            Half(english, colors, title, onEnglish, onAnother)
        }
    }
}

@Composable
private fun Paired(
    start: ChooserCopy,
    end: ChooserCopy,
    colors: LanguageChooserColors,
    gap: Dp,
    cell: @Composable (ChooserCopy) -> Unit,
) {
    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
        Box(Modifier.weight(1f).fillMaxHeight().padding(top = gap, end = RuleGutter)) { Cell(start, cell) }
        // The hairline is drawn per row with no gaps between rows, so it runs unbroken from tag to link.
        Box(Modifier.width(1.dp).fillMaxHeight().background(colors.rule))
        Box(Modifier.weight(1f).fillMaxHeight().padding(top = gap, start = RuleGutter)) { Cell(end, cell) }
    }
}

@Composable
private fun Cell(
    copy: ChooserCopy,
    cell: @Composable (ChooserCopy) -> Unit,
) {
    InLanguage(copy.language) { Column(Modifier.fillMaxSize()) { cell(copy) } }
}

@Composable
private fun Half(
    copy: ChooserCopy,
    colors: LanguageChooserColors,
    title: TextStyle,
    onUse: () -> Unit,
    onAnother: () -> Unit,
) {
    InLanguage(copy.language) {
        Column(Modifier.fillMaxWidth().padding(start = 24.dp, end = 24.dp, top = 22.dp, bottom = 10.dp)) {
            Tag(copy, colors)
            Spacer(Modifier.height(TitleGap))
            Title(copy, title, colors)
            Spacer(Modifier.height(BodyGap))
            Body(copy, colors)
            Spacer(Modifier.height(NoteGap))
            Note(copy, colors)
            Spacer(Modifier.height(ButtonGap))
            ChooserButton(copy.use, copy.language, colors, onUse, Modifier.fillMaxWidth())
            Spacer(Modifier.height(LinkGap))
            Link(copy.another, copy.language, colors, onAnother)
        }
    }
}

@Composable
private fun Tag(
    copy: ChooserCopy,
    colors: LanguageChooserColors,
) = Text(tagged(copy.tag, copy.language), style = ChooserType.tag, color = colors.muted)

@Composable
private fun Title(
    copy: ChooserCopy,
    style: TextStyle,
    colors: LanguageChooserColors,
) = Text(tagged(copy.title, copy.language), style = style, color = colors.title)

@Composable
private fun Body(
    copy: ChooserCopy,
    colors: LanguageChooserColors,
) = Text(tagged(copy.body, copy.language), style = ChooserType.body, color = colors.body)

@Composable
private fun Note(
    copy: ChooserCopy,
    colors: LanguageChooserColors,
) = Text(tagged(copy.note, copy.language), style = ChooserType.note, color = colors.body)

@Composable
private fun ChooserButton(
    text: String,
    language: String,
    colors: LanguageChooserColors,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        modifier = modifier.heightIn(min = 48.dp),
        shape = RoundedCornerShape(12.dp),
        colors = ButtonDefaults.buttonColors(containerColor = colors.button, contentColor = colors.buttonText),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text(tagged(text, language), style = ChooserType.button)
    }
}

@Composable
private fun Link(
    text: String,
    language: String,
    colors: LanguageChooserColors,
    onClick: () -> Unit,
) {
    Box(Modifier.heightIn(min = 44.dp).clickable(role = Role.Button, onClick = onClick), contentAlignment = Alignment.CenterStart) {
        Text(tagged(text, language), style = ChooserType.link, color = colors.link)
    }
}

@Composable
private fun LanguageGrid(
    local: ChooserCopy,
    english: ChooserCopy,
    colors: LanguageChooserColors,
    wide: Boolean,
    scrolls: Boolean,
    onBack: (() -> Unit)?,
    onKeep: () -> Unit,
    onChoose: (String) -> Unit,
) {
    val current = local.language
    var selected by rememberSaveable { mutableStateOf(current) }
    val columns = if (wide) 3 else 2
    val apply = { if (selected == current) onKeep() else onChoose(selected) }
    Column(Modifier.fillMaxWidth()) {
        // In the dialog the options scroll under a pinned button; in setup the page scrolls instead.
        val scrollState = rememberScrollState()
        val scroll = if (scrolls) Modifier.weight(1f, fill = false).verticalScroll(scrollState) else Modifier
        Column(scroll.fillMaxWidth().padding(start = 24.dp, end = 24.dp, top = 24.dp, bottom = if (scrolls) 16.dp else 0.dp)) {
            InLanguage(local.language) {
                Column(Modifier.fillMaxWidth()) {
                    Text(tagged(local.title, local.language), style = ChooserType.title(wide), color = colors.title)
                    Spacer(Modifier.height(BodyGap))
                    Text(tagged(local.pick, local.language), style = ChooserType.body, color = colors.body)
                }
            }
            if (local.language != english.language) {
                // The English source follows the interface language, so the grid keeps the bilingual promise.
                InLanguage(english.language) {
                    Column(Modifier.fillMaxWidth().padding(top = 14.dp)) {
                        Text(tagged(english.title, english.language), style = ChooserType.echoTitle, color = colors.muted)
                        Spacer(Modifier.height(4.dp))
                        Text(tagged(english.pick, english.language), style = ChooserType.note, color = colors.muted)
                    }
                }
            }
            Column(Modifier.padding(top = 20.dp).selectableGroup(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                LanguageSettings.names.entries.chunked(columns).forEach { row ->
                    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { (code, name) ->
                            Option(code, name, code == selected, colors, Modifier.weight(1f).fillMaxHeight()) { selected = code }
                        }
                        repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
        // A hairline marks where the options pass under the pinned button.
        if (scrolls && scrollState.maxValue > 0) HorizontalDivider(thickness = 1.dp, color = colors.rule)
        val label = remember(local, selected) { local.localized.getString(R.string.language_dialog_use, nativeName(selected)) }
        InLanguage(local.language) {
            if (wide) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                    onBack?.let { Link(local.back, local.language, colors, it) }
                    Spacer(Modifier.weight(1f))
                    ChooserButton(label, local.language, colors, apply, Modifier.widthIn(min = 240.dp))
                }
            } else {
                Column(Modifier.fillMaxWidth().padding(start = 24.dp, end = 24.dp, top = 16.dp, bottom = if (onBack != null) 10.dp else 24.dp)) {
                    ChooserButton(label, local.language, colors, apply, Modifier.fillMaxWidth())
                    onBack?.let {
                        Spacer(Modifier.height(LinkGap))
                        Link(local.back, local.language, colors, it)
                    }
                }
            }
        }
    }
}

@Composable
private fun Option(
    code: String,
    name: String,
    selected: Boolean,
    colors: LanguageChooserColors,
    modifier: Modifier,
    onSelect: () -> Unit,
) {
    val shape = RoundedCornerShape(10.dp)
    // Each name runs in its own direction, but every option lines up with the interface so the grid reads as one
    // column of names rather than a few right-aligned strays among left-aligned ones.
    val align = if (LocalLayoutDirection.current == LayoutDirection.Ltr) TextAlign.Left else TextAlign.Right
    val direction = if (directionOf(code) == LayoutDirection.Rtl) TextDirection.Rtl else TextDirection.Ltr
    Row(
        modifier
            .heightIn(min = 48.dp)
            .clip(shape)
            .background(if (selected) colors.accent.copy(alpha = .1f) else Color.Transparent)
            .border(1.dp, if (selected) colors.accent.copy(alpha = .6f) else colors.rule, shape)
            .selectable(selected = selected, role = Role.RadioButton, onClick = onSelect)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            tagged(name, code),
            Modifier.weight(1f),
            style = ChooserType.option.copy(textAlign = align, textDirection = direction),
            color = colors.title,
        )
        if (selected) Icon(Icons.Outlined.Check, null, Modifier.padding(start = 6.dp).size(18.dp), tint = colors.accent)
    }
}
