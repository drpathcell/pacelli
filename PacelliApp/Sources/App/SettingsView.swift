import FirebaseAuth
import PacelliKit
import SwiftUI
import UIKit

/// Settings tab: appearance (theme mode + colour scheme), account,
/// data export, privacy & encryption, and the burn-all-data danger zone.
struct SettingsView: View {
    let current: CurrentHousehold
    let appState: AppState

    @AppStorage(ThemeStorageKeys.colorScheme) private var schemeRaw =
        AppColorSchemeChoice.pacelli.rawValue
    @AppStorage(ThemeStorageKeys.themeMode) private var modeRaw =
        AppThemeModeChoice.system.rawValue

    @State private var showAccount = false
    @State private var showExportWarning = false
    @State private var exporting = false
    @State private var exportItem: ExportShareItem?
    @State private var exportError: String?
    @State private var photoBytes: Int64 = 0
    @State private var tidying = false
    @State private var reindexed: Int?

    // The lock's own on/off flag lives in UserDefaults under the same key
    // BiometricLock reads, so RootView and this toggle cannot disagree.
    @AppStorage(BiometricLock.enabledKey) private var lockEnabled = false
    @State private var lock = BiometricLock()

    // Reminder prefs are per-device (a phone, not a household, gets reminded),
    // so they live in UserDefaults rather than Firestore.
    @AppStorage(ReminderPrefs.storageEnabled) private var remindersEnabled = false
    @AppStorage(ReminderPrefs.storageTime) private var reminderTimeRaw = TimeOfDay.noon.raw
    @AppStorage(ReminderPrefs.storageDayBefore) private var reminderDayBefore = false
    @State private var reminderDeniedNotice = false
    @AppStorage(PushService.storageActivityPush) private var activityPush = false

    private var isGuest: Bool { Auth.auth().currentUser?.isAnonymous ?? false }

    /// Ask for permission at the moment reminders are switched on — never at
    /// launch. If the user has previously denied it at the system level the
    /// toggle cannot work, so flip it back rather than leaving a switch that
    /// silently does nothing.
    private func remindersChanged(_ isOn: Bool) async {
        guard isOn else {
            NotificationService.cancelAll()
            return
        }
        let granted = await NotificationService.requestAuthorizationIfNeeded()
        if granted {
            await appState.reconcileReminders()
        } else {
            remindersEnabled = false
            reminderDeniedNotice = true
        }
    }

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

                Section {
                    NavigationLink {
                        HouseholdView(current: current, appState: appState)
                    } label: {
                        Label("Members & invites", systemImage: "person.2")
                    }
                    NavigationLink {
                        ManualView(current: current)
                    } label: {
                        Label("Household manual", systemImage: "book")
                    }
                    NavigationLink {
                        ConnectAIView()
                    } label: {
                        Label("Connect an AI", systemImage: "sparkles")
                    }
                    .accessibilityIdentifier("settings_connect_ai")
                } header: {
                    Text("Household")
                } footer: {
                    Text(
                        "Connecting an AI lets a tool like Claude read and change your household for you. It joins as its own member and you can disconnect it at any time."
                    )
                }

                Section {
                    Toggle("Task reminders", isOn: $remindersEnabled)
                        .accessibilityIdentifier("settings_reminders_toggle")

                    if remindersEnabled {
                        DatePicker(
                            "Remind me at",
                            selection: Binding(
                                get: { (TimeOfDay(raw: reminderTimeRaw) ?? .noon).date },
                                set: { newValue in
                                    let c = Calendar.current.dateComponents(
                                        [.hour, .minute], from: newValue)
                                    reminderTimeRaw = TimeOfDay(
                                        hour: c.hour ?? 12, minute: c.minute ?? 0).raw
                                }),
                            displayedComponents: .hourAndMinute
                        )
                        .accessibilityIdentifier("settings_reminder_time")

                            Toggle("Also remind me the day before", isOn: $reminderDayBefore)
                    }

                    Toggle("Tell me when someone adds a task", isOn: $activityPush)
                        .accessibilityIdentifier("settings_activity_push_toggle")
                } header: {
                    Text("Reminders")
                } footer: {
                    Text(
                        "Tasks with a due date remind you at this time on the day. A task can set its own time. Reminders are created on this device and never leave it. Task alerts from the other person are sent through Apple, and what they say is encrypted."
                    )
                }
                .onChange(of: remindersEnabled) { _, isOn in
                    Task { await remindersChanged(isOn) }
                }
                .onChange(of: reminderTimeRaw) { _, _ in
                    Task { await appState.reconcileReminders() }
                }
                .onChange(of: reminderDayBefore) { _, _ in
                    Task { await appState.reconcileReminders() }
                }
                // Re-register so the SERVER sees the change. The preference
                // lives on the device_tokens row — leaving it local would mean
                // the push still gets sent and the phone still wakes up.
                .onChange(of: activityPush) { _, isOn in
                    Task {
                        if isOn { await NotificationService.requestAuthorizationIfNeeded() }
                        await appState.refreshPushRegistration()
                    }
                }
                // Attached to THIS section, not the List: the export alerts
                // already occupy the List's chain, and a third .alert there
                // silently breaks presentation for all of them (build 32).
                .alert(
                    "Notifications are off", isPresented: $reminderDeniedNotice,
                    actions: {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        Button("Not now", role: .cancel) {}
                    },
                    message: {
                        Text(
                            "Pacelli can't send reminders until you allow notifications in iOS Settings."
                        )
                    }
                )

                Section {
                    NavigationLink("Privacy & encryption") {
                        PrivacyEncryptionView()
                    }
                    if BiometricLock.isAvailable {
                        Toggle(
                            "Require \(BiometricLock.biometryLabel)",
                            isOn: Binding(
                                get: { lockEnabled },
                                set: { want in
                                    Task {
                                        // The toggle follows the outcome, not
                                        // the tap: turning the lock OFF has to
                                        // pass the lock first, or anyone
                                        // holding an unlocked phone just
                                        // switches it off here.
                                        if await lock.setEnabled(want) {
                                            lockEnabled = want
                                        }
                                    }
                                }
                            )
                        )
                        .accessibilityIdentifier("settings_biometric_lock_toggle")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    if BiometricLock.isAvailable {
                        Text(
                            "Locks the app when you switch away from it. Your data is always encrypted; this stops someone holding your unlocked phone from reading it."
                        )
                    }
                }

                // Was filed under "Household" until 2026-08-13, next to members
                // and invites — where nobody looking for support would open it.
                // Two versions shipped with a working feedback channel and not
                // one real message arrived through it. Feedback goes to the
                // developer, not to the household; it gets its own header, and
                // the footer says where it lands, because "Send feedback" alone
                // does not tell you whether a human reads it.
                Section {
                    NavigationLink {
                        FeedbackView(current: current)
                    } label: {
                        Label("Send feedback", systemImage: "envelope")
                    }
                } header: {
                    Text("Help")
                } footer: {
                    Text(
                        "Report a problem or suggest an idea. It goes straight to the developer, encrypted so only they can read it."
                    )
                }

                Section {
                    LabeledContent("Photos on this phone") {
                        Text(ByteCountFormatter.string(
                            fromByteCount: photoBytes, countStyle: .file))
                            .monospacedDigit()
                    }
                    Button {
                        // Safe precisely because the local file is a cache: the
                        // encrypted copy is the durable one, and anything freed
                        // here comes back the next time it is opened.
                        tidying = true
                        Task {
                            defer { tidying = false }
                            let live = (try? await PhotosRepository.liveIds(
                                householdId: current.household.id)) ?? []
                            PhotoStore.reconcile(
                                householdId: current.household.id, keeping: live)
                            PhotoStore.evict(
                                householdId: current.household.id, downTo: 0,
                                protecting: await pendingPhotoIds())
                            photoBytes = PhotoStore.bytesUsed(
                                householdId: current.household.id)
                        }
                    } label: {
                        HStack {
                            Text("Free up space")
                            Spacer()
                            if tidying { ProgressView() }
                        }
                    }
                    .disabled(tidying || photoBytes == 0)
                    .foregroundStyle(.primary)

                    Button {
                        Task {
                            reindexed = await PhotoService.reindexAll(
                                householdId: current.household.id)
                        }
                    } label: {
                        Text("Read photos again for search")
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Photos")
                } footer: {
                    Text(
                        "Freeing space removes the readable copies from this phone. They come back when you open them, and photos still waiting to upload are never removed. Reading again is worth doing after a big iOS update — the text recognition improves."
                    )
                }
                .task {
                    photoBytes = PhotoStore.bytesUsed(householdId: current.household.id)
                }
                .alert(
                    "Done", isPresented: .constant(reindexed != nil),
                    actions: { Button("OK") { reindexed = nil } },
                    message: { Text("Read \(reindexed ?? 0) photo(s) on this phone.") })

                Section {
                    Button {
                        showExportWarning = true
                    } label: {
                        HStack {
                            Label("Export data", systemImage: "square.and.arrow.up")
                            Spacer()
                            if exporting { ProgressView() }
                        }
                    }
                    .foregroundStyle(.primary)
                    .disabled(exporting)
                    .accessibilityIdentifier("settings_export_button")
                    // Export presentation lives on the button, not the List —
                    // stacking a third .alert on the List silently breaks
                    // alert presentation in SwiftUI.
                    .alert("Export a readable copy?", isPresented: $showExportWarning) {
                        Button("Cancel", role: .cancel) {}
                        Button("Export") { runExport() }
                    } message: {
                        Text(
                            "The exported file contains your household data in readable form — it is not encrypted. Keep it somewhere safe."
                        )
                    }
                    .alert(
                        "Something went wrong", isPresented: .constant(exportError != nil),
                        actions: { Button("OK") { exportError = nil } },
                        message: { Text(exportError ?? "") }
                    )
                    .sheet(
                        item: $exportItem,
                        onDismiss: cleanUpExports
                    ) { item in
                        ExportShareSheet(url: item.url)
                            .presentationDetents([.medium, .large])
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text(
                        "Save a backup of everything in your household as a JSON file."
                    )
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

    /// Photos this phone has not managed to upload yet. They are the only
    /// copy that exists, so nothing may evict them.
    private func pendingPhotoIds() async -> Set<String> {
        let all = (try? await PhotosRepository.fetchAll(
            householdId: current.household.id)) ?? []
        return Set(all.filter { $0.uploadState != .ready }.map(\.id))
    }

    /// The export is plaintext — don't leave copies in tmp after the share
    /// sheet closes (pacelli-security-audit §export: temp files auto-deleted).
    private func cleanUpExports() {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        guard let files = try? fm.contentsOfDirectory(atPath: tmp.path) else { return }
        for name in files where name.hasPrefix("Pacelli export") {
            try? fm.removeItem(at: tmp.appendingPathComponent(name))
        }
    }

    private func runExport() {
        guard !exporting else { return }
        exporting = true
        Task {
            defer { exporting = false }
            do {
                let url = try await withTimeout(30) {
                    try await ExportService.exportFile(for: current)
                }
                exportItem = ExportShareItem(url: url)
            } catch {
                print("[SettingsView] export failed: \(error)")
                exportError = String(
                    localized: "Couldn't export your data. Please check your connection and try again.")
            }
        }
    }
}

private struct ExportShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// The system share sheet (no SwiftUI-native equivalent that presents
/// from an async completion; `ShareLink` needs its item up-front).
private struct ExportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController, context: Context
    ) {}
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
                Label("Checklist and plan item quantities", systemImage: "lock.fill")
                Label("Photos you attach", systemImage: "lock.fill")
                Label("What your phone reads in a photo", systemImage: "lock.fill")
                Label("Household name", systemImage: "lock.fill")
                Label("Your display name", systemImage: "lock.fill")
            }

            Section {
                Label("Dates and times", systemImage: "lock.open")
                Label("Completion status and priority", systemImage: "lock.open")
                Label("Category icons and colours", systemImage: "lock.open")
                Label("Sort order and record identifiers", systemImage: "lock.open")
            } header: {
                Text("Not encrypted")
            } footer: {
                Text(
                    "These fields stay readable so the app can query, sort and enforce access rules on the server. They contain no free-text content."
                )
            }

            // The claims on this screen have to stay literally true, and push
            // introduced two new facts about where data goes. Saying nothing
            // would have left the screen quietly inaccurate.
            Section {
                Text(
                    "The picture itself is encrypted on this device before it is stored, and what is stored is bytes — no one operating the servers can open it. A readable copy of each photo stays on the phones of your household and nowhere else. It is kept in a Pacelli folder you can open in the Files app, and it is deliberately left out of your iCloud backup, because that is the one place readable content would otherwise leave your devices."
                )
                .font(.callout)
                Text(
                    "Location data is removed before a photo is stored. A picture taken at home carries your address in it otherwise."
                )
                .font(.callout)
                Text(
                    "Your phone reads the text in a photo so you can search for it later. That happens on the device, and what it reads is encrypted like everything else — no photo is sent anywhere to be looked at."
                )
                .font(.callout)
            } header: {
                Text("Photos")
            }

            Section("Notifications") {
                Text(
                    "Reminders about your own tasks are created on this device and never leave it. When the other person adds a task, a notification is sent through Apple — it says only that a task was added, and the title travels with it still encrypted. Apple never has your household key, so it cannot read it, and neither can we."
                )
                .font(.callout)
                Text(
                    "Feedback you send us is encrypted on this device so that only the Pacelli developer can read it — not with your household key, which never leaves your devices."
                )
                .font(.callout)
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
