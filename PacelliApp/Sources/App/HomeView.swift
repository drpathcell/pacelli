import FirebaseAuth
import PacelliKit
import SwiftUI

/// Usable Home — the screen a guest lands on with zero walls.
/// Live task list (decrypted) with add, complete, edit (detail), delete,
/// subtask badges, and category colors.
struct HomeView: View {
    let current: CurrentHousehold
    let appState: AppState

    @State private var tasks: [HouseholdTask] = []
    @State private var subtasksByTask: [String: [Subtask]] = [:]
    @State private var categoriesById: [String: TaskCategory] = [:]
    @State private var newTitle = ""
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var showAccount = false

    private var isGuest: Bool { Auth.auth().currentUser?.isAnonymous ?? false }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                } else if tasks.isEmpty {
                    ContentUnavailableView(
                        "No tasks yet",
                        systemImage: "checklist",
                        description: Text("Add your first task below."))
                } else {
                    List {
                        ForEach($tasks) { $task in
                            row(for: $task)
                        }
                    }
                }
            }
            .navigationTitle(current.household.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAccount = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Account")
                }
            }
            .sheet(isPresented: $showAccount) {
                AccountSheet(appState: appState)
                    .presentationDetents([.medium])
            }
            .safeAreaInset(edge: .bottom) { addBar }
            .task { await reload() }
            .refreshable { await reload() }
            .alert(
                "Something went wrong", isPresented: .constant(errorMessage != nil),
                actions: { Button("OK") { errorMessage = nil } },
                message: { Text(errorMessage ?? "") })
        }
    }

    private func row(for task: Binding<HouseholdTask>) -> some View {
        HStack(spacing: 4) {
            // Dedicated toggle target ≥44pt (audit fix: circle-only was 22pt).
            Button {
                toggle(task.wrappedValue)
            } label: {
                Image(
                    systemName: task.wrappedValue.isCompleted
                        ? "checkmark.circle.fill" : "circle"
                )
                .font(.title3)
                .foregroundStyle(
                    task.wrappedValue.isCompleted ? Color.accentColor : .secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            NavigationLink {
                TaskDetailView(task: task) { remove(task.wrappedValue) }
            } label: {
                TaskRowLabel(
                    task: task.wrappedValue,
                    category: task.wrappedValue.categoryId
                        .flatMap { categoriesById[$0] },
                    subtasks: subtasksByTask[task.wrappedValue.id] ?? [])
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                delete(task.wrappedValue)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var addBar: some View {
        HStack(spacing: 12) {
            TextField("New task", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)
            Button(action: add) {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Data

    private func reload() async {
        let householdId = current.household.id
        do {
            tasks = sorted(
                try await withTimeout(15) {
                    try await TasksRepository.fetchTasks(householdId: householdId)
                })
            // Badges are non-fatal — the list must render even if these fail.
            subtasksByTask =
                (try? await withTimeout(15) {
                    try await SubtasksRepository.fetchSubtasksByTask(
                        householdId: householdId)
                }) ?? [:]
            let categories =
                (try? await withTimeout(15) {
                    try await CategoriesRepository.fetchCategories(
                        householdId: householdId)
                }) ?? []
            categoriesById = Dictionary(
                uniqueKeysWithValues: categories.map { ($0.id, $0) })
            loading = false
        } catch {
            loading = false
            errorMessage = String(localized: "Couldn't load tasks.")
        }
    }

    /// Pending first, newest first within each group.
    private func sorted(_ list: [HouseholdTask]) -> [HouseholdTask] {
        list.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            return $0.createdAt > $1.createdAt
        }
    }

    private func add() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        newTitle = ""
        Task {
            do {
                let householdId = current.household.id
                let created = try await withTimeout(15) {
                    try await TasksRepository.createTask(
                        householdId: householdId, title: title)
                }
                tasks.insert(created, at: 0)
            } catch {
                errorMessage = String(localized: "Couldn't add the task.")
            }
        }
    }

    private func toggle(_ task: HouseholdTask) {
        Task {
            do {
                let completed = !task.isCompleted
                try await withTimeout(15) {
                    try await TasksRepository.setCompleted(task, completed: completed)
                }
                if let i = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[i].status =
                        completed
                        ? HouseholdTask.Status.completed : HouseholdTask.Status.pending
                    tasks[i].completedAt = completed ? Date() : nil
                    withAnimation { tasks = sorted(tasks) }
                }
            } catch {
                errorMessage = String(localized: "Couldn't update the task.")
            }
        }
    }

    /// Firestore delete + local removal (swipe action).
    private func delete(_ task: HouseholdTask) {
        Task {
            do {
                try await withTimeout(15) {
                    try await TasksRepository.deleteTask(task)
                }
                remove(task)
            } catch {
                errorMessage = String(localized: "Couldn't delete the task.")
            }
        }
    }

    /// Local removal only (detail view already deleted remotely).
    private func remove(_ task: HouseholdTask) {
        withAnimation {
            tasks.removeAll { $0.id == task.id }
        }
        subtasksByTask[task.id] = nil
    }
}

private struct TaskRowLabel: View {
    let task: HouseholdTask
    let category: TaskCategory?
    let subtasks: [Subtask]

    private var subtaskSummary: String? {
        guard !subtasks.isEmpty else { return nil }
        return "\(subtasks.filter(\.isCompleted).count)/\(subtasks.count)"
    }

    private var isOverdue: Bool {
        guard let due = task.dueDate, !task.isCompleted else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)

            if category != nil || subtaskSummary != nil || task.dueDate != nil {
                HStack(spacing: 10) {
                    if let category {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color(hex: category.color))
                            Text(category.name)
                        }
                    }
                    if let due = task.dueDate {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                            Text(due, style: .date)
                        }
                        .foregroundStyle(isOverdue ? Color.red : Color.secondary)
                    }
                    if let subtaskSummary {
                        HStack(spacing: 3) {
                            Image(systemName: "checklist")
                            Text(subtaskSummary)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
