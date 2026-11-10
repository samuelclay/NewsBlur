import Foundation

struct WidgetStoryPagination<Entry: Identifiable> {
    enum Result {
        case nextPage
        case complete
        case pageLimit
    }

    let limit: Int
    let maximumPages: Int
    private(set) var page = 1
    private(set) var stories: [Entry] = []
    private var identifiers = Set<Entry.ID>()

    init(limit: Int, maximumPages: Int = 10) {
        self.limit = limit
        self.maximumPages = maximumPages
    }

    mutating func append(_ entries: [Entry], hiddenCount: Int) -> Result {
        for entry in entries where stories.count < limit {
            if identifiers.insert(entry.id).inserted { stories.append(entry) }
        }
        // WidgetCache.swift receives pages filtered after their limit is applied on the server.
        // WidgetStoryPagination.swift must scan past hidden stories before declaring the river empty.
        if stories.count == limit || (hiddenCount == 0 && entries.count < limit) { return .complete }
        guard page < maximumPages else { return .pageLimit }
        page += 1
        return .nextPage
    }

    func resolvedStories(cached: [Entry], reachedEnd: Bool) -> [Entry] {
        // WidgetCache.swift keeps cached stories if a timeout, page cap, or network error prevents a full scan.
        !stories.isEmpty || reachedEnd ? stories : cached
    }
}
