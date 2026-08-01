import FirebaseAuth
import PacelliKit
import SwiftUI

/// Household management: member list, email invites (with the native key
/// handshake), pending invites, member removal (admins).
struct HouseholdView: View {
    let current: CurrentHousehold

    @State private var members: [MembershipService.Member] = []
    @State private var invites: [MembershipService.PendingInvite] = []
    @State private var inviteEmail = ""
    @State private var loading = true
    @State private var infoMessage: String?
    @State private var errorMessage: String?

    private var myUid: String? { Auth.auth().currentUser?.uid }
    private var isAdmin: Bool { current.role == "admin" }

    var body: some View {
        List {
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
        .navigationTitle(current.household.name)
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
