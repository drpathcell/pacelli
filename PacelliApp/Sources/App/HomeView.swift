import PacelliKit
import SwiftUI

/// Usable Home — the screen a guest lands on with zero walls.
/// Walking-skeleton scope: live task list (decrypted), add, complete.
struct HomeView: View {
    let current: CurrentHousehold

    @State private var tasks: [HouseholdTask] = []
    @State private var newTitle = ""
    @State private var loading = true
    @State private var errorMessage: String?

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
                        ForEach(tasks) { task in
                            TaskRow(task: task) { toggle(task) }
                        }
                    }
                }
            }
            .navigationTitle(current.household.name)
            .safeAreaInset(edge: .bottom) { addBar }
            .task { await reload() }
            .refreshable { await reload() }
            .alert(
                "Something went wrong", isPresented: .constant(errorMessage != nil),
                actions: { Button("OK") { errorMessage = nil } },
                message: { Text(errorMessage ?? "") })
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

    private func reload() async {
        do {
            let householdId = current.household.id
            tasks = try await withTimeout(15) {
                try await TasksRepository.fetchTasks(householdId: householdId)
            }
            loading = false
        } catch {
            loading = false
            errorMessage = String(localized: "Couldn't load tasks.")
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
                }
            } catch {
                errorMessage = String(localized: "Couldn't update the task.")
            }
        }
    }
}

private struct TaskRow: View {
    let task: HouseholdTask
    let onToggle: () -> Void

    var body: some View {
        // Whole row toggles (audit fix: circle-only was a 22pt target,
        // below the 44pt HIG minimum).
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)

                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
