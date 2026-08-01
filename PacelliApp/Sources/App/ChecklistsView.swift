import PacelliKit
import SwiftUI

/// Checklists tab: live list (decrypted) with add, delete, and navigation
/// into item-level detail.
struct ChecklistsView: View {
    let current: CurrentHousehold
    let appState: AppState

    @State private var checklists: [Checklist] = []
    @State private var newTitle = ""
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var showAccount = false

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                } else if checklists.isEmpty {
                    ContentUnavailableView(
                        "No checklists yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Add your first checklist below."))
                } else {
                    List {
                        ForEach($checklists) { $checklist in
                            NavigationLink {
                                ChecklistDetailView(checklist: $checklist) {
                                    remove(checklist)
                                }
                            } label: {
                                ChecklistRowLabel(checklist: checklist)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(checklist)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Checklists")
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

    private var addBar: some View {
        HStack(spacing: 12) {
            TextField("New checklist", text: $newTitle)
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
        let householdId = current.household.id
        do {
            checklists = try await withTimeout(15) {
                try await ChecklistsRepository.fetchChecklists(householdId: householdId)
            }
            loading = false
        } catch {
            loading = false
            errorMessage = String(localized: "Couldn't load checklists.")
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
                    try await ChecklistsRepository.createChecklist(
                        householdId: householdId, title: title)
                }
                checklists.insert(created, at: 0)
            } catch {
                errorMessage = String(localized: "Couldn't add the checklist.")
            }
        }
    }

    /// Firestore delete + local removal (swipe action).
    private func delete(_ checklist: Checklist) {
        Task {
            do {
                try await withTimeout(15) {
                    try await ChecklistsRepository.deleteChecklist(checklist)
                }
                remove(checklist)
            } catch {
                errorMessage = String(localized: "Couldn't delete the checklist.")
            }
        }
    }

    /// Local removal only (detail view already deleted remotely).
    private func remove(_ checklist: Checklist) {
        withAnimation {
            checklists.removeAll { $0.id == checklist.id }
        }
    }
}

private struct ChecklistRowLabel: View {
    let checklist: Checklist

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(checklist.title)
            if !checklist.items.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "checklist")
                    Text(
                        "\(checklist.items.filter(\.isChecked).count)/\(checklist.items.count)"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Checklist detail: rename, item add/toggle/delete, push-item-as-task,
/// delete checklist. Rename saves explicitly; item ops apply immediately.
struct ChecklistDetailView: View {
    @Binding var checklist: Checklist
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var newItemTitle = ""
    @State private var newItemQuantity = ""
    @State private var saving = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    init(checklist: Binding<Checklist>, onDelete: @escaping () -> Void) {
        self._checklist = checklist
        self.onDelete = onDelete
        _title = State(initialValue: checklist.wrappedValue.title)
    }

    private var isDirty: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        return trimmed != checklist.title && !trimmed.isEmpty
    }

    var body: some View {
        List {
            Section("Checklist") {
                TextField("Title", text: $title)
            }

            Section("Items") {
                ForEach(checklist.items) { item in
                    ChecklistItemRow(item: item) { toggle(item) }
                        .swipeActions(edge: .leading) {
                            Button {
                                pushAsTask(item)
                            } label: {
                                Label("Make task", systemImage: "arrow.right.circle")
                            }
                            .tint(.accentColor)
                        }
                }
                .onDelete(perform: deleteItems)

                HStack(spacing: 12) {
                    TextField("Add an item", text: $newItemTitle)
                        .onSubmit(addItem)
                    TextField("Qty", text: $newItemQuantity)
                        .frame(width: 52)
                        .textFieldStyle(.roundedBorder)
                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section {
                Button("Delete checklist", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .navigationTitle("Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(!isDirty || saving)
            }
        }
        .confirmationDialog(
            "Delete this checklist?", isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete checklist and items", role: .destructive) { deleteChecklist() }
        } message: {
            Text("This also deletes its items. This can't be undone.")
        }
        .alert(
            "Something went wrong", isPresented: .constant(errorMessage != nil),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") })
    }

    // MARK: - Checklist

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saving = true
        Task {
            do {
                try await withTimeout(15) {
                    try await ChecklistsRepository.updateChecklist(
                        checklist, title: trimmed)
                }
                checklist.title = trimmed
                checklist.updatedAt = Date()
            } catch {
                errorMessage = String(localized: "Couldn't save your changes.")
            }
            saving = false
        }
    }

    private func deleteChecklist() {
        Task {
            do {
                try await withTimeout(15) {
                    try await ChecklistsRepository.deleteChecklist(checklist)
                }
                dismiss()
                onDelete()
            } catch {
                errorMessage = String(localized: "Couldn't delete the checklist.")
            }
        }
    }

    // MARK: - Items

    private func addItem() {
        let itemTitle = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !itemTitle.isEmpty else { return }
        let quantity = newItemQuantity.trimmingCharacters(in: .whitespaces)
        newItemTitle = ""
        newItemQuantity = ""
        Task {
            do {
                let created = try await withTimeout(15) {
                    try await ChecklistsRepository.addItem(
                        checklistId: checklist.id,
                        householdId: checklist.householdId,
                        title: itemTitle,
                        quantity: quantity.isEmpty ? nil : quantity)
                }
                checklist.items.append(created)
            } catch {
                errorMessage = String(localized: "Couldn't add the item.")
            }
        }
    }

    private func toggle(_ item: ChecklistItem) {
        Task {
            do {
                let checked = !item.isChecked
                try await withTimeout(15) {
                    try await ChecklistsRepository.setChecked(item, checked: checked)
                }
                if let i = checklist.items.firstIndex(where: { $0.id == item.id }) {
                    checklist.items[i].isChecked = checked
                    checklist.items[i].checkedAt = checked ? Date() : nil
                }
            } catch {
                errorMessage = String(localized: "Couldn't update the item.")
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let toDelete = offsets.map { checklist.items[$0] }
        checklist.items.remove(atOffsets: offsets)
        Task {
            for item in toDelete {
                do {
                    try await withTimeout(15) {
                        try await ChecklistsRepository.deleteItem(item)
                    }
                } catch {
                    checklist.items.append(item)
                    errorMessage = String(localized: "Couldn't delete the item.")
                }
            }
        }
    }

    private func pushAsTask(_ item: ChecklistItem) {
        Task {
            do {
                try await withTimeout(15) {
                    try await ChecklistsRepository.pushItemAsTask(item)
                }
                withAnimation {
                    checklist.items.removeAll { $0.id == item.id }
                }
            } catch {
                errorMessage = String(localized: "Couldn't move the item to tasks.")
            }
        }
    }
}

private struct ChecklistItemRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? Color.accentColor : .secondary)
                Text(item.title)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                if let quantity = item.quantity, !quantity.isEmpty {
                    Text("×\(quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
