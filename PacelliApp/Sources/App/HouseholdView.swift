import FirebaseAuth
import PacelliKit
import SwiftUI

/// Household management: name (any member can rename), member list, email
/// invites (with the native key handshake), pending invites, member
/// removal (admins).
struct HouseholdView: View {
    let current: CurrentHousehold
    let appState: AppState

    @State private var members: [MembershipService.Member] = []
    @State private var invites: [MembershipService.PendingInvite] = []
    @State private var inviteEmail = ""
    @State private var loading = true
    @State private var infoMessage: String?
    @State private var errorMessage: String?
    @State private var householdName: String
    @State private var savedName: String
    @State private var savingName = false

    init(current: CurrentHousehold, appState: AppState) {
        self.current = current
        self.appState = appState
        _householdName = State(initialValue: current.household.name)
        _savedName = State(initialValue: current.household.name)
    }

    private var myUid: String? { Auth.auth().currentUser?.uid }
    private var isAdmin: Bool { current.role == "admin" }

    private var trimmedName: String {
        householdName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            Section("Household name") {
                HStack(spacing: 12) {
                    TextField("Household name", text: $householdName)
                        .onSubmit(saveName)
                        .accessibilityIdentifier("household_name_field")
                    if savingName {
                        ProgressView()
                    } else if trimmedName != savedName && !trimmedName.isEmpty {
                        Button(action: saveName) {
                            Text("Save").fontWeight(.semibold)
                        }
                        .accessibilityIdentifier("household_name_save")
                    }
                }
            }

            Section("Members") {
                if loading {
                    ProgressView()
                }
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName(for: member))
                            Text(member.role == "admin" ? "Admin" : "Member")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        if isAdmin && member.userId != myUid {
                            Button(role: .destructive) {
                                remove(member)
                            } label: {
                                Label("Remove", systemImage: "person.badge.minus")
                            }
                        }
                    }
                }
            }

            if !invites.isEmpty {
                Section("Pending invites") {
                    ForEach(invites) { invite in
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .foregroundStyle(.secondary)
                            Text(invite.email)
                            Spacer()
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                revoke(invite)
                            } label: {
                                Label("Revoke", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                HStack(spacing: 12) {
                    TextField("Email address", text: $inviteEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(invite)
                    Button(action: invite) {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(!inviteEmail.contains("@"))
                }
            } header: {
                Text("Invite someone")
            } footer: {
                Text(
                    "They join when they sign in to Pacelli with this email. The household key is shared securely as part of the invite."
                )
            }
        }
        .navigationTitle(savedName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
        .alert(
            "Something went wrong", isPresented: .constant(errorMessage != nil),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") })
        .alert(
            "Done", isPresented: .constant(infoMessage != nil),
            actions: { Button("OK") { infoMessage = nil } },
            message: { Text(infoMessage ?? "") })
    }

    private func saveName() {
        let name = trimmedName
        guard !name.isEmpty, name != savedName, !savingName else { return }
        savingName = true
        Task {
            defer { savingName = false }
            do {
                let householdId = current.household.id
                try await withTimeout(15) {
                    try await HouseholdService.renameHousehold(householdId, to: name)
                }
                savedName = name
                appState.householdRenamed(to: name)
            } catch {
                errorMessage = String(localized: "Couldn't rename the household.")
            }
        }
    }

    private func displayName(for member: MembershipService.Member) -> String {
        if member.userId == myUid {
            return member.displayName.map { "\($0) (you)" }
                ?? String(localized: "You")
        }
        return member.displayName ?? String(localized: "Member")
    }

    private func reload() async {
        let householdId = current.household.id
        do {
            members = try await withTimeout(15) {
                try await MembershipService.fetchMembers(householdId: householdId)
            }
            invites =
                (try? await withTimeout(15) {
                    try await MembershipService.fetchPendingInvites(
                        householdId: householdId)
                }) ?? []
            loading = false
        } catch {
            loading = false
            errorMessage = String(localized: "Couldn't load household members.")
        }
    }

    private func invite() {
        let email = inviteEmail.trimmingCharacters(in: .whitespaces)
        guard email.contains("@") else { return }
        inviteEmail = ""
        Task {
            do {
                let householdId = current.household.id
                try await withTimeout(15) {
                    try await MembershipService.inviteByEmail(
                        householdId: householdId, email: email)
                }
                infoMessage = String(
                    localized: "Invite sent. \(email) will join when they sign in with that email.")
                await reload()
            } catch {
                errorMessage = String(localized: "Couldn't send the invite.")
            }
        }
    }

    private func remove(_ member: MembershipService.Member) {
        Task {
            do {
                let householdId = current.household.id
                try await withTimeout(15) {
                    try await MembershipService.removeMember(
                        householdId: householdId, userId: member.userId)
                }
                withAnimation { members.removeAll { $0.id == member.id } }
            } catch {
                errorMessage = String(localized: "Couldn't remove the member.")
            }
        }
    }

    private func revoke(_ invite: MembershipService.PendingInvite) {
        Task {
            do {
                try await withTimeout(15) {
                    try await MembershipService.revokeInvite(invite)
                }
                withAnimation { invites.removeAll { $0.id == invite.id } }
            } catch {
                errorMessage = String(localized: "Couldn't revoke the invite.")
            }
        }
    }
}
