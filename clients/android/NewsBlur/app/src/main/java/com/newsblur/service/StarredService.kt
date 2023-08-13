package com.newsblur.service

class StarredService(parent: NBSyncService) : SubService(parent) {

    companion object {
        @JvmField
        var activelyRunning = false
    }

    override fun exec() {
        activelyRunning = true

        if (parent.stopSync()) return

        // get all starred story hashes from remote db
        val starredHashesResponse = parent.apiManager.starredStoryHashes

        if (parent.stopSync()) return

        // get all starred story hashes from local db
        val localStoryHashes = parent.dbHelper.starredStoryHashes

        if (parent.stopSync()) return

        val newStarredHashes = starredHashesResponse.starredStoryHashes.minus(localStoryHashes)
        val invalidStarredHashes = localStoryHashes.minus(starredHashesResponse.starredStoryHashes)

        if (newStarredHashes.isNotEmpty()) {
            parent.dbHelper.markStoryHashesStarred(newStarredHashes, true)
        }
        if (invalidStarredHashes.isNotEmpty()) {
            parent.dbHelper.markStoryHashesStarred(invalidStarredHashes, false)
        }

        activelyRunning = false
    }
}