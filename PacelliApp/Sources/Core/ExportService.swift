import Foundation
import PacelliKit

/// Builds the user-facing JSON backup (Settings → Export data).
///
/// Format: one versioned envelope; entities are their decrypted Dart-wire
/// maps (`toMap()` — flat snake_case, ISO-8601 string dates), nested only
/// where the UI nests them (subtasks under tasks, items under checklists,
/// entries under plans). `schema_version` 2 is the contract the future
/// importer reads — bump on any breaking change, never mutate silently.
///
/// **Version 2 carries the photos.** A household with pictures exports as a
/// zip — `pacelli-export.json` plus a `photos/` folder of readable JPEGs — and
/// a household without them still exports as the single JSON file it always
/// did. There is one Export button and it does the right thing; an export that
/// silently omitted your photos would be worse than no export at all.
///
/// The file is intentionally PLAINTEXT: it is the user's own readable
/// backup of their own data, generated on-device from already-decrypted
/// models and handed straight to the iOS share sheet. Nothing here talks
/// to the network beyond the existing repository fetches, and nothing is
/// written outside the app's tmp directory. The UI warns before export
/// (pacelli-security-audit §export).
enum ExportService {
    static let schemaVersion = 2

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

        let stamp = fileDateStamp(now)
        let photos = (try? await PhotosRepository.fetchAll(householdId: householdId)) ?? []

        var envelopeWithPhotos = envelope
        envelopeWithPhotos["photos"] = photos.map { photo -> [String: Any] in
            [
                "id": photo.id,
                "file": "photos/\(photo.id).jpg",
                "subject_type": photo.subjectType.rawValue,
                "subject_id": photo.subjectId,
                "category_id": photo.categoryId ?? NSNull(),
                "caption": photo.caption ?? NSNull(),
                "recognised_text": photo.recognisedText ?? NSNull(),
                "labels": photo.labels ?? NSNull(),
                "created_by": photo.createdBy,
                "created_at": DartISO8601.string(from: photo.createdAt),
                "upload_state": photo.uploadState.rawValue,
            ]
        }

        guard !photos.isEmpty else {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Pacelli export \(stamp).json")
            try json(envelopeWithPhotos).write(to: url, options: .atomic)
            return url
        }

        return try await zipped(
            envelope: envelopeWithPhotos, photos: photos,
            householdId: householdId, stamp: stamp)
    }

    private static func json(_ envelope: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    /// Builds `Pacelli export <date>/` and zips it.
    ///
    /// Photos that are not on this device are fetched and decrypted on the way
    /// — an export is a backup, and a backup that only contains the pictures
    /// this particular phone happens to be caching is not one. A photo whose
    /// full size was never uploaded (`pending`, `stranded`) has nothing to
    /// fetch; the JSON still lists it, with its state, so the file explains its
    /// own gaps rather than pretending there are none.
    private static func zipped(
        envelope: [String: Any], photos: [Photo],
        householdId: String, stamp: String
    ) async throws -> URL {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory
            .appendingPathComponent("Pacelli export \(stamp)", isDirectory: true)
        try? fm.removeItem(at: folder)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let photosDir = folder.appendingPathComponent("photos", isDirectory: true)
        try fm.createDirectory(at: photosDir, withIntermediateDirectories: true)

        var written = 0
        for photo in photos where photo.uploadState == .ready {
            guard let jpeg = try? await PhotoService.fullImage(
                photoId: photo.id, householdId: householdId)
            else { continue }
            try? jpeg.write(
                to: photosDir.appendingPathComponent("\(photo.id).jpg"), options: .atomic)
            written += 1
        }

        var envelope = envelope
        envelope["photos_included"] = written
        try json(envelope).write(
            to: folder.appendingPathComponent("pacelli-export.json"), options: .atomic)

        // Zipping without a dependency: NSFileCoordinator's `.forUploading`
        // hands back a zip of the directory. The URL it provides is valid only
        // inside the block, so the copy happens there.
        let destination = fm.temporaryDirectory
            .appendingPathComponent("Pacelli export \(stamp).zip")
        try? fm.removeItem(at: destination)

        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: folder, options: [.forUploading], error: &coordinatorError
        ) { zipURL in
            do {
                try fm.copyItem(at: zipURL, to: destination)
            } catch {
                copyError = error
            }
        }
        try? fm.removeItem(at: folder)

        if let coordinatorError { throw coordinatorError }
        if let copyError { throw copyError }
        return destination
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
