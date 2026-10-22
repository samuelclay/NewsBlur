// WidgetConfiguration.swift exposes one folder or site per widget in the system editor.
import AppIntents
import Foundation

struct NewsBlurWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "NewsBlur"
    static var description = IntentDescription(LocalizedStringResource("Choose a folder or site for this widget."))

    @Parameter(title: LocalizedStringResource("Folder or site"))
    var source: WidgetSourceEntity?

    static var parameterSummary: some ParameterSummary {
        Summary { \.$source }
    }
}

struct WidgetSourceEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Folder or site"))
    static var defaultQuery = WidgetSourceQuery()
    let id: String
    let name: String
    var favicon: Data? = nil

    var displayRepresentation: DisplayRepresentation {
        if id == "all" { return DisplayRepresentation(title: LocalizedStringResource("All Site Stories")) }
        if let favicon { return DisplayRepresentation(title: "\(name)", image: .init(data: favicon, isTemplate: false)) }
        return DisplayRepresentation(title: "\(name)", image: .init(systemName: id.hasPrefix("folder:") ? "folder" : "dot.radiowaves.left.and.right"))
    }
    static let all = WidgetSourceEntity(id: "all", name: "")
}

struct WidgetSourceQuery: EntityStringQuery {
    typealias Result = IntentItemCollection<WidgetSourceEntity>

    func entities(for identifiers: [String]) async throws -> [WidgetSourceEntity] {
        let catalog = WidgetSourceCatalog.load()
        return identifiers.map { id in
            if id == "all" { return .all }
            let name = id.hasPrefix("folder:") ? String(id.dropFirst(7)) :
                catalog.feeds[String(id.dropFirst(5))]?["feed_title"] as? String ?? String(id.dropFirst(5))
            // WidgetConfiguration.swift retains deleted selections so they never silently become All Stories.
            return WidgetSourceEntity(id: id, name: name, favicon: id.hasPrefix("feed:") ? catalog.favicon(for: String(id.dropFirst(5))) : nil)
        }
    }

    func defaultResult() async -> WidgetSourceEntity? { .all }

    func suggestedEntities() async throws -> Result {
        let catalog = await WidgetSourceCatalog.loadForPicker(defaults: UserDefaults(suiteName: WidgetSourceCatalog.group)) {
            await WidgetSourceCatalog.refresh(includeFavicons: false)
        }
        return collection(catalog: catalog)
    }
    func entities(matching string: String) async throws -> Result {
        let catalog = await WidgetSourceCatalog.loadForPicker(defaults: UserDefaults(suiteName: WidgetSourceCatalog.group)) {
            await WidgetSourceCatalog.refresh(includeFavicons: false)
        }
        return collection(catalog: catalog, matching: string)
    }

    private func collection(catalog: WidgetSourceCatalog, matching search: String = "") -> Result {
        let folders = catalog.folders.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { WidgetSourceEntity(id: "folder:" + $0, name: $0) }
        let sites = catalog.feeds.map { WidgetSourceEntity(id: "feed:" + $0.key, name: $0.value["feed_title"] as? String ?? $0.key, favicon: catalog.favicon(for: $0.key)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let matches: (WidgetSourceEntity) -> Bool = { search.isEmpty || $0.name.localizedStandardContains(search) }
        return Result(sections: [
            IntentItemSection(items: [IntentItem(.all)]),
            IntentItemSection(LocalizedStringResource("Folders"), items: folders.filter(matches)),
            IntentItemSection(LocalizedStringResource("Sites"), items: sites.filter(matches))
        ])
    }
}
