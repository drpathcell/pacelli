import PacelliKit
import SwiftUI

/// Checklists tab: live list (decrypted) with add, delete, and navigation
/// into item-level detail.
struct ChecklistsView: View {
    let current: CurrentHousehold
    let appState: AppState

    @State private var checklists: [Checklist] = []
    @State private var templates: [ChecklistTemplate] = []
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
                        templatesSection
                        Section {
                            ForEach($checklists) { $checklist in
                                NavigationLink {
                                    ChecklistDetailView(
                                        checklist: $checklist,
                                        onSavedAsTemplate: { templates.insert($0, at: 0) }
                                    ) {
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

    /// Only shown once something has been saved. An always-present empty
    /// "Templates" header would be a permanent advert for a feature the
    /// household is not using.
    @ViewBuilder
    private var templatesSection: some View {
        if !templates.isEmpty {
            Section {
                ForEach(templates) { template in
                    Button {
                        use(template)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.on.square")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.title)
                                    .foregroundStyle(.primary)
                                Text(
                                    template.items.count == 1
                                        ? "1 item"
                                        : "\(template.items.count) items"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("template_row")
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteTemplate(template)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Templates")
            } footer: {
                Text("Tap a template to start a new list from it.")
            }
        }
    }

    /// Stamps a template into a real checklist and drops it at the top, where
    /// the person who just tapped it is looking.
    private func use(_ template: ChecklistTemplate) {
        Task {
            do {
                let created = try await withTimeout(15) {
                    try await ChecklistsRepository.createChecklist(from: template)
                }
                withAnimation { checklists.insert(created, at: 0) }
            } catch {
                errorMessage = String(localized: "Couldn't start a list from that template.")
            }
        }
    }

    private func deleteTemplate(_ template: ChecklistTemplate) {
        let previous = templates
        withAnimation { templates.removeAll { $0.id == template.id } }
        Task {
            do {
                try await withTimeout(15) {
                    try await ChecklistsRepository.deleteTemplate(template)
                }
            } catch {
                templates = previous
                errorMessage = String(localized: "Couldn't delete the template.")
            }
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
            // Templates are secondary: a failure here must not blank the
            // checklists that already loaded, so it is caught separately and
            // silently. Worst case the section is missing until the next pull.
            templates = (try? await withTimeout(15) {
                try await ChecklistsRepository.fetchTemplates(householdId: householdId)
            }) ?? []
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
    let onSavedAsTemplate: (ChecklistTemplate) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var newItemTitle = ""
    @State private var newItemQuantity = ""
    @State private var saving = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?
    @State private var namingTemplate = false
    @State private var templateName = ""
    @State private var savedTemplateName: String?

    init(
        checklist: Binding<Checklist>,
        onSavedAsTemplate: @escaping (ChecklistTemplate) -> Void = { _ in },
        onDelete: @escaping () -> Void
    ) {
        self._checklist = checklist
        self.onSavedAsTemplate = onSavedAsTemplate
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
                    ChecklistItemRow(
                        item: item,
                        onToggle: { toggle(item) },
                        onCommit: { newTitle, newQty in
                            updateItem(item, title: newTitle, quantity: newQty)
                        })
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
                Button {
                    templateName = title
                    namingTemplate = true
                } label: {
                    Label("Save as template", systemImage: "square.on.square")
                }
                // A template of nothing is not worth saving, and the button
                // being live would suggest otherwise.
                .disabled(checklist.items.isEmpty)
                .accessibilityIdentifier("save_as_template_button")
            } footer: {
                Text(
                    checklist.items.isEmpty
                        ? "Add some items first, then you can save this list as a reusable template."
                        : "Anyone in your household can start a fresh list from a template."
                )
            }

            Section {
                Button("Delete checklist", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .alert("Save as template", isPresented: $namingTemplate) {
            TextField("Template name", text: $templateName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saveAsTemplate() }
        } message: {
            Text("Its items are copied as they are now. Ticking things off later won't change the template.")
        }
        .alert(
            "Saved", isPresented: .constant(savedTemplateName != nil),
            actions: { Button("OK") { savedTemplateName = nil } },
            message: {
                Text("\"\(savedTemplateName ?? "")\" is now in Templates on the Checklists screen.")
            })
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

    /// Optimistic, and it puts the old values back if the write fails —
    /// otherwise the row keeps showing an edit the household never received.
    private func updateItem(_ item: ChecklistItem, title newTitle: String, quantity newQty: String) {
        guard let i = checklist.items.firstIndex(where: { $0.id == item.id }) else { return }
        let previousTitle = checklist.items[i].title
        let previousQty = checklist.items[i].quantity

        checklist.items[i].title = newTitle
        checklist.items[i].quantity = newQty.isEmpty ? nil : newQty

        Task {
            do {
                try await withTimeout(15) {
                    try await ChecklistsRepository.updateItem(
                        item, title: newTitle, quantity: newQty.isEmpty ? nil : newQty)
                }
            } catch {
                if let j = checklist.items.firstIndex(where: { $0.id == item.id }) {
                    checklist.items[j].title = previousTitle
                    checklist.items[j].quantity = previousQty
                }
                errorMessage = String(localized: "Couldn't save the change.")
            }
        }
    }

    private func saveAsTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !checklist.items.isEmpty else { return }
        let snapshot = checklist
        Task {
            do {
                let created = try await withTimeout(15) {
                    try await ChecklistsRepository.saveAsTemplate(snapshot, title: name)
                }
                onSavedAsTemplate(created)
                savedTemplateName = created.title
            } catch {
                errorMessage = String(localized: "Couldn't save the template.")
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

/// An item you can actually correct.
///
/// Until 1.5.0 the whole row was one Button that only toggled, so changing
/// "White pepper ×1" to ×2 meant deleting it and retyping — which also threw
/// away its position and its checked state. Now the circle toggles and the
/// text is editable in place, in the same shape as the "Add an item" row
/// directly beneath it so the two read as one control.
private struct ChecklistItemRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void
    /// (title, quantity) — called only when something actually changed.
    let onCommit: (String, String) -> Void

    @State private var title: String
    @State private var quantity: String
    @FocusState private var focused: Field?
    @Environment(\.scenePhase) private var scenePhase

    private enum Field { case title, quantity }

    init(
        item: ChecklistItem,
        onToggle: @escaping () -> Void,
        onCommit: @escaping (String, String) -> Void
    ) {
        self.item = item
        self.onToggle = onToggle
        self.onCommit = onCommit
        _title = State(initialValue: item.title)
        _quantity = State(initialValue: item.quantity ?? "")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Only the circle toggles. Making the whole row toggle again would
            // mean every attempt to place the cursor ticks the item off.
            Button(action: onToggle) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isChecked ? "Uncheck \(item.title)" : "Check \(item.title)")

            TextField("Item", text: $title)
                .focused($focused, equals: .title)
                .strikethrough(item.isChecked)
                .foregroundStyle(item.isChecked ? .secondary : .primary)
                .submitLabel(.done)
                .onSubmit(commit)
                .accessibilityIdentifier("checklist_item_title")

            TextField("Qty", text: $quantity)
                .focused($focused, equals: .quantity)
                .frame(width: 52)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .submitLabel(.done)
                .onSubmit(commit)
                .accessibilityIdentifier("checklist_item_qty")
        }
        // Commit when the field loses focus, not on every keystroke: a write
        // per character would be a Firestore write per character.
        .onChange(of: focused) { _, now in
            if now == nil { commit() }
        }
        // Focus loss alone is not enough, and the first version of this shipped
        // with only that. Type "×3", swipe the app away, and the edit dies with
        // the process — the field never lost focus, so nothing ever wrote.
        // Caught on a cold relaunch, 2026-08-13.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { commit() }
        }
        // Same hole one level down: navigating back tears the row down without
        // ever resigning first responder.
        .onDisappear { commit() }
        // Someone else edited this item, or our own toggle came back. Adopt it
        // ONLY while not being edited, or a sync would overwrite mid-sentence.
        .onChange(of: item.title) { _, new in
            if focused == nil { title = new }
        }
        .onChange(of: item.quantity) { _, new in
            if focused == nil { quantity = new ?? "" }
        }
    }

    private func commit() {
        let t = title.trimmingCharacters(in: .whitespaces)
        let q = quantity.trimmingCharacters(in: .whitespaces)
        // An empty title would leave an unnameable row; put the old one back.
        guard !t.isEmpty else {
            title = item.title
            quantity = item.quantity ?? ""
            return
        }
        guard t != item.title || q != (item.quantity ?? "") else { return }
        onCommit(t, q)
    }
}
