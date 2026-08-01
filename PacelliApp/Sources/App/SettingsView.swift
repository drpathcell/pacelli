import FirebaseAuth
import PacelliKit
import SwiftUI

/// Settings tab: appearance (theme mode + colour scheme), account,
/// privacy & encryption, and the burn-all-data danger zone.
struct SettingsView: View {
    let current: CurrentHousehold
    let appState: AppState

    @AppStorage(ThemeStorageKeys.colorScheme) private var schemeRaw =
        AppColorSchemeChoice.pacelli.rawValue
    @AppStorage(ThemeStorageKeys.themeMode) private var modeRaw =
        AppThemeModeChoice.system.rawValue

    @State private var showAccount = false

    private var isGuest: Bool { Auth.auth().currentUser?.isAnonymous ?? false }

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $modeRaw) {
                        ForEach(AppThemeModeChoice.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    Picker(selection: $schemeRaw) {
                        ForEach(AppColorSchemeChoice.allCases) { scheme in
                            Text(scheme.displayName).tag(scheme.rawValue)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Colours")
                            Image(systemName: "circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(
                                    (AppColorSchemeChoice(rawValue: schemeRaw)
                                        ?? .pacelli).tint)
                        }
                    }
                }

                Section("Account") {
                    Button {
                        showAccount = true
                    } label: {
                        HStack {
                            Text(isGuest ? "Guest — create an account" : "Manage account")
                            Spacer()
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section("Privacy") {
                    NavigationLink("Privacy & encryption") {
                        PrivacyEncryptionView()
                    }
                }

                Section {
                    NavigationLink {
                        BurnDataView(appState: appState)
                    } label: {
                        Label("Burn all data", systemImage: "flame")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Danger zone")
                } footer: {
                    Text("Permanently deletes your household data and your account.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showAccount) {
                AccountSheet(appState: appState)
                    .presentationDetents([.medium])
            }
        }
    }
}

/// The "what is / isn't encrypted" lists MUST match the implementation
/// exactly (pacelli-security-audit §Phase 5). Update this screen in the
/// same commit as any change to what gets encrypted.
struct PrivacyEncryptionView: View {
    var body: some View {
        List {
            Section {
                Text(
                    "Your content is encrypted on this device with AES-256 before it is uploaded. Each household has its own random key; that key is wrapped with a key derived from your account and stored so only household members can unwrap it. Your keys are cached in the device Keychain and never leave your devices unencrypted."
                )
                .font(.callout)
            }

            Section("Encrypted before upload") {
                Label("Task titles and notes", systemImage: "lock.fill")
                Label("Subtask titles", systemImage: "lock.fill")
                Label("Checklist titles and item titles", systemImage: "lock.fill")
                Label(
                    "Plan titles, entry titles, labels and descriptions",
                    systemImage: "lock.fill")
                Label("Category names", systemImage: "lock.fill")
                Label("Household name", systemImage: "lock.fill")
                Label("Your display name", systemImage: "lock.fill")
            }

            Section {
                Label("Dates and times", systemImage: "lock.open")
                Label("Completion status and priority", systemImage: "lock.open")
                Label("Item quantities", systemImage: "lock.open")
                Label("Category icons and colours", systemImage: "lock.open")
                Label("Sort order and record identifiers", systemImage: "lock.open")
            } header: {
                Text("Not encrypted")
            } footer: {
                Text(
                    "These fields stay readable so the app can query, sort and enforce access rules on the server. They contain no free-text content."
                )
            }

            Section("Access control") {
                Text(
                    "Every record is tied to your household. Server rules only allow access to signed-in members of that household — including for guest accounts."
                )
                .font(.callout)
            }
        }
        .navigationTitle("Privacy & encryption")
        .navigationBarTitleDisplayMode(.inline)
    }
}
