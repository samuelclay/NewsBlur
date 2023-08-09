package com.newsblur.util

import kotlinx.coroutines.*

import android.view.View
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val TAG = "NBScope"

fun <R> CoroutineScope.executeAsyncTask(
        onPreExecute: () -> Unit = { },
        doInBackground: () -> R,
        onPostExecute: (R) -> Unit = { }) =
        launch {
            withContext(Dispatchers.Main) { onPreExecute() }
            val result = withContext(Dispatchers.IO) { doInBackground() }
            withContext(Dispatchers.Main) { onPostExecute(result) }
        }

val NBScope = CoroutineScope(
        CoroutineName(TAG) +
                Dispatchers.Default +
                SupervisorJob() + // children coroutines won't stop parent if they cancel or error
                CoroutineExceptionHandler { context, throwable ->
                    Log.e(TAG, "Coroutine exception on context $context with $throwable")
                })

fun View.setViewGone() {
    this.visibility = View.GONE
}

fun View.setViewVisible() {
    this.visibility = View.VISIBLE
}