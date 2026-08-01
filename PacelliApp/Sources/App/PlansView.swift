import PacelliKit
import SwiftUI

/// Plans tab: live list (decrypted) with add (weekly plan starting today),
/// delete, and navigation into day-by-day detail.
struct PlansView: View {
    let current: CurrentHousehold
    let appState: AppState

    @State private var plans: [Plan] = []
    @State private var newTitle = ""
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var showAccount = false

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                } else if plans.isEmpty {
                    ContentUnavailableView(
                        "No plans yet",
                        systemImage: "calendar",
                        description: Text("Add a weekly plan below."))
                } else {
                    List {
                        ForEach($plans) { $plan in
                            NavigationLink {
                                PlanDetailView(plan: $plan) { remove(plan) }
                            } label: {
                                PlanRowLabel(plan: plan)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(plan)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Plans")
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
            TextField("New weekly plan", text: $newTitle)
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
            plans = try await withTimeout(15) {
                try await PlansRepository.fetchPlans(householdId: householdId)
            }
            loading = false
        } catch {
            loading = false
            errorMessage = String(localized: "Couldn't load plans.")
        }
    }

    /// Creates a weekly plan: today → today+6.
    private func add() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        newTitle = ""
        Task {
            do {
                let householdId = current.household.id
                let start = Calendar.current.startOfDay(for: Date())
                let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
                let created = try await withTimeout(15) {
                    try await PlansRepository.createPlan(
                        householdId: householdId, title: title,
                        startDate: start, endDate: end)
                }
                plans.insert(created, at: 0)
            } catch {
                errorMessage = String(localized: "Couldn't add the plan.")
            }
        }
    }

    private func delete(_ plan: Plan) {
        Task {
            do {
                try await withTimeout(15) {
                    try await PlansRepository.deletePlan(plan)
                }
                remove(plan)
            } catch {
                errorMessage = String(localized: "Couldn't delete the plan.")
            }
        }
    }

    private func remove(_ plan: Plan) {
        withAnimation {
            plans.removeAll { $0.id == plan.id }
        }
    }
}

private struct PlanRowLabel: View {
    let plan: Plan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(plan.title)
                if plan.status == Plan.Status.finalised {
                    Text("Finalised")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                    Text(
                        "\(plan.startDate.formatted(.dateTime.day().month())) – \(plan.endDate.formatted(.dateTime.day().month()))"
                    )
                }
                if !plan.entries.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "list.bullet")
                        Text("\(plan.entries.count)")
                    }
                }
                if !plan.checklistItems.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "checklist")
                        Text(
                            "\(plan.checklistItems.filter(\.isChecked).count)/\(plan.checklistItems.count)"
                        )
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Plan detail: one section per day in the plan's range with its entries,
/// an add bar targeting a picked day, the plan checklist, status toggle,
/// and delete. Entry/item ops apply immediately.
struct PlanDetailView: View {
    @Binding var plan: Plan
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var newEntryTitle = ""
    @State private var targetDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var newItemTitle = ""
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    private var days: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: plan.startDate)
        let end = cal.startOfDay(for: plan.endDate)
        var result: [Date] = []
        var d = start
        while d <= end && result.count < 62 {
            result.append(d)
            d = cal.date(byAdding: .day, value: 1, to: d) ?? end.addingTimeInterval(1)
        }
        return result
    }

    private func entries(on day: Date) -> [PlanEntry] {
        plan.entries.filter { Calendar.current.isDate($0.entryDate, inSameDayAs: day) }
    }

    var body: some View {
        List {
            ForEach(days, id: \.self) { day in
                Section(day.formatted(.dateTime.weekday(.wide).day().month())) {
                    let dayEntries = entries(on: day)
                    if dayEntries.isEmpty {
                        Text("No entries")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    ForEach(dayEntries) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                            if let label = entry.label, !label.isEmpty {
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteEntry(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section("Add entry") {
                Picker("Day", selection: $targetDay) {
                    ForEach(days, id: \.self) { day in
                        Text(day.formatted(.dateTime.weekday(.abbreviated).day().month()))
                            .tag(day)
                    }
                }
                HStack(spacing: 12) {
                    TextField("Entry title", text: $newEntryTitle)
                        .onSubmit(addEntry)
                    Button(action: addEntry) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newEntryTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Checklist") {
                ForEach(plan.checklistItems) { item in
                    PlanChecklistRow(item: item) { toggleItem(item) }
                }
                .onDelete(perform: deleteItems)

                HStack(spacing: 12) {
                    TextField("Add a checklist item", text: $newItemTitle)
                        .onSubmit(addItem)
                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section {
                Button(
                    plan.status == Plan.Status.finalised
                        ? "Back to draft" : "Mark finalised"
                ) {
                    toggleStatus()
                }
                Button("Delete plan", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Default the add-entry target to today when in range.
            let today = Calendar.current.startOfDay(for: Date())
            targetDay = days.contains(today) ? today : (days.first ?? today)
        }
        .confirmationDialog(
            "Delete this plan?", isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete plan, entries and checklist", role: .destructive) {
                deletePlan()
            }
        } message: {
            Text("This can't be undone.")
        }
        .alert(
            "Something went wrong", isPresented: .constant(errorMessage != nil),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") })
    }

    // MARK: - Entries

    private func addEntry() {
        let title = newEntryTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        newEntryTitle = ""
        let day = targetDay
        let sortOrder = (entries(on: day).map(\.sortOrder).max() ?? -1) + 1
        Task {
            do {
                let created = try await withTimeout(15) {
                    try await PlansRepository.addEntry(
                        planId: plan.id, householdId: plan.householdId,
                        entryDate: day, title: title, sortOrder: sortOrder)
                }
                plan.entries.append(created)
            } catch {
                errorMessage = String(localized: "Couldn't add the entry.")
            }
        }
    }

    private func deleteEntry(_ entry: PlanEntry) {
        Task {
            do {
                try await withTimeout(15) {
                    try await PlansRepository.deleteEntry(entry)
                }
                withAnimation {
                    plan.entries.removeAll { $0.id == entry.id }
                }
            } catch {
                errorMessage = String(localized: "Couldn't delete the entry.")
            }
        }
    }

    // MARK: - Checklist

    private func addItem() {
        let title = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        newItemTitle = ""
        Task {
            do {
                let created = try await withTimeout(15) {
                    try await PlansRepository.addChecklistItem(
                        planId: plan.id, householdId: plan.householdId, title: title)
                }
                plan.checklistItems.append(created)
            } catch {
                errorMessage = String(localized: "Couldn't add the item.")
            }
        }
    }

    private func toggleItem(_ item: PlanChecklistItem) {
        Task {
            do {
                let checked = !item.isChecked
                try await withTimeout(15) {
                    try await PlansRepository.setChecked(item, checked: checked)
                }
                if let i = plan.checklistItems.firstIndex(where: { $0.id == item.id }) {
                    plan.checklistItems[i].isChecked = checked
                    plan.checklistItems[i].checkedAt = checked ? Date() : nil
                }
            } catch {
                errorMessage = String(localized: "Couldn't update the item.")
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let toDelete = offsets.map { plan.checklistItems[$0] }
        plan.checklistItems.remove(atOffsets: offsets)
        Task {
            for item in toDelete {
                do {
                    try await withTimeout(15) {
                        try await PlansRepository.deleteChecklistItem(item)
                    }
                } catch {
                    plan.checklistItems.append(item)
                    errorMessage = String(localized: "Couldn't delete the item.")
                }
            }
        }
    }

    // MARK: - Plan

    private func toggleStatus() {
        let newStatus =
            plan.status == Plan.Status.finalised
            ? Plan.Status.draft : Plan.Status.finalised
        Task {
            do {
                try await withTimeout(15) {
                    try await PlansRepository.updateStatus(plan, status: newStatus)
                }
                plan.status = newStatus
                plan.updatedAt = Date()
            } catch {
                errorMessage = String(localized: "Couldn't update the plan.")
            }
        }
    }

    private func deletePlan() {
        Task {
            do {
                try await withTimeout(15) {
                    try await PlansRepository.deletePlan(plan)
                }
                dismiss()
                onDelete()
            } catch {
                errorMessage = String(localized: "Couldn't delete the plan.")
            }
        }
    }
}

private struct PlanChecklistRow: View {
    let item: PlanChecklistItem
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
