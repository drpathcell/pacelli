import SwiftUI
import UIKit

/// Settings → Connect an AI.
///
/// The backend for this shipped in 1.6.0 and has been reachable only from
/// `scripts/pacelli.py` ever since — a household feature that required a
/// terminal. This screen is the whole feature as far as a user is concerned.
///
/// Two things drive the layout:
///
///  1. **The code is a bearer secret with a ten-minute life.** It is shown
///     once, held only in `@State`, and never written anywhere — no
///     UserDefaults, no Keychain, no Firestore read-back. When it expires the
///     view stops showing it rather than leaving a dead string on screen that
///     someone will try to paste.
///  2. **An assistant is a member, not a setting.** The connected list is the
///     point of the screen, not an afterthought below the button: it is where
///     you see what has access and where you take it away.
struct ConnectAIView: View {
    @State private var assistants: [AILinkService.Assistant] = []
    @State private var label = ""
    @State private var newCode: AILinkService.CreatedLink?
    @State private var loading = true
    @State private var creating = false
    @State private var errorMessage: String?
    @State private var copied = false
    /// The code is the whole point of this screen, and it is drawn above the
    /// field that makes it. Leaving the field focused after a create puts the
    /// keyboard over the thing the user just asked for.
    @FocusState private var labelFocused: Bool

    /// Drives the countdown and the expiry cut-off. One second is plenty for a
    /// ten-minute deadline and costs nothing while the screen is open.
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var liveCode: AILinkService.CreatedLink? {
        guard let newCode, newCode.expiresAt > now else { return nil }
        return newCode
    }

    var body: some View {
        List {
            Section {
                if loading {
                    ProgressView()
                } else if assistants.isEmpty {
                    Text("No assistant is connected.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("ai_link_empty")
                } else {
                    ForEach(assistants) { assistant in
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(assistant.label)
                                Text(joinedLabel(assistant))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .accessibilityIdentifier("ai_link_row")
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                revoke(assistant)
                            } label: {
                                Label("Disconnect", systemImage: "minus.circle")
                            }
                        }
                    }
                }
            } header: {
                Text("Connected")
            } footer: {
                Text(
                    "An assistant joins your household as its own member. What it changes is recorded as its work, not yours, and disconnecting it never affects your own sign-in. Swipe a row to disconnect."
                )
            }

            if let code = liveCode {
                Section {
                    HStack(spacing: 12) {
                        Text(code.formatted)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.semibold)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("ai_link_code_value")
                        Spacer()
                        Button {
                            UIPasteboard.general.string = code.code
                            copied = true
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("ai_link_code_copy")
                    }
                    HStack(spacing: 4) {
                        Text("Expires in")
                        Text(timerInterval: now...code.expiresAt, countsDown: true)
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Pairing code")
                } footer: {
                    Text(
                        "Give this to your AI tool within ten minutes. It works once, and only once. The assistant appears above as soon as it uses the code — not before, so an unused code leaves nothing behind."
                    )
                }
            }

            Section {
                TextField("Name it — \"Claude on my laptop\"", text: $label)
                    .accessibilityIdentifier("ai_link_label_field")
                    .focused($labelFocused)
                    .submitLabel(.done)
                    .onSubmit(create)
                if creating {
                    ProgressView()
                } else {
                    Button(
                        liveCode == nil
                            ? String(localized: "Create a pairing code")
                            : String(localized: "Create another code"),
                        action: create
                    )
                    .accessibilityIdentifier("ai_link_create")
                }
            } header: {
                Text("Connect an assistant")
            } footer: {
                Text(
                    "Connect one for each tool you use — a laptop and a phone are two assistants, and each can be disconnected on its own. The name is only so you can tell them apart here."
                )
            }
        }
        .navigationTitle("Connect an AI")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
        .onReceive(tick) { now = $0 }
        .alert(
            "Something went wrong", isPresented: .constant(errorMessage != nil),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") })
    }

    private func joinedLabel(_ assistant: AILinkService.Assistant) -> String {
        guard let joined = assistant.joinedAt else {
            return String(localized: "Connected")
        }
        return String(
            localized: "Connected \(joined.formatted(date: .abbreviated, time: .omitted))")
    }

    private func reload() async {
        do {
            assistants = try await withTimeout(20) { try await AILinkService.list() }
            loading = false
        } catch {
            loading = false
            errorMessage = message(for: error)
        }
    }

    private func create() {
        guard !creating else { return }
        labelFocused = false
        creating = true
        copied = false
        Task {
            defer { creating = false }
            do {
                let name = label
                newCode = try await withTimeout(25) {
                    try await AILinkService.create(label: name)
                }
                label = ""
            } catch {
                errorMessage = message(for: error)
            }
        }
    }

    private func revoke(_ assistant: AILinkService.Assistant) {
        Task {
            do {
                let uid = assistant.assistantUid
                try await withTimeout(20) {
                    try await AILinkService.revoke(assistantUid: uid)
                }
                withAnimation { assistants.removeAll { $0.id == assistant.id } }
            } catch {
                errorMessage = message(for: error)
                // The row is only removed on a confirmed revoke, so a failure
                // must put the truth back on screen rather than leave a list
                // that says the assistant is gone when it is not.
                await reload()
            }
        }
    }

    /// The API's own sentences are the useful ones; only a timeout and a
    /// dropped connection need a string of our own.
    private func message(for error: Error) -> String {
        if let linkError = error as? AILinkService.AILinkError {
            return linkError.message
        }
        return String(
            localized: "Couldn't reach Pacelli. Please check your connection and try again.")
    }
}
