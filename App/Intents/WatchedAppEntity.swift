import AppIntents
import WAIHCore

/// An app from the catalog (or one the user added), as picked in a Shortcuts action.
struct WatchedAppEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "App"
    static let defaultQuery = WatchedAppQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ app: WatchedApp) {
        id = app.id
        name = app.name
    }
}

struct WatchedAppQuery: EntityStringQuery {
    /// Read straight from disk: Shortcuts may run this while the app is not on the main actor.
    private var settings: WAIHSettings { SettingsStore().load() }

    func entities(for identifiers: [String]) async throws -> [WatchedAppEntity] {
        let settings = settings
        return identifiers.compactMap { settings.app(id: $0) }.map(WatchedAppEntity.init)
    }

    /// Watched apps first, then the rest of the catalog.
    func suggestedEntities() async throws -> [WatchedAppEntity] {
        let settings = settings
        let watched = settings.watchedApps
        let others = settings.allApps.filter { !settings.isWatched($0.id) }
        return (watched + others).map(WatchedAppEntity.init)
    }

    func entities(matching string: String) async throws -> [WatchedAppEntity] {
        settings.allApps
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(WatchedAppEntity.init)
    }
}
