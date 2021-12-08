package com.newsblur.util

import kotlinx.coroutines.*

private const val TAG = "NBScope"

fun <R> CoroutineScope.executeAsyncTask(
        onPreExecute: () -> Unit = { },
        doInBackground: () -> R,
        onPostExecute: (R) -> Unit = { }) =
        launch {
            onPreExecute()
            val result = withContext(Dispatchers.IO) { doInBackground() }
            onPostExecute(result)
        }

val NBScope = CoroutineScope(
        CoroutineName(TAG) +
                Dispatchers.Default +
                SupervisorJob() + // children coroutines won't stop parent if they cancel or error
                CoroutineExceptionHandler { context, throwable ->
                    Log.e(TAG, "Coroutine exception on context $context with $throwable")
                })