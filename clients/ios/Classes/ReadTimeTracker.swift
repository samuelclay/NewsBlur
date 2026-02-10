// ReadTimeTracker.swift - Tracks active reading time for stories
//
// Adapted from media/js/newsblur/common/read_time_tracker.js for iOS.
// Uses a "grace period" approach: scrolling/tapping grants a 2-minute window
// where we assume the user is still reading. If no activity for 2+ minutes,
// we stop accumulating (but keep earned time, unlike web which deletes it).

import UIKit

@objcMembers
class ReadTimeTracker: NSObject {
    static let shared = ReadTimeTracker()

    private static let idleThresholdSeconds: TimeInterval = 120 // 2 minutes
    private static let tickInterval: TimeInterval = 1.0

    private(set) var currentStoryHash: String?
    private var readTimes: [String: Int] = [:]
    private var queuedReadTimes: [String: Int] = [:]
    private var lastActivity: Date = Date()
    private var timer: Timer?
    private var isAppActive: Bool = true

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    // MARK: - Tracking

    func startTracking(storyHash: String) {
        guard !storyHash.isEmpty else { return }
        stopTracking()

        currentStoryHash = storyHash
        lastActivity = Date()

        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
        currentStoryHash = nil
    }

    func getAndResetReadTime(storyHash: String) -> Int {
        guard !storyHash.isEmpty else { return 0 }
        return readTimes.removeValue(forKey: storyHash) ?? 0
    }

    func recordActivity() {
        lastActivity = Date()
    }

    // MARK: - Queue

    func queueReadTime(storyHash: String, seconds: Int) {
        guard seconds > 0 else { return }
        queuedReadTimes[storyHash, default: 0] += seconds
    }

    func consumeQueuedReadTimesJSON() -> String? {
        guard !queuedReadTimes.isEmpty else { return nil }
        let timesToSend = queuedReadTimes
        queuedReadTimes.removeAll()

        guard let data = try? JSONSerialization.data(withJSONObject: timesToSend),
              let json = String(data: data, encoding: .utf8) else {
            for (hash, secs) in timesToSend {
                queuedReadTimes[hash, default: 0] += secs
            }
            return nil
        }
        return json
    }

    func restoreQueuedReadTimes(json: String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        for (hash, value) in dict {
            if let secs = value as? Int {
                queuedReadTimes[hash, default: 0] += secs
            } else if let secs = value as? NSNumber {
                queuedReadTimes[hash, default: 0] += secs.intValue
            }
        }
    }

    // MARK: - Flush

    func harvestAndFlush() {
        if let hash = currentStoryHash {
            let seconds = getAndResetReadTime(storyHash: hash)
            if seconds > 0 {
                queueReadTime(storyHash: hash, seconds: seconds)
            }
        }
        stopTracking()
        flushReadTimes()
    }

    func flushReadTimes() {
        guard let json = consumeQueuedReadTimesJSON(),
              let appDelegate = NewsBlurAppDelegate.shared else {
            return
        }

        let urlString = "\(appDelegate.url ?? "")/reader/mark_story_hashes_as_read"
        let params: [String: Any] = ["read_times": json]

        appDelegate.post(urlString, parameters: params, success: { _, _ in
        }, failure: { [weak self] _, _ in
            self?.restoreQueuedReadTimes(json: json)
        })
    }

    // MARK: - Private

    private func tick() {
        guard let hash = currentStoryHash else { return }
        guard isAppActive else { return }

        let idleTime = Date().timeIntervalSince(lastActivity)
        if idleTime < Self.idleThresholdSeconds {
            readTimes[hash, default: 0] += 1
        }
    }

    @objc private func appDidBecomeActive() {
        isAppActive = true
        recordActivity()
    }

    @objc private func appWillResignActive() {
        isAppActive = false
    }
}
