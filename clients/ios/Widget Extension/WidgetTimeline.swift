import Foundation
import WidgetKit

enum WidgetTimeline {
    static func make<Entry: TimelineEntry>(
        at date: Date = Date(),
        entry: (Date) -> Entry
    ) -> Timeline<Entry> {
        // WidgetExtension.swift fetches once per timeline. Future copies would only repeat stale stories.
        // WidgetKit decides when to honor this refresh request based on visibility and its update budget.
        return Timeline(entries: [entry(date)], policy: .after(date.addingTimeInterval(15 * 60)))
    }
}
