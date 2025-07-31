package com.newsblur.service

import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.ensureActive

class StarredSubService(delegate: SyncServiceDelegate) : SyncSubService(delegate) {

    override suspend fun execute() = coroutineScope {
        ensureActive()

        // get all starred story hashes from remote db
        val starredHashesResponse = apiManager.starredStoryHashes

        ensureActive()

        // get all starred story hashes from local db
        val localStoryHashes = dbHelper.starredStoryHashes

        ensureActive()

        val newStarredHashes = starredHashesResponse.starredStoryHashes.minus(localStoryHashes)
        val invalidStarredHashes = localStoryHashes.minus(starredHashesResponse.starredStoryHashes)

        if (newStarredHashes.isNotEmpty()) {
            dbHelper.markStoryHashesStarred(newStarredHashes, true)
        }
        if (invalidStarredHashes.isNotEmpty()) {
            dbHelper.markStoryHashesStarred(invalidStarredHashes, false)
        }
    }
}