import Foundation
import PacelliKit

/// Builds the user-facing JSON backup (Settings → Export data).
///
/// Format: one versioned envelope; entities are their decrypted Dart-wire
/// maps (`toMap()` — flat snake_case, ISO-8601 string dates), nested only
/// where the UI nests them (subtasks under tasks, items under checklists,
/// entries under plans). `schema_version` 1 is the contract the future
/// importer reads — bump on any breaking change, never mutate silently.
///
/// The file is intentionally PLAINTEXT: it is the user's own readable
/// backup of their own data, generated on-device from already-decrypted
/// models and handed straight to the iOS share sheet. Nothing here talks
/// to the network beyond the existing repository fetches, and nothing is
/// written outside the app's tmp directory. The UI warns before export
/// (pacelli-security-audit §export).
enum ExportService {
    static let schemaVersion = 1

    /// Gathers every household entity, writes a pretty-printed JSON file
    /// to the app's temporary directory, and returns its URL for sharing.
    static func exportFile(for current: CurrentHousehold) async throws -> URL {
        let householdId = current.household.id

        async let tasksFetch = TasksRepository.fetchTasks(householdId: householdId)
        async let subtasksFetch = SubtasksRepository.fetchSubtasksByTask(
            householdId: householdId)
        async let categoriesFetch = CategoriesRepository.fetchCategories(
            householdId: householdId)
        async let checklistsFetch = ChecklistsRepository.fetchChecklists(
            householdId: householdId)
        async let plansFetch = PlansRepository.fetchPlans(householdId: householdId)
        async let manualFetch = ManualRepository.fetchEntries(householdId: householdId)
        async let membersFetch = MembershipService.fetchMembers(householdId: householdId)

        let (tasks, subtasksByTask, categories, checklists, plans, manual, members) =
            try await (
                tasksFetch, subtasksFetch, categoriesFetch, checklistsFetch,
                plansFetch, manualFetch, membersFetch
            )

        let now = Date()
        let bundle = Bundle.main
        let appVersion = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

        let envelope: [String: Any] = [
            "format": "pacelli-export",
            "schema_version": schemaVersion,
            "app_version": "\(appVersion) (\(build))",
            "exported_at": DartISO8601.string(from: now),
            "household": current.household.toMap(),
            "members": members.map { member in
                [
                    "user_id": member.userId,
                    "role": member.role,
                    "display_name": member.displayName ?? NSNull(),
                    "joined_at": member.joinedAt.map(DartISO8601.string(from:))
                        ?? NSNull(),
                ] as [String: Any]
            },
            "categories": categories.map { $0.toMap() },
            "tasks": tasks.map { task in
                var map = task.toMap()
                map["subtasks"] = (subtasksByTask[task.id] ?? []).map { $0.toMap() }
                return map
            },
            "checklists": checklists.map { checklist in
                var map = checklist.toMap()
                map["items"] = checklist.items.map { $0.toMap() }
                return map
            },
            "plans": plans.map { plan in
                var map = plan.toMap()
                map["entries"] = plan.entries.map { $0.toMap() }
                map["checklist_items"] = plan.checklistItems.map { $0.toMap() }
                return map
            },
            "manual_entries": manual.map(manualEntryMap(_:)),
        ]

        let data = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])

        let stamp = fileDateStamp(now)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pacelli export \(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// `ManualEntry` has no `toMap()` (its wire format uses Firestore
    /// Timestamps, which PacelliKit doesn't know about) — the export uses
    /// ISO strings like every other entity in the file.
    private static func manualEntryMap(_ entry: ManualEntry) -> [String: Any] {
        [
            "id": entry.id,
            "household_id": entry.householdId,
            "title": entry.title,
            "content": entry.content,
            "category_id": entry.categoryId ?? NSNull(),
            "tags": entry.tags,
            "is_pinned": entry.isPinned,
            "created_by": entry.createdBy,
            "created_at": DartISO8601.string(from: entry.createdAt),
            "updated_at": DartISO8601.string(from: entry.updatedAt),
            "last_edited_by": entry.lastEditedBy ?? NSNull(),
        ]
    }

    private static func fileDateStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
