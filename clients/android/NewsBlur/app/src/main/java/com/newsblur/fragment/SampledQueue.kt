package com.newsblur.fragment

import com.newsblur.util.NBScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.sample
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class SampledQueue(
        intervalMillis: Long = 250,
        capacity: Int = 5,
        scope: CoroutineScope = NBScope) {

    private val mutex = Mutex()
    private val queue = MutableSharedFlow<() -> Unit>(extraBufferCapacity = capacity, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    private var isOpen = true

    init {
        queue.sample(intervalMillis)
                .map { it }
                .launchIn(scope)
    }

    fun add(action: () -> Unit) = runBlocking {
        mutex.withLock {
            if (!isOpen) return@runBlocking
            queue.emit(action)
        }
    }

    fun close(): Unit = runBlocking {
        mutex.withLock {
            if (!isOpen) return@runBlocking
            isOpen = false
        }
    }

}