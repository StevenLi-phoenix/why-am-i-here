import Foundation
import SwiftData

/// SwiftData-backed log of pickups. All access happens on the main actor.
@MainActor
public final class PickupStore {
    public let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration("Pickups", isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: Pickup.self, configurations: configuration)
        Log.store.info("store opened inMemory=\(inMemory)")
    }

    public func insert(_ pickup: Pickup) {
        context.insert(pickup)
        save()
    }

    public func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Log.store.error("save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func pickup(id: UUID) -> Pickup? {
        var descriptor = FetchDescriptor<Pickup>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    /// Pickups opened in `[interval.start, interval.end)`, oldest first.
    public func pickups(in interval: DateInterval) -> [Pickup] {
        let start = interval.start, end = interval.end
        let descriptor = FetchDescriptor<Pickup>(
            predicate: #Predicate { $0.openedAt >= start && $0.openedAt < end },
            sortBy: [SortDescriptor(\.openedAt)])
        return fetch(descriptor)
    }

    public func records(in interval: DateInterval) -> [PickupRecord] {
        pickups(in: interval).map(\.record)
    }

    public func count(appID: String, in interval: DateInterval) -> Int {
        let start = interval.start, end = interval.end
        let descriptor = FetchDescriptor<Pickup>(
            predicate: #Predicate { $0.appID == appID && $0.openedAt >= start && $0.openedAt < end })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    public func count(in interval: DateInterval) -> Int {
        let start = interval.start, end = interval.end
        let descriptor = FetchDescriptor<Pickup>(predicate: #Predicate { $0.openedAt >= start && $0.openedAt < end })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    public var totalCount: Int {
        (try? context.fetchCount(FetchDescriptor<Pickup>())) ?? 0
    }

    /// Sessions that started and have not ended, newest first.
    public func activeSessions(appID: String? = nil) -> [Pickup] {
        let descriptor = FetchDescriptor<Pickup>(
            predicate: #Predicate { $0.sessionStart != nil && $0.sessionEnd == nil },
            sortBy: [SortDescriptor(\.openedAt, order: .reverse)])
        let all = fetch(descriptor)
        guard let appID else { return all }
        return all.filter { $0.appID == appID }
    }

    /// Most recent pickup of `appID` opened before `date`.
    public func lastPickup(appID: String, before date: Date) -> Pickup? {
        var descriptor = FetchDescriptor<Pickup>(
            predicate: #Predicate { $0.appID == appID && $0.openedAt < date },
            sortBy: [SortDescriptor(\.openedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    /// Most recent pickup that has an answer, a skip or a "Never Mind".
    public func lastCheckIn() -> Pickup? {
        let changedMind: String? = SessionEnd.changedMind.rawValue
        var descriptor = FetchDescriptor<Pickup>(
            predicate: #Predicate { $0.reasonRaw != nil || $0.skipped || $0.endedByRaw == changedMind },
            sortBy: [SortDescriptor(\.openedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    public func deleteAll() {
        do {
            try context.delete(model: Pickup.self)
            try context.save()
            Log.store.notice("all pickups deleted")
        } catch {
            Log.store.error("deleteAll failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fetch(_ descriptor: FetchDescriptor<Pickup>) -> [Pickup] {
        do {
            return try context.fetch(descriptor)
        } catch {
            Log.store.error("fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
