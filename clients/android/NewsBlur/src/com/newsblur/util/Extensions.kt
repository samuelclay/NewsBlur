package com.newsblur.util

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

fun <R> CoroutineScope.executeAsyncTask(
        onPreExecute: () -> Unit = {  },
        doInBackground: () -> R,
        onPostExecute: (R) -> Unit = {  }) =
        launch {
            onPreExecute()
            val result = withContext(Dispatchers.IO) { doInBackground() }
            onPostExecute(result)
        }