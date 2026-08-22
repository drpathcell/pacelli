import Foundation
import PacelliKit

/// Cross-entity search. Like the Dart implementation, search happens
/// CLIENT-SIDE after decryption — encrypted fields can't be queried on the
/// server. Reuses the feature repositories, so scope grows with the ported
/// modules (currently: tasks, subtasks, checklists+items, plans+entries,
/// manual entries).
enum SearchService {
    struct Result: Identifiable, Sendable {
        enum Kind: String {
            case task, subtask, checklist, checklistItem, plan, planEntry, manual, photo

            var displayName: String {
                switch self {
                case .task: String(localized: "Task")
                case .subtask: String(localized: "Subtask")
                case .checklist: String(localized: "Checklist")
                case .checklistItem: String(localized: "Checklist item")
                case .plan: String(localized: "Plan")
                case .planEntry: String(localized: "Plan entry")
                case .manual: String(localized: "Manual")
                case .photo: String(localized: "Photo")
                }
            }

            var systemImage: String {
                switch self {
                case .task, .subtask: "checkmark.circle"
                case .checklist, .checklistItem: "list.bullet.rectangle"
                case .plan, .planEntry: "calendar"
                case .manual: "book"
                case .photo: "photo"
                }
            }
        }

        let id: String
        let kind: Kind
        let title: String
        let subtitle: String?
    }

    /// Case-insensitive contains-match across all decrypted content.
    static func search(query: String, householdId: String) async throws -> [Result] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }

        func matches(_ text: String?) -> Bool {
            text?.localizedCaseInsensitiveContains(q) ?? false
        }

        var results: [Result] = []

        let tasks = try await TasksRepository.fetchTasks(householdId: householdId)
        for task in tasks where matches(task.title) || matches(task.description) {
            results.append(
                Result(
                    id: "task-\(task.id)", kind: .task, title: task.title,
                    subtitle: task.description))
        }
        let subtasks = try await SubtasksRepository.fetchSubtasksByTask(
            householdId: householdId)
        for (taskId, list) in subtasks {
            let parent = tasks.first { $0.id == taskId }
            for subtask in list where matches(subtask.title) {
                results.append(
                    Result(
                        id: "subtask-\(subtask.id)", kind: .subtask,
                        title: subtask.title, subtitle: parent?.title))
            }
        }

        let checklists = try await ChecklistsRepository.fetchChecklists(
            householdId: householdId)
        for checklist in checklists {
            if matches(checklist.title) {
                results.append(
                    Result(
                        id: "checklist-\(checklist.id)", kind: .checklist,
                        title: checklist.title, subtitle: nil))
            }
            for item in checklist.items where matches(item.title) {
                results.append(
                    Result(
                        id: "clitem-\(item.id)", kind: .checklistItem,
                        title: item.title, subtitle: checklist.title))
            }
        }

        let plans = try await PlansRepository.fetchPlans(householdId: householdId)
        for plan in plans {
            if matches(plan.title) {
                results.append(
                    Result(
                        id: "plan-\(plan.id)", kind: .plan, title: plan.title,
                        subtitle: nil))
            }
            for entry in plan.entries
            where matches(entry.title) || matches(entry.label)
                || matches(entry.description)
            {
                results.append(
                    Result(
                        id: "plentry-\(entry.id)", kind: .planEntry,
                        title: entry.title, subtitle: plan.title))
            }
        }

        let manualEntries = try await ManualRepository.fetchEntries(
            householdId: householdId)
        for entry in manualEntries where matches(entry.title) || matches(entry.content) {
            let preview = entry.content.isEmpty
                ? nil : String(entry.content.prefix(80))
            results.append(
                Result(
                    id: "manual-\(entry.id)", kind: .manual, title: entry.title,
                    subtitle: preview))
        }

        // Photos match on what the person typed AND on what the phone read in

        // them. The subtitle carries the recognised text rather than a generic

        // label, because a photo that surfaced for the word "boiler" is baffling

        // until you can see that the word is printed on the thing in the picture.

        let photos = (try? await PhotosRepository.fetchAll(householdId: householdId)) ?? []

        let provenance = await PhotosRepository.provenance(householdId: householdId)

        for photo in photos {

            let subjectTitle = provenance[photo.subjectId]?.title

            guard matches(photo.caption) || matches(photo.recognisedText)

                || matches(photo.labels) || matches(subjectTitle)

            else { continue }

        

            let why = [photo.caption, photo.recognisedText]

                .compactMap { $0 }

                .first { $0.localizedCaseInsensitiveContains(q) }

            results.append(

                Result(

                    id: "photo-\(photo.id)", kind: .photo,

                    title: subjectTitle ?? String(localized: "Photo"),

                    subtitle: why.map { String($0.prefix(80)) }))

        }


        return results
    }
}
