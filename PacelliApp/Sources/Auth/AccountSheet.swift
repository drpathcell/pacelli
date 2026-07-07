import FirebaseAuth
import SwiftUI

/// Account panel from Home. Grows into Settings in later phases.
/// Guests get the upgrade CTA (5.1.1(v): account creation is an optional
/// upgrade, never a gate) with a clear data-continuity promise.
struct AccountSheet: View {
    let appState: AppState

    @Environment(\.dismiss) private var dismiss
    @State private var showUpgrade = false

    private var user: User? { Auth.auth().currentUser }
    private var isGuest: Bool { user?.isAnonymous ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isGuest {
                        Label("Using Pacelli as a guest", systemImage: "person.fill.questionmark")
                        Text("Your data lives safely in this household. Create an account to keep it if you switch devices.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Label(
                            user?.email ?? user?.displayName ?? String(localized: "Signed in"),
                            systemImage: "person.crop.circle.fill.badge.checkmark")
                    }
                }

                if isGuest {
                    Section {
                        Button {
                            showUpgrade = true
                        } label: {
                            Label("Create account", systemImage: "person.crop.circle.badge.plus")
                        }
                    } footer: {
                        Text("Your household and tasks come with you — nothing is lost.")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        dismiss()
                        Task { await appState.signOut() }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showUpgrade) {
                AuthView(mode: .upgrade, appState: appState)
            }
        }
    }
}
