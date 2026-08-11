import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

/// Household-manual reads/writes. Parity with the Dart repository —
/// `manual_entries/{uuid}` flat docs, encrypted title/content/tags,
/// Firestore **Timestamp** dates (unique to this collection).
/// v1 scope: entries + pin; manual categories deferred.
enum ManualRepository {
    private static var db: Firestore { Firestore.firestore() }
    private static var uid: String? { Auth.auth().currentUser?.uid }

    /// All entries, pinned first then most-recently-updated.
    static func fetchEntries(householdId: String) async throws -> [ManualEntry] {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let snap = try await db.collection("manual_entries")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()

        return snap.documents
            .compactMap { doc -> ManualEntry? in
                var data = doc.data()
                if let t = data["title"] as? String {
                    data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
                }
                if let c = data["content"] as? String {
                    data["content"] = PacelliCrypto.decryptNullable(c, key: key) ?? c
                }
                if let tags = data["tags"] as? [String] {
                    data["tags"] = tags.map {
                        PacelliCrypto.decryptNullable($0, key: key) ?? $0
                    }
                }
                // Timestamp → Date (this collection alone uses Timestamps).
                if let ts = data["created_at"] as? Timestamp {
                    data["created_at"] = ts.dateValue()
                }
                if let ts = data["updated_at"] as? Timestamp {
                    data["updated_at"] = ts.dateValue()
                }
                return ManualEntry(map: data)
            }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned }
                return $0.updatedAt > $1.updatedAt
            }
    }

    /// Mirrors Dart `createManualEntry` doc shape.
    static func createEntry(
        householdId: String, title: String, content: String = "",
        isPinned: Bool = false
    ) async throws -> ManualEntry {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let now = Date()
        let entry = ManualEntry(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            title: title,
            content: content,
            isPinned: isPinned,
            createdBy: uid,
            createdAt: now,
            updatedAt: now,
            lastEditedBy: uid)

        try await db.collection("manual_entries").document(entry.id).setData([
            "id": entry.id,
            "household_id": householdId,
            "title": try PacelliCrypto.encrypt(title, key: key),
            "content": try PacelliCrypto.encrypt(content, key: key),
            "category_id": NSNull(),
            "tags": [],
            "is_pinned": isPinned,
            "created_by": uid,
            "created_at": Timestamp(date: now),
            "updated_at": Timestamp(date: now),
            "last_edited_by": uid,
        ])
        return entry
    }

    /// Partial update. Mirrors Dart `updateManualEntry`.
    static func updateEntry(
        _ entry: ManualEntry, title: String? = nil, content: String? = nil,
        isPinned: Bool? = nil
    ) async throws {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(entry.householdId)
        else { throw PacelliError.missingHouseholdKey }
        var updates: [String: Any] = [
            "updated_at": Timestamp(date: Date()),
            "last_edited_by": uid,
        ]
        if let title { updates["title"] = try PacelliCrypto.encrypt(title, key: key) }
        if let content {
            updates["content"] = try PacelliCrypto.encrypt(content, key: key)
        }
        if let isPinned { updates["is_pinned"] = isPinned }
        try await db.collection("manual_entries").document(entry.id).updateData(updates)
    }

    /// Mirrors Dart `deleteManualEntry`.
    static func deleteEntry(_ entry: ManualEntry) async throws {
        try await db.collection("manual_entries").document(entry.id).delete()
    }
}

/// Feedback submission.
///
/// Sealed to a Pacelli public key, NOT the household key. Until 2026-08-11
/// this used `loadHouseholdKey` — a key generated on the sender's device and
/// never leaves their Keychain — so every message ever sent was ciphertext
/// nobody could read, including us. Four were sitting unreadable in Firestore
/// when it was found. See `FeedbackSeal` for the format and why.
///
/// Submit-only in the app: it holds no private key and cannot read back what
/// it sends. Retrieval is `scripts/read_feedback.py`.
enum FeedbackRepository {

    /// X25519 public key, raw 32 bytes, base64. The private half never ships
    /// and lives only on the maintainer's machine
    /// (`~/.config/jarvis/secrets/pacelli_feedback_x25519.key`). Safe to
    /// publish — sealing to it is all this key can do.
    static let publicKeyBase64 = "isahawcJ3hRgBAUrgUHItXWrQvQh2gTrtaE/Y0cNvmQ="
    private static var db: Firestore { Firestore.firestore() }

    enum FeedbackType: String, CaseIterable, Identifiable {
        case general, bug
        case featureRequest

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .general: String(localized: "General")
            case .bug: String(localized: "Bug report")
            case .featureRequest: String(localized: "Feature request")
            }
        }
    }

    enum FeedbackRating: String, CaseIterable, Identifiable {
        case positive, neutral, negative

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .positive: String(localized: "😊 Good")
            case .neutral: String(localized: "😐 Okay")
            case .negative: String(localized: "🙁 Bad")
            }
        }
    }

    /// Everything a human would want to read is sealed into one blob so no
    /// single field leaks content. `type` and `rating` stay plaintext: they
    /// are three-way enums useful for triage and reveal essentially nothing.
    static func submit(
        householdId: String, type: FeedbackType, rating: FeedbackRating,
        message: String, replyEmail: String? = nil
    ) async throws {
        guard let user = Auth.auth().currentUser else {
            throw PacelliError.notSignedIn
        }

        let email = replyEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload: [String: Any] = [
            "message": message,
            "email": (email?.isEmpty == false ? email! : NSNull()) as Any,
            // Context worth having when someone reports a bug, and worth
            // sealing rather than storing plainly next to it.
            "app_version": Self.appVersion,
            "os": Self.osVersion,
            "locale": Locale.current.identifier,
            "is_guest": user.isAnonymous,
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        let sealed = try FeedbackSeal.seal(
            String(decoding: json, as: UTF8.self), to: publicKeyBase64)

        let id = UUID().uuidString.lowercased()
        try await db.collection("feedback").document(id).setData([
            "id": id,
            "household_id": householdId,
            "type": type.rawValue,
            "rating": rating.rawValue,
            "message": sealed,
            "context": NSNull(),
            "created_by": user.uid,
            "created_at": DartISO8601.string(from: Date()),
        ])
    }

    /// ProcessInfo rather than UIDevice: `UIDevice.current` is main-actor
    /// isolated and this runs off the main actor.
    private static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "iOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
