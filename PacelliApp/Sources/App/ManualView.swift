import PacelliKit
import SwiftUI

/// Household manual: pinned-first entry list with add/edit/delete.
/// v1 scope: title + markdown content + pin (categories/tags deferred).
struct ManualView: View {
    let current: CurrentHousehold

    @State private var entries: [ManualEntry] = []
    @State private var loading = true
    @State private var showingNew = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if entries.isEmpty {
                ContentUnavailableView(
                    "No manual entries yet",
                    systemImage: "book",
                    description: Text(
                        "Keep how-tos and household notes here — bin schedules, appliance quirks, wifi details."))
            } else {
                List {
                    ForEach($entries) { $entry in
                        NavigationLink {
                            ManualEntryView(entry: $entry) { remove(entry) }
                        } label: {
                            HStack(spacing: 10) {
                                if entry.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption)
                                        .foregroundStyle(.tint)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                    if !entry.content.isEmpty {
                                        Text(entry.content)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Household manual")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNew = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New entry")
            }
        }
        .sheet(isPresented: $showingNew) {
            NewManualEntrySheet(householdId: current.household.id) { created in
                entries.insert(created, at: 0)
                resort()
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .alert(
            "Something went wrong", isPresented: .constant(errorMessage != nil),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") })
    }

    private func reload() async {
        let householdId = current.household.id
        do {
            entries = try await withTimeout(15) {
                try await ManualRepository.fetchEntries(householdId: householdId)
            }
            loading = false
        } catch {
            loading = false
            errorMessage = String(localized: "Couldn't load the manual.")
        }
    }

    private func resort() {
        entries.sort {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func delete(_ entry: ManualEntry) {
        Task {
            do {
                try await withTimeout(15) {
                    try await ManualRepository.deleteEntry(entry)
                }
                remove(entry)
            } catch {
                errorMessage = String(localized: "Couldn't delete the entry.")
            }
        }
    }

    private func remove(_ entry: ManualEntry) {
        withAnimation { entries.removeAll { $0.id == entry.id } }
    }
}

private struct NewManualEntrySheet: View {
    let householdId: String
    let onCreated: (ManualEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title, axis: .vertical)
                    .lineLimit(1...4)
                TextField("Write it down…", text: $content, axis: .vertical)
                    .lineLimit(6...16)
            }
            .navigationTitle("New entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(
                            title.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
            .alert(
                "Something went wrong", isPresented: .constant(errorMessage != nil),
                actions: { Button("OK") { errorMessage = nil } },
                message: { Text(errorMessage ?? "") })
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saving = true
        Task {
            do {
                let created = try await withTimeout(15) {
                    try await ManualRepository.createEntry(
                        householdId: householdId, title: trimmed, content: content)
                }
                onCreated(created)
                dismiss()
            } catch {
                errorMessage = String(localized: "Couldn't save the entry.")
                saving = false
            }
        }
    }
}

/// Edit view: title, content, pin. Explicit Save (dirty-tracked).
struct ManualEntryView: View {
    @Binding var entry: ManualEntry
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var isPinned: Bool
    @State private var saving = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    init(entry: Binding<ManualEntry>, onDelete: @escaping () -> Void) {
        self._entry = entry
        self.onDelete = onDelete
        let e = entry.wrappedValue
        _title = State(initialValue: e.title)
        _content = State(initialValue: e.content)
        _isPinned = State(initialValue: e.isPinned)
    }

    private var isDirty: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        return (trimmed != entry.title && !trimmed.isEmpty)
            || content != entry.content
            || isPinned != entry.isPinned
    }

    var body: some View {
        Form {
            TextField("Title", text: $title, axis: .vertical)
                    .lineLimit(1...4)
            TextField("Content", text: $content, axis: .vertical)
                .lineLimit(8...24)
            Toggle("Pinned", isOn: $isPinned)
            Section {
                Button("Delete entry", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(!isDirty || saving)
            }
        }
        .confirmationDialog(
            "Delete this entry?", isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete entry", role: .destructive) { deleteEntry() }
        }
        .alert(
            "Something went wrong", isPresented: .constant(errorMessage != nil),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") })
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saving = true
        Task {
            do {
                try await withTimeout(15) {
                    try await ManualRepository.updateEntry(
                        entry,
                        title: trimmed != entry.title ? trimmed : nil,
                        content: content != entry.content ? content : nil,
                        isPinned: isPinned != entry.isPinned ? isPinned : nil)
                }
                entry.title = trimmed
                entry.content = content
                entry.isPinned = isPinned
                entry.updatedAt = Date()
            } catch {
                errorMessage = String(localized: "Couldn't save your changes.")
            }
            saving = false
        }
    }

    private func deleteEntry() {
        Task {
            do {
                try await withTimeout(15) {
                    try await ManualRepository.deleteEntry(entry)
                }
                dismiss()
                onDelete()
            } catch {
                errorMessage = String(localized: "Couldn't delete the entry.")
            }
        }
    }
}

/// Feedback form (submit-only; entries are read by the developer).
struct FeedbackView: View {
    let current: CurrentHousehold

    @Environment(\.dismiss) private var dismiss
    @State private var type: FeedbackRepository.FeedbackType = .general
    @State private var rating: FeedbackRepository.FeedbackRating = .neutral
    @State private var message = ""
    @State private var replyEmail = ""
    @State private var sending = false
    @State private var sent = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Picker("Type", selection: $type) {
                ForEach(FeedbackRepository.FeedbackType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            Picker("How's Pacelli?", selection: $rating) {
                ForEach(FeedbackRepository.FeedbackRating.allCases) { rating in
                    Text(rating.displayName).tag(rating)
                }
            }
            .pickerStyle(.segmented)
            TextField("Tell us more…", text: $message, axis: .vertical)
                .lineLimit(5...12)
            // Optional on purpose. Someone reporting a bug anonymously should
            // not have to identify themselves to be heard — but without this
            // there was no way to reply to anyone, ever.
            Section {
                TextField("Email (only if you'd like a reply)", text: $replyEmail)
                    .accessibilityIdentifier("feedbackReplyEmail")
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Optional. Leave it blank to stay anonymous.")
            }
            Section {
                Button(sending ? "Sending…" : "Send feedback") { send() }
                    .accessibilityIdentifier("sendFeedbackButton")
                    .disabled(
                        message.trimmingCharacters(in: .whitespaces).isEmpty || sending)
            } footer: {
                // Precise rather than reassuring. The old copy said "encrypted
                // like the rest of your household data", which was true and
                // was exactly the bug: it was encrypted to a key only the
                // sender held, so nobody could ever read it.
                Text(
                    "Your message is encrypted on this device so that only the Pacelli developer can read it. Nobody else, including anyone who could reach the database, can."
                )
            }
        }
        .navigationTitle("Send feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thank you!", isPresented: $sent) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your feedback has been sent.")
        }
        .alert(
            "Something went wrong", isPresented: .constant(errorMessage != nil),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") })
    }

    private func send() {
        let text = message.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        sending = true
        Task {
            do {
                let householdId = current.household.id
                let type = type
                let rating = rating
                let email = replyEmail
                try await withTimeout(15) {
                    try await FeedbackRepository.submit(
                        householdId: householdId, type: type, rating: rating,
                        message: text, replyEmail: email)
                }
                sent = true
            } catch {
                errorMessage = String(localized: "Couldn't send your feedback.")
            }
            sending = false
        }
    }
}
