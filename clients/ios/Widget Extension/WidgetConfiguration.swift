// WidgetConfiguration.swift exposes one folder or site per widget in the system editor.
import AppIntents
import Foundation

private extension WidgetStorySource {
    var pickerTitle: LocalizedStringResource {
        switch self {
        case .infrequent: return LocalizedStringResource("Infrequent Site Stories")
        case .widelyRead: return LocalizedStringResource("Widely Read Stories")
        case .longReads: return LocalizedStringResource("Long Reads")
        case .goodReads: return LocalizedStringResource("Good Reads")
        }
    }
}

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
        if let title = builtInTitle { return DisplayRepresentation(title: title) }
        if let favicon { return DisplayRepresentation(title: "\(name)", image: .init(data: favicon, isTemplate: false)) }
        return DisplayRepresentation(title: "\(name)", image: .init(systemName: id.hasPrefix("folder:") ? "folder" : "dot.radiowaves.left.and.right"))
    }

    var builtInTitle: LocalizedStringResource? {
        id == "all" ? LocalizedStringResource("All Site Stories") : WidgetStorySource(rawValue: id)?.pickerTitle
    }

    static let all = WidgetSourceEntity(id: "all", name: "")
    static let builtIns = [all] + WidgetStorySource.allCases.map { WidgetSourceEntity(id: $0.rawValue, name: "") }
}

struct WidgetSourceQuery: EntityStringQuery {
    typealias Result = IntentItemCollection<WidgetSourceEntity>

    func entities(for identifiers: [String]) async throws -> [WidgetSourceEntity] {
        lazy var catalog = WidgetSourceCatalog.load()
        return identifiers.map { id in
            if let builtIn = WidgetSourceEntity.builtIns.first(where: { $0.id == id }) { return builtIn }
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
        let matches: (String) -> Bool = { search.isEmpty || $0.localizedStandardContains(search) }
        let builtIns = WidgetSourceEntity.builtIns.filter {
            $0.builtInTitle.map { matches(String(localized: $0)) } ?? false
        }
        let folders = catalog.folders.keys.filter(matches).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { WidgetSourceEntity(id: "folder:" + $0, name: $0) }
        let sites = catalog.pickerSites(matching: search).map {
            WidgetSourceEntity(id: "feed:" + $0.id, name: $0.name, favicon: $0.favicon)
        }
        return Result(sections: [
            IntentItemSection(items: builtIns.map { IntentItem($0) }),
            IntentItemSection(LocalizedStringResource("Folders"), items: folders),
            IntentItemSection(LocalizedStringResource("Sites"), items: sites)
        ])
    }
}
