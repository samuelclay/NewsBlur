import Foundation

@objc final class OfflineCacheCleanup: NSObject {
    // OfflineSyncUnreads.m calls this inside its transaction, after replacing the unread hashes.
    @objc(pruneDatabase:limit:oldestFirst:)
    static func pruneDatabase(_ database: FMDatabase, limit: Int, oldestFirst: Bool) -> Bool {
        let limit = max(0, limit)
        let order = oldestFirst ? "ASC" : "DESC"
        let statements = [
            "DROP TABLE IF EXISTS temp.offline_retained_hashes",
            "CREATE TEMP TABLE offline_retained_hashes (story_hash TEXT PRIMARY KEY)",
            "INSERT INTO offline_retained_hashes SELECT story_hash FROM unread_hashes ORDER BY story_timestamp \(order), story_hash ASC LIMIT \(limit)",
            // OfflineCacheCleanup.swift reserves capacity for unread stories that have not downloaded yet.
            "INSERT OR IGNORE INTO offline_retained_hashes SELECT s.story_hash FROM stories s WHERE NOT EXISTS (SELECT 1 FROM unread_hashes u WHERE u.story_hash = s.story_hash) ORDER BY s.story_timestamp DESC, s.story_hash ASC LIMIT MAX(0, \(limit) - (SELECT COUNT(*) FROM offline_retained_hashes))",
            "DELETE FROM stories WHERE story_hash NOT IN (SELECT story_hash FROM offline_retained_hashes)",
            "DELETE FROM unread_hashes WHERE story_hash NOT IN (SELECT story_hash FROM offline_retained_hashes)",
            "DELETE FROM cached_text WHERE NOT EXISTS (SELECT 1 FROM stories s WHERE s.story_hash = cached_text.story_hash)",
            "DELETE FROM cached_images WHERE NOT EXISTS (SELECT 1 FROM stories s WHERE s.story_hash = cached_images.story_hash)",
            "DELETE FROM story_scrolls WHERE NOT EXISTS (SELECT 1 FROM stories s WHERE s.story_hash = story_scrolls.story_hash)",
            "DROP TABLE temp.offline_retained_hashes"
        ]
        return statements.allSatisfy { database.executeUpdate($0, withArgumentsIn: []) }
    }

    @objc(clearDatabase:)
    static func clearDatabase(_ database: FMDatabase) -> Bool {
        // OfflineCacheCleanup.swift preserves accounts and queued read/saved changes during a manual purge.
        ["stories", "unread_hashes", "cached_text", "cached_images", "story_scrolls"].allSatisfy {
            database.executeUpdate("DELETE FROM \($0)", withArgumentsIn: [])
        }
    }

    @objc(compactDatabase:force:)
    static func compactDatabase(_ database: FMDatabase, force: Bool) -> Bool {
        if !force {
            func pragma(_ name: String) -> Int {
                guard let result = database.executeQuery("PRAGMA \(name)", withArgumentsIn: []) else { return 0 }
                defer { result.close() }
                return result.next() ? Int(result.longLongInt(forColumnIndex: 0)) : 0
            }
            let free = pragma("freelist_count")
            let pages = pragma("page_count")
            let pageSize = pragma("page_size")
            // OfflineCacheCleanup.swift avoids rewriting the database for a few reclaimed pages on every sync.
            guard free * pageSize >= 1_024 * 1_024, free >= pages / 4 else { return true }
        }
        guard database.executeUpdate("VACUUM", withArgumentsIn: []) else { return false }
        guard let checkpoint = database.executeQuery("PRAGMA wal_checkpoint(TRUNCATE)", withArgumentsIn: []) else { return false }
        defer { checkpoint.close() }
        return checkpoint.next() && checkpoint.int(forColumnIndex: 0) == 0
    }

    @objc(removeUnreferencedImagesWithDatabase:directory:)
    static func removeUnreferencedImages(database: FMDatabase, directory: URL) -> Bool {
        guard let images = database.executeQuery("SELECT DISTINCT image_url FROM cached_images", withArgumentsIn: []) else { return false }
        var retained = Set<String>()
        while images.next() {
            if let url = images.string(forColumn: "image_url"), let hash = Utilities.md5(url) {
                retained.insert(hash + ".jpeg")
            }
        }
        images.close()
        let manager = FileManager.default
        guard manager.fileExists(atPath: directory.path) else { return true }
        do {
            // OfflineFetchImages.m names files by URL, so a retained story can share an evicted story's image.
            for file in try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where !retained.contains(file.lastPathComponent) {
                try manager.removeItem(at: file)
            }
            return true
        } catch {
            NSLog("OfflineCacheCleanup.swift could not remove unused story images: %@", error.localizedDescription)
            return false
        }
    }
}
