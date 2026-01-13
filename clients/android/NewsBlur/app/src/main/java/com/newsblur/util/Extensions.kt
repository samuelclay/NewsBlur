package com.newsblur.util

import android.view.View
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val TAG = "NBScope"

fun <R> CoroutineScope.executeAsyncTask(
    onPreExecute: () -> Unit = { },
    doInBackground: suspend () -> R,
    onPostExecute: (R) -> Unit = { },
) = launch(Dispatchers.IO) {
    withContext(Dispatchers.Main) { onPreExecute() }
    val result = doInBackground()
    withContext(Dispatchers.Main) { onPostExecute(result) }
}

@JvmField
val NBScope =
    CoroutineScope(
        CoroutineName(TAG) +
            Dispatchers.Default +
            SupervisorJob() + // children coroutines won't stop parent if they cancel or error
            CoroutineExceptionHandler { context, throwable ->
                Log.e(TAG, "Coroutine exception on context $context with $throwable")
            },
    )

fun View.setViewGone() {
    this.visibility = View.GONE
}

fun View.setViewVisible() {
    this.visibility = View.VISIBLE
}
