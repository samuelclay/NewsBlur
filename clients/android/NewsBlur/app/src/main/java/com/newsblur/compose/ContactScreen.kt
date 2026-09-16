package com.newsblur.compose

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.newsblur.R
import com.newsblur.design.LocalNbColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ContactScreen(onBack: () -> Unit, onEmail: () -> Unit, onWebsite: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.contact_us)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.contact_back))
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Text(stringResource(R.string.app_name), style = MaterialTheme.typography.headlineMedium)
            Text(stringResource(R.string.contact_description))
            Text(stringResource(R.string.contact_email_label), style = MaterialTheme.typography.titleMedium)
            SelectionContainer { Text(stringResource(R.string.contact_email)) }
            Button(onClick = onEmail) { Text(stringResource(R.string.contact_send_email)) }
            Text(stringResource(R.string.contact_website_label), style = MaterialTheme.typography.titleMedium)
            SelectionContainer { Text(stringResource(R.string.contact_website)) }
            TextButton(
                onClick = onWebsite,
                colors = ButtonDefaults.textButtonColors(contentColor = LocalNbColors.current.textLink),
            ) { Text(stringResource(R.string.contact_open_website)) }
        }
    }
}
