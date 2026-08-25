import FirebaseAuth
import PacelliKit
import SwiftUI

/// Who may burn the household's shared data — the household owner's screen.
///
/// Juan, 2026-08-24: *"The creator of the household should have the freedom to
/// give everyone the possibility to burn all the data or restrict it to only
/// selected people or no one."* This is that, with one thing deliberately
/// absent: it does not and cannot restrict account deletion, which App Store
/// Guideline 5.1.1(v) makes everyone's right. The screen says so, because a
/// person setting this up will otherwise assume it covers both.
///
/// Reachable only when `policy.isOwner`, but that is presentation. The
/// enforcement is `firestore.rules`, which allows `burn_permission` and
/// `burn_allowed_uids` to change only when the caller is the household's
/// `created_by` — a non-owner reaching this screen by any means gets
/// permission-denied from Firestore, not a client-side apology.
struct BurnPermissionView: View {
    let current: CurrentHousehold
    let policy: BurnPolicyService.Policy
    /// Handed back so the screen behind updates without a round trip.
    let onChange: (BurnPolicyService.Policy) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var permission: BurnPolicyService.Permission
    @State private var allowed: Set<String>
    @State private var members: [MembershipService.Member] = []
    @State private var loadingMembers = true
    @State private var saving = false
    @State private var errorMessage: String?

    init(
        current: CurrentHousehold,
        policy: BurnPolicyService.Policy,
        onChange: @escaping (BurnPolicyService.Policy) -> Void
    ) {
        self.current = current
        self.policy = policy
        self.onChange = onChange
        _permission = State(initialValue: policy.permission)
        _allowed = State(initialValue: Set(policy.allowedUids))
    }

    private var uid: String { Auth.auth().currentUser?.uid ?? "" }

    private var dirty: Bool {
        permission != policy.permission
            || (permission == .selected && allowed != Set(policy.allowedUids))
    }

    var body: some View {
        List {
            Section {
                ForEach(BurnPolicyService.Permission.allCases, id: \.self) { option in
                    Button {
                        permission = option
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title).foregroundStyle(.primary)
                                Text(option.explanation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if permission == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .accessibilityIdentifier("burnPermission_\(option.rawValue)")
                }
            } header: {
                Text("Who can erase shared data")
            } footer: {
                Text("This covers tasks, checklists, plans, photos and the manual — everything the household shares.")
            }

            if permission == .selected {
                Section {
                    if loadingMembers {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading members…").foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(members) { member in
                            Button {
                                toggle(member.userId)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(label(for: member))
                                            .foregroundStyle(.primary)
                                        if member.role == "assistant" {
                                            // Worth calling out: an assistant
                                            // ticked here can wipe the
                                            // household on its own judgement.
                                            Text("Connected AI assistant")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if allowed.contains(member.userId) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .accessibilityIdentifier("burnAllow_\(member.userId)")
                        }
                    }
                } header: {
                    Text("Allowed to burn")
                } footer: {
                    Text(allowed.isEmpty
                        ? String(localized: "Nobody is ticked, so nobody can burn — the same as choosing Nobody.")
                        : String(localized: "Only the ticked people can burn. You are not included automatically."))
                }
            }

            Section {
                Label(
                    "Deleting an account is always allowed, for everyone. This setting cannot change that.",
                    systemImage: "person.crop.circle.badge.checkmark")
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .accessibilityIdentifier("burnPermissionError")
                }
            }
        }
        .navigationTitle("Who can burn")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!dirty || saving)
                    .accessibilityIdentifier("burnPermissionSave")
            }
        }
        .task { await loadMembers() }
    }

    private func label(for member: MembershipService.Member) -> String {
        let name = member.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = (name?.isEmpty == false) ? name! : String(localized: "Member")
        return member.userId == uid ? String(localized: "\(base) (you)") : base
    }

    private func toggle(_ userId: String) {
        if allowed.contains(userId) { allowed.remove(userId) } else { allowed.insert(userId) }
    }

    private func loadMembers() async {
        loadingMembers = true
        members = (try? await MembershipService.fetchMembers(
            householdId: current.household.id)) ?? []
        loadingMembers = false
    }

    private func save() {
        saving = true
        errorMessage = nil
        let chosen = permission
        // Only the ticked people who are still members. A uid left over from
        // someone who has since left would otherwise sit in the list forever,
        // and would come back to life if that uid ever rejoined.
        let uids = members.map(\.userId).filter { allowed.contains($0) }
        Task {
            do {
                try await BurnPolicyService.set(
                    chosen, allowedUids: uids, householdId: current.household.id)
                // Recomputed by the server rather than assumed here: the owner
                // may just have removed their own ability to burn, and the
                // screen behind must show that rather than what it hoped for.
                let refreshed = (try? await BurnPolicyService.fetch())
                    ?? BurnPolicyService.Policy(
                        permission: chosen, allowedUids: uids,
                        isOwner: true, mayBurn: false)
                onChange(refreshed)
                saving = false
                dismiss()
            } catch {
                saving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
