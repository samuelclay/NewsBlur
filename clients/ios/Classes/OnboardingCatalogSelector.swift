// OnboardingCatalogSelector.swift shares onboarding quality rules with the catalog audit CLI.
import Foundation
import NaturalLanguage
import ImageIO
import CoreGraphics

enum OnboardingCatalogSelector {
    struct Selection {
        var feeds: [[String: Any]]
        var icons: [[String: Any]]
        var rejected: [String: Int]
    }

    private static let aliases = [
        "cooking & food": "food & cooking", "art & design": "design",
        "automobiles": "automotive", "fitness & health": "health & fitness",
        "news & current events": "news & politics", "travel & lifestyle": "travel",
        "culture & lifestyle": "lifestyle", "entertainment & comedy": "comedy & humor",
        "finance & business": "finance"
    ]
    private static let sourceOrder = ["rss", "newsletter", "youtube", "reddit", "podcast"]
    // OnboardingCatalogSelector.swift excludes catalog keyword collisions and the multilingual video feed found in the 2026-10-02 audit.
    private static let excludedFeedURLs: [String: Set<String>] = [
        "food & cooking": ["https://www.youtube.com/feeds/videos.xml?channel_id=UCR4s1DE9J4DHzZYXMltSMAg",
            "http://thebakingbird.com/feed/", "http://thebakingdba.blogspot.com/feeds/posts/default",
            "https://bakingclouds.com/feed/"],
        "agriculture": ["https://feeds.megaphone.fm/accelerateyourbusinessgrowth"],
        "anime & manga": ["https://tumblr.forgifs.com/rss", "https://feeds.feedburner.com/crunchyroll/rss/anime"],
        "books & reading": ["https://devblogs.microsoft.com/oldnewthing/author/oldnewthing/feed",
            "https://techcrunch.com/author/zack-whittaker/feed/", "https://reason.com/people/jim-epstein/feed/atom/"],
        "education": ["https://www.thehindu.com/?service=rss", "https://aella.substack.com/feed",
            "https://ryanmcbeth.substack.com/feed"],
        "film & television": ["https://www.youtube.com/feeds/videos.xml?channel_id=UC_x5XG1OV2P6uZZ5FSM9Ttw"],
        "gaming": ["https://techcrunch.com/feed/"],
        "economics": ["https://www.youtube.com/feeds/videos.xml?channel_id=UCr3cBLTYmIK9kY0F_OdFWFQ"],
        "automotive": ["https://www.sciencedaily.com/rss/matter_energy/automotive_and_transportation.xml"],
        "business": ["https://feeds.feedburner.com/time/business",
            "http://www.bbc.co.uk/programmes/p002vsxs/episodes/downloads.rss"],
        "comedy & humor": ["https://feeds.megaphone.fm/jokermenpod"],
        "fashion & beauty": ["https://www.youtube.com/feeds/videos.xml?channel_id=UCFWK-5uho_CvKKdwcuHNo1g",
            "https://www.reddit.com/r/amIuglyBrutallyHonest/.rss"],
        "health & fitness": ["https://www.precisionnutrition.com/blog/feed"],
        "internet culture & social media": [
            "https://www.youtube.com/feeds/videos.xml?channel_id=UC3NaOy_DAFPLMzNhXQ3PWZA",
            "https://www.youtube.com/feeds/videos.xml?channel_id=UCzdnmHHR7fNHtoVLolDg6_g",
            "https://www.microsoft.com/en-us/power-platform/blog/product/power-apps/feed/",
            "https://platformengineering.org/blog/rss.xml", "https://pnp.github.io/blog/index.xml"],
        "lifestyle": ["http://feeds2.feedburner.com/LifestylesUnlimited"],
        "military & defense": ["https://www.reddit.com/r/netsec/.rss"],
        "parenting": ["https://feeds.feedburner.com/TheArtfulParent"],
        "pets & animals": ["https://arsenalyouth.wordpress.com/feed/", "https://eatlittlebird.com/feed/",
                           "http://feeds.feedburner.com/BirdsOnTheBlog", "http://birdsoftheair.blogspot.com/feeds/posts/default"],
        "religion & spirituality": ["https://christianselig.com/index.xml", "https://rss.csmonitor.com/feeds/science",
            "https://rss.csmonitor.com/feeds/environment", "https://rss.csmonitor.com/feeds/arts"],
        "photography": ["https://feeds.simplecast.com/tIivNLb5", "https://medium.com/feed/adventures-in-consumer-technology"],
        "science": ["https://reactormag.com/feed/", "https://www.spreaker.com/show/6180443/episodes/feed"],
        "productivity & organization": ["https://aws.amazon.com/blogs/infrastructure-and-automation/feed/",
            "https://automationpanda.com/feed/", "https://www.ontestautomation.com/feed.xml",
            "https://responsibleautomation.wordpress.com/feed/", "https://automationchampion.com/feed/",
            "http://roboticsandautomationnews.com/feed/",
            "https://www.automationworld.com/__rss/website-scheduled-content.xml?input=%7B%22sectionAlias%22:%22home%22%7D"],
        "psychology & mental health": ["https://www.reddit.com/r/ThinkingProcess/.rss"],
        "relationships & dating": ["http://thevisualcommunicationguy.com/feed/",
            "http://www.timetoshinepodcast.com/feed/podcast/", "https://www.reddit.com/r/PublicSpeaking/.rss",
            "https://www.reddit.com/r/Toastmasters/.rss"],
        "wellness & self-care": ["https://meditations-in-an-emergency.ghost.io/rss/"]
    ]

    static func canonicalInterest(_ interest: String) -> String {
        aliases[interest.lowercased()] ?? interest
    }

    static func canonicalInterests(_ interests: [String]) -> [String] {
        Array(Set(interests.map(canonicalInterest))).sorted {
            displayTitle($0).localizedStandardCompare(displayTitle($1)) == .orderedAscending
        }
    }

    static func displayTitle(_ interest: String) -> String {
        canonicalInterest(interest).lowercased() == "food & cooking" ? "Cooking & Food" : interest.localizedCapitalized
    }

    static func categoryAliases(for interest: String) -> [String] {
        let canonical = canonicalInterest(interest)
        return [canonical] + aliases.filter { $0.value == canonical.lowercased() }.keys.sorted()
    }

    static func address(_ entry: [String: Any]) -> String {
        let feed = entry["feed"] as? [String: Any] ?? [:]
        return (feed["feed_address"] as? String ?? entry["feed_address"] as? String ?? entry["feed_url"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func favicon(_ entry: [String: Any]) -> String? {
        (entry["feed"] as? [String: Any])?["favicon"] as? String ?? entry["favicon"] as? String
    }

    static func hasEnglishStories(_ entry: [String: Any]) -> Bool {
        let titles = (entry["stories"] as? [[String: Any]] ?? []).compactMap { $0["story_title"] as? String }
            .map { $0.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression) }
            .filter { $0.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count >= 8 }
        guard titles.count >= 3 else { return false }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(titles.joined(separator: ". "))
        guard recognizer.dominantLanguage == .english,
              (recognizer.languageHypotheses(withMaximum: 1)[.english] ?? 0) >= 0.6 else { return false }
        for title in titles where title.split(separator: " ").count >= 4 {
            recognizer.reset()
            recognizer.processString(title)
            if let language = recognizer.dominantLanguage, language != .english,
               (recognizer.languageHypotheses(withMaximum: 1)[language] ?? 0) >= 0.7 { return false }
        }
        return true
    }

    static func iconFingerprint(_ base64: String) -> String? {
        let encoded = base64.hasPrefix("data:") ? String(base64.split(separator: ",", maxSplits: 1).last ?? "") : base64
        guard let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 32,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary), image.width >= 8, image.height >= 8 else { return nil }
        var pixels = [UInt8](repeating: 0, count: 32 * 32 * 4)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 32, height: 32,
                                          bitsPerComponent: 8, bytesPerRow: 128,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: 32, height: 32))
            return true
        }
        guard rendered else { return nil }
        var colors: Set<UInt16> = []
        var opaquePixels = 0
        var fingerprint: UInt64 = 14_695_981_039_346_656_037
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[offset + 3] > 32 {
                opaquePixels += 1
                colors.insert(UInt16(pixels[offset] >> 4) << 8 | UInt16(pixels[offset + 1] >> 4) << 4 | UInt16(pixels[offset + 2] >> 4))
            }
            for value in pixels[offset..<(offset + 4)] {
                fingerprint = (fingerprint ^ UInt64(value >> 3)) &* 1_099_511_628_211
            }
        }
        guard opaquePixels >= 32, colors.count >= 2 else { return nil }
        return String(fingerprint, radix: 16)
    }

    static func hasRecentStories(_ entry: [String: Any], now: Date = Date()) -> Bool {
        let feed = entry["feed"] as? [String: Any] ?? entry
        let values = [feed["last_story_date"], entry["last_story_date"]] +
            (entry["stories"] as? [[String: Any]] ?? []).map { $0["story_date"] }
        let dates = values.compactMap { value -> Date? in
            if let number = value as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
            guard let text = value as? String else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: text) ?? formatter.date(from: text.replacingOccurrences(of: " ", with: "T") + "Z")
        }
        guard let latest = dates.max() else { return false }
        return now.timeIntervalSince(latest) <= 365 * 86_400 && latest.timeIntervalSince(now) <= 86_400
    }

    static func select(_ entries: [[String: Any]], limit: Int = 15, interest: String? = nil, now: Date = Date()) -> Selection {
        struct Candidate {
            var entry: [String: Any]
            var source: String
            var icon: String
            var popularity: Double
            var order: Int
        }
        var candidates: [Candidate] = []
        var seen: Set<String> = []
        var rejected: [String: Int] = [:]
        var fingerprints: [String: String] = [:]
        var invalidIcons: Set<String> = []
        func fingerprint(_ encoded: String?) -> String? {
            guard let encoded, !invalidIcons.contains(encoded) else { return nil }
            if let cached = fingerprints[encoded] { return cached }
            guard let value = iconFingerprint(encoded) else { invalidIcons.insert(encoded); return nil }
            fingerprints[encoded] = value
            return value
        }
        for (index, entry) in entries.enumerated() {
            let url = address(entry)
            if seen.contains(url) { continue }
            let feed = entry["feed"] as? [String: Any] ?? [:]
            let reason: String?
            let icon = fingerprint(favicon(entry))
            if url.isEmpty { reason = "missing_url" }
            else if excludedFeedURLs[interest.map(canonicalInterest)?.lowercased() ?? ""]?.contains(url) == true { reason = "unrelated_to_interest" }
            else if feed["has_feed_exception"] as? Bool == true ||
                (feed["has_exception"] as? Bool == true && feed["exception_type"] as? String == "feed") { reason = "feed_error" }
            else if !hasRecentStories(entry, now: now) { reason = "missing_or_stale_stories" }
            else if !hasEnglishStories(entry) { reason = "non_english_or_missing_stories" }
            else if icon == nil { reason = "missing_or_default_icon" }
            else { reason = nil }
            if let reason { rejected[reason, default: 0] += 1; continue }
            guard seen.insert(url).inserted, let icon else { continue }
            let source = entry["feed_type"] as? String ?? "rss"
            let readership = feed["num_subscribers"] as? NSNumber ?? entry["num_subscribers"] as? NSNumber
            let external = entry["subscriber_count"] as? NSNumber ?? entry["subscribers"] as? NSNumber
            let popularity = source == "rss" || source == "newsletter" ? readership ?? external : external ?? readership
            candidates.append(Candidate(entry: entry, source: source, icon: icon, popularity: popularity?.doubleValue ?? 0, order: index))
        }
        candidates.sort { $0.popularity == $1.popularity ? $0.order < $1.order : $0.popularity > $1.popularity }
        let order = sourceOrder + Set(candidates.map(\.source)).subtracting(sourceOrder).sorted()
        var selected: [Candidate] = []
        var selectedURLs: Set<String> = []
        var selectedIcons: Set<String> = []
        // OnboardingCatalogSelector.swift first fills five distinct icons, then fills the bundle without starving a single-source interest.
        while selected.count < min(5, limit) {
            var progressed = false
            for source in order where selected.count < min(5, limit) {
                guard let candidate = candidates.first(where: {
                    $0.source == source && !selectedURLs.contains(address($0.entry)) && !selectedIcons.contains($0.icon)
                }) else { continue }
                selected.append(candidate)
                selectedURLs.insert(address(candidate.entry))
                selectedIcons.insert(candidate.icon)
                progressed = true
            }
            if !progressed { break }
        }
        let icons = selected.map(\.entry)
        while selected.count < limit {
            var progressed = false
            for source in order where selected.count < limit {
                guard let candidate = candidates.first(where: { $0.source == source && !selectedURLs.contains(address($0.entry)) }) else { continue }
                selected.append(candidate)
                selectedURLs.insert(address(candidate.entry))
                progressed = true
            }
            if !progressed { break }
        }
        return Selection(feeds: selected.map(\.entry), icons: icons, rejected: rejected)
    }
}
