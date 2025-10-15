@file:OptIn(ExperimentalMaterial3Api::class)

package com.newsblur.design

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.TextButton
import androidx.wear.compose.material3.TextButtonDefaults

@Composable
fun NbTopAppBar(title: String) {
    val cs = MaterialTheme.colorScheme
    val nb = LocalNbColors.current
    TopAppBar(
        title = { Text(title, color = cs.onPrimary) },
        colors =
            androidx.compose.material3.TopAppBarDefaults.topAppBarColors(
                containerColor = nb.barBackground,
                titleContentColor = cs.onPrimary,
                navigationIconContentColor = cs.onPrimary,
                actionIconContentColor = cs.onPrimary,
            ),
    )
}

@Composable
fun NbDelimiter() = androidx.compose.material3.Divider(color = LocalNbColors.current.delimiter)

@Composable
fun NbRowBorder() = androidx.compose.material3.Divider(color = LocalNbColors.current.rowBorder)

// default text
@Composable
fun NbBody(text: String) = Text(text, color = LocalNbColors.current.textDefault)

// link text
@Composable
fun NbLink(
    text: String,
    onClick: () -> Unit,
) = Text(
    text = text,
    color = LocalNbColors.current.textLink,
    modifier = Modifier.clickable(onClick = onClick),
)

// reading background
@Composable
fun NbReadingSurface(content: @Composable () -> Unit) {
    Surface(color = LocalNbColors.current.itemBackground, content = content)
}

// chip
@Composable
fun NbAssistChip(
    label: String,
    onClick: () -> Unit,
) {
    val nb = LocalNbColors.current
    AssistChip(
        onClick = onClick,
        label = { Text(label, color = nb.chipLabel) },
        colors = AssistChipDefaults.assistChipColors(containerColor = nb.chipContainer),
    )
}

// actionButtons, storyButtons, toggleButtons
@Composable
fun NbActionButton(
    text: String,
    onClick: () -> Unit,
) {
    val nb = LocalNbColors.current
    TextButton(
        onClick = onClick,
        colors =
            TextButtonDefaults.textButtonColors(
                contentColor = nb.buttonText,
                containerColor = nb.buttonBackground,
            ),
        modifier = Modifier.height(40.dp), // like toggleButton style
    ) { Text(text) }
}

@Composable
fun NbSnackBarHost(host: SnackbarHostState) {
    val nb = LocalNbColors.current
    val cs = MaterialTheme.colorScheme
    SnackbarHost(hostState = host) { data ->
        Snackbar(
            containerColor = nb.snackbarContainer,
            contentColor = cs.onPrimary,
        ) {
            Text(
                data.visuals.message,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
fun NbDropdownMenu(
    expanded: Boolean,
    onDismiss: () -> Unit,
    container: Color = LocalNbColors.current.barBackground,
    content: @Composable ColumnScope.() -> Unit,
) {
    DropdownMenu(expanded = expanded, onDismissRequest = onDismiss) {
        Surface(color = container) { Column(content = content) }
    }
}
