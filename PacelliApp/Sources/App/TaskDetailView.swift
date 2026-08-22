import PacelliKit
import SwiftUI

/// Task detail + editing: title, notes, category, priority, due date,
/// subtasks, delete. Edits save explicitly (Save button) via a partial
/// `updateTask`; subtask and delete operations apply immediately.
struct TaskDetailView: View {
    @Binding var task: HouseholdTask
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var priority: String
    @State private var categoryId: String?
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var customReminder: Bool
    @State private var reminderTime: Date

    @State private var categories: [TaskCategory] = []
    @State private var subtasks: [Subtask] = []
    @State private var newSubtaskTitle = ""
    @State private var saving = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    init(task: Binding<HouseholdTask>, onDelete: @escaping () -> Void) {
        self._task = task
        self.onDelete = onDelete
        let t = task.wrappedValue
        _title = State(initialValue: t.title)
        _notes = State(initialValue: t.description ?? "")
        _priority = State(initialValue: t.priority)
        _categoryId = State(initialValue: t.categoryId)
        _hasDueDate = State(initialValue: t.dueDate != nil)
        _dueDate = State(initialValue: t.dueDate ?? Calendar.current.startOfDay(for: Date()))
        _customReminder = State(initialValue: t.reminderTime != nil)
        _reminderTime = State(
            initialValue: (t.reminderTime.flatMap(TimeOfDay.init(raw:))
                ?? ReminderPrefs.current.defaultTime).date)
    }

    private var isDirty: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        return (trimmed != task.title && !trimmed.isEmpty)
            || notesValue != task.description
            || priority != task.priority
            || categoryId != task.categoryId
            || dueDateValue != task.dueDate
            || reminderValue != task.reminderTime
    }

    private var notesValue: String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var defaultReminderNote: String {
        let prefs = ReminderPrefs.current
        guard prefs.enabled else {
            return String(localized: "Turn on reminders in Settings to be notified.")
        }
        return String(localized: "Reminds you at \(prefs.defaultTime.raw), your default time.")
    }

    private var dueDateValue: Date? { hasDueDate ? dueDate : nil }

    /// Nil means "use the device default" — the override is deliberately
    /// opt-in so the common case stays a single toggle.
    private var reminderValue: String? {
        guard hasDueDate, customReminder else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        return TimeOfDay(hour: c.hour ?? 12, minute: c.minute ?? 0).raw
    }

    var body: some View {
        Form {
            Section("Task") {
                TextField("Title", text: $title)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(1...6)
            }

            Section("Details") {
                Picker(selection: $categoryId) {
                    Text("None").tag(String?.none)
                    ForEach(categories) { category in
                        Text(category.name).tag(String?.some(category.id))
                    }
                } label: {
                    // Dot lives on the label side — SwiftUI renders the
                    // collapsed menu value monochrome, so color there is lost.
                    HStack(spacing: 8) {
                        Text("Category")
                        if let selected = categories.first(where: { $0.id == categoryId }) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: selected.color))
                        }
                    }
                }
                NavigationLink("Manage categories") {
                    ManageCategoriesView(
                        householdId: task.householdId,
                        categories: $categories,
                        onDeleted: { deletedId in
                            if categoryId == deletedId { categoryId = nil }
                        })
                }

                Picker("Priority", selection: $priority) {
                    Text("Low").tag(HouseholdTask.Priority.low)
                    Text("Medium").tag(HouseholdTask.Priority.medium)
                    Text("High").tag(HouseholdTask.Priority.high)
                    Text("Urgent").tag(HouseholdTask.Priority.urgent)
                }

                Toggle("Due date", isOn: $hasDueDate.animation())
                if hasDueDate {
                    DatePicker(
                        "Due", selection: $dueDate, displayedComponents: .date)

                    Toggle("Reminder at a set time", isOn: $customReminder.animation())
                        .accessibilityIdentifier("task_custom_reminder")
                    if customReminder {
                        DatePicker(
                            "Remind me at", selection: $reminderTime,
                            displayedComponents: .hourAndMinute)
                    } else {
                        Text(defaultReminderNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                PhotoStrip(
                    subject: .task,
                    subjectId: task.id,
                    householdId: task.householdId)
            } header: {
                Text("Photos")
            } footer: {
                Text(
                    "Photos are encrypted on this device before they are stored, like everything else. The original stays on your phone; everyone in the household can see it."
                )
            }

            Section("Subtasks") {
                ForEach(subtasks) { subtask in
                    SubtaskRow(subtask: subtask) { toggleSubtask(subtask) }
                }
                .onDelete(perform: deleteSubtasks)

                HStack(spacing: 12) {
                    TextField("Add a subtask", text: $newSubtaskTitle)
                        .onSubmit(addSubtask)
                    Button(action: addSubtask) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(
                        newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section {
                Button(task.isCompleted ? "Reopen task" : "Mark completed") {
                    toggleCompleted()
                }
                Button("Delete task", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(!isDirty || saving)
            }
        }
        .task { await load() }
        .confirmationDialog(
            "Delete this task?", isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete task and subtasks", role: .destructive) { deleteTask() }
        } message: {
            Text("This also deletes its subtasks. This can't be undone.")
        }
        .alert(
            "Something went wrong", isPresented: .constant(errorMessage != nil),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") })
    }

    // MARK: - Data

    private func load() async {
        let taskId = task.id
        let householdId = task.householdId
        do {
            subtasks = try await withTimeout(15) {
                try await SubtasksRepository.fetchSubtasks(
                    taskId: taskId, householdId: householdId)
            }
            categories = try await withTimeout(15) {
                try await CategoriesRepository.fetchCategories(
                    householdId: householdId)
            }
        } catch {
            print("[TaskDetailView] load failed: \(error)")
            errorMessage = String(localized: "Couldn't load task details.")
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saving = true
        Task {
            do {
                try await withTimeout(15) {
                    try await TasksRepository.updateTask(
                        task,
                        title: trimmed != task.title ? trimmed : nil,
                        description: notesValue != task.description
                            ? .some(notesValue) : nil,
                        categoryId: categoryId != task.categoryId
                            ? .some(categoryId) : nil,
                        priority: priority != task.priority ? priority : nil,
                        dueDate: dueDateValue != task.dueDate
                            ? .some(dueDateValue) : nil,
                        reminderTime: reminderValue != task.reminderTime
                            ? .some(reminderValue) : nil)
                }
                task.title = trimmed
                task.description = notesValue
                task.categoryId = categoryId
                task.priority = priority
                task.dueDate = dueDateValue
                task.reminderTime = reminderValue
            } catch {
                print("[TaskDetailView] save failed: \(error)")
                errorMessage = String(localized: "Couldn't save your changes.")
            }
            saving = false
        }
    }

    private func toggleCompleted() {
        Task {
            do {
                let completed = !task.isCompleted
                try await withTimeout(15) {
                    try await TasksRepository.setCompleted(task, completed: completed)
                }
                task.status =
                    completed
                    ? HouseholdTask.Status.completed : HouseholdTask.Status.pending
                task.completedAt = completed ? Date() : nil
            } catch {
                errorMessage = String(localized: "Couldn't update the task.")
            }
        }
    }

    private func deleteTask() {
        Task {
            do {
                try await withTimeout(15) {
                    try await TasksRepository.deleteTask(task)
                }
                dismiss()
                onDelete()
            } catch {
                errorMessage = String(localized: "Couldn't delete the task.")
            }
        }
    }

    // MARK: - Subtasks

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        newSubtaskTitle = ""
        let sortOrder = (subtasks.map(\.sortOrder).max() ?? -1) + 1
        Task {
            do {
                let created = try await withTimeout(15) {
                    try await SubtasksRepository.addSubtask(
                        taskId: task.id, householdId: task.householdId,
                        title: title, sortOrder: sortOrder)
                }
                subtasks.append(created)
            } catch {
                errorMessage = String(localized: "Couldn't add the subtask.")
            }
        }
    }

    private func toggleSubtask(_ subtask: Subtask) {
        Task {
            do {
                let completed = !subtask.isCompleted
                try await withTimeout(15) {
                    try await SubtasksRepository.setCompleted(
                        subtask, completed: completed)
                }
                if let i = subtasks.firstIndex(where: { $0.id == subtask.id }) {
                    subtasks[i].isCompleted = completed
                }
            } catch {
                errorMessage = String(localized: "Couldn't update the subtask.")
            }
        }
    }

    private func deleteSubtasks(at offsets: IndexSet) {
        let toDelete = offsets.map { subtasks[$0] }
        subtasks.remove(atOffsets: offsets)
        Task {
            for subtask in toDelete {
                do {
                    try await withTimeout(15) {
                        try await SubtasksRepository.deleteSubtask(subtask)
                    }
                } catch {
                    subtasks.append(subtask)
                    subtasks.sort { ($0.sortOrder, $0.id) < ($1.sortOrder, $1.id) }
                    errorMessage = String(localized: "Couldn't delete the subtask.")
                }
            }
        }
    }
}

private struct SubtaskRow: View {
    let subtask: Subtask
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(subtask.isCompleted ? Color.accentColor : .secondary)
                Text(subtask.title)
                    .strikethrough(subtask.isCompleted)
                    .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Category management: list, add, delete (defaults are protected).
struct ManageCategoriesView: View {
    let householdId: String
    @Binding var categories: [TaskCategory]
    let onDeleted: (String) -> Void

    @State private var newName = ""
    @State private var newColor = TaskCategory.defaultColor
    @State private var errorMessage: String?

    private static let palette = [
        "#7EA87E", "#5B8DB8", "#B87E5B", "#9B7EB8", "#B85B7E", "#7EB8A8",
    ]

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    HStack(spacing: 12) {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(Color(hex: category.color))
                        Text(category.name)
                        Spacer()
                        if category.isDefault {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Default category")
                        }
                    }
                }
                .onDelete(perform: delete)
            }

            Section("New category") {
                TextField("Name", text: $newName)
                HStack(spacing: 14) {
                    ForEach(Self.palette, id: \.self) { hex in
                        Button {
                            newColor = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if newColor == hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Add category") { add() }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Something went wrong", isPresented: .constant(errorMessage != nil),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") })
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        newName = ""
        Task {
            do {
                let created = try await withTimeout(15) {
                    try await CategoriesRepository.createCategory(
                        householdId: householdId, name: name, color: newColor)
                }
                categories.append(created)
            } catch {
                errorMessage = String(localized: "Couldn't add the category.")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { categories[$0] }
        for category in toDelete where category.isDefault {
            return  // Defaults are protected; keep the list untouched.
        }
        categories.remove(atOffsets: offsets)
        Task {
            for category in toDelete {
                do {
                    try await withTimeout(15) {
                        try await CategoriesRepository.deleteCategory(category)
                    }
                    onDeleted(category.id)
                } catch {
                    categories.append(category)
                    errorMessage = String(localized: "Couldn't delete the category.")
                }
            }
        }
    }
}

extension Color {
    /// `#RRGGBB` hex → Color. Falls back to the accent color on bad input.
    init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else {
            self = .accentColor
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }
}
