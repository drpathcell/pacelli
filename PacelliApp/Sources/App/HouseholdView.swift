import FirebaseAuth
import PacelliKit
import SwiftUI

/// Household management: name (any member can rename), member list, email
/// invites (with the native key handshake), pending invites, member
/// removal (admins).
struct HouseholdView: View {
    let current: CurrentHousehold
    let appState: AppState

    @State private var myName = ""
    // `savingName` was already taken by the household-name save below.
    @State private var savingMyName = false
    @State private var members: [MembershipService.Member] = []
    @State private var invites: [MembershipService.PendingInvite] = []
    @State private var inviteEmail = ""
    @State private var joinCode: JoinCodeService.JoinCode?
    @State private var joinCodeBusy = false
    @State private var enteredCode = ""
    @State private var joining = false
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

            Section {
                TextField("Your name", text: $myName)
                    .accessibilityIdentifier("household_my_name")
                    .textContentType(.name)
                    .submitLabel(.done)
                    .onSubmit { Task { await saveMyName() } }
                if savingMyName {
                    Text("Saving…").font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Your name")
            } footer: {
                // Says why the field exists at all. Sign in with Apple returns
                // a name only on the very first authorization, so for most
                // people this is the only way one ever gets set.
                Text(
                    "This is how you appear to the other people in your household. It's encrypted with your household key, like everything else."
                )
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

            Section {
                if joinCodeBusy {
                    ProgressView()
                } else if let joinCode, !joinCode.isExpired {
                    HStack(spacing: 12) {
                        Text(joinCode.formatted)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.semibold)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("join_code_value")
                        Spacer()
                        ShareLink(
                            item: String(
                                localized:
                                    "Join our Pacelli household with this code: \(joinCode.formatted)"
                            )
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Text(expiryLabel(joinCode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Generate a new code", action: regenerateCode)
                    Button("Turn off the code", role: .destructive, action: revokeCode)
                } else {
                    Button(
                        joinCode == nil
                            ? String(localized: "Create a join code")
                            : String(localized: "That code expired — create a new one"),
                        action: regenerateCode
                    )
                    .accessibilityIdentifier("join_code_create")
                }
            } header: {
                Text("Join code")
            } footer: {
                Text(
                    "Read this code out or share it — whoever types it joins straight away, whatever they sign in with. Use this if they sign in with Apple and hide their email, because then nobody can invite that address. Codes last 7 days."
                )
            }

            Section {
                HStack(spacing: 12) {
                    TextField("Code", text: $enteredCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("join_code_field")
                        .onSubmit(joinWithCode)
                    if joining {
                        ProgressView()
                    } else {
                        Button("Join", action: joinWithCode)
                            .disabled(
                                JoinCodeService.normalize(enteredCode).count != 8)
                            .accessibilityIdentifier("join_code_submit")
                    }
                }
            } header: {
                Text("Join another household")
            } footer: {
                Text("Got a code from someone else? Enter it here to switch to their household.")
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

    private func saveMyName() async {
        savingMyName = true
        defer { savingMyName = false }
        try? await HouseholdService.setDisplayName(myName, householdId: current.household.id)
        await reload()
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
        // Prefilled so the field shows what is actually stored, rather than
        // looking empty and inviting someone to retype what they already set.
        if !savingMyName {
            myName = await HouseholdService.currentDisplayName(householdId: householdId)
        }
        do {
            members = try await withTimeout(15) {
                try await MembershipService.fetchMembers(householdId: householdId)
            }
            invites =
                (try? await withTimeout(15) {
                    try await MembershipService.fetchPendingInvites(
                        householdId: householdId)
                }) ?? []
            joinCode =
                (try? await withTimeout(15) {
                    try await JoinCodeService.currentCode(householdId: householdId)
                }) ?? nil
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

    private func expiryLabel(_ code: JoinCodeService.JoinCode) -> String {
        let days = max(
            0,
            Calendar.current.dateComponents(
                [.day], from: Date(), to: code.expiresAt).day ?? 0)
        return days <= 0
            ? String(localized: "Expires today")
            : String(localized: "Expires in \(days) days")
    }

    private func regenerateCode() {
        guard !joinCodeBusy else { return }
        joinCodeBusy = true
        Task {
            defer { joinCodeBusy = false }
            do {
                let householdId = current.household.id
                joinCode = try await withTimeout(20) {
                    try await JoinCodeService.regenerate(householdId: householdId)
                }
            } catch {
                errorMessage = String(localized: "Couldn't create a join code.")
            }
        }
    }

    private func revokeCode() {
        guard !joinCodeBusy else { return }
        joinCodeBusy = true
        Task {
            defer { joinCodeBusy = false }
            do {
                let householdId = current.household.id
                try await withTimeout(15) {
                    try await JoinCodeService.revokeAll(householdId: householdId)
                }
                joinCode = nil
            } catch {
                errorMessage = String(localized: "Couldn't turn off the join code.")
            }
        }
    }

    private func joinWithCode() {
        let code = JoinCodeService.normalize(enteredCode)
        guard code.count == 8, !joining else { return }
        joining = true
        Task {
            defer { joining = false }
            do {
                let joined = try await withTimeout(25) {
                    try await JoinCodeService.join(code: code)
                }
                enteredCode = ""
                await appState.switchToHousehold(joined)
            } catch let error as JoinCodeService.JoinError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = String(localized: "Couldn't join with that code.")
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
