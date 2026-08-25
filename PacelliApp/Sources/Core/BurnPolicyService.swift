import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

/// Who is allowed to destroy the household's shared data.
///
/// Added in 1.10.0, when "burn all data" split into two things that had always
/// been one:
///
///   - **Delete my account** — everyone, always, no permission consulted. App
///     Store Guideline 5.1.1(v) makes in-app account deletion mandatory, so it
///     cannot be gated and this type is never asked about it.
///   - **Burn household data** — the owner's call, which is what this is.
///
/// ## Why reading the policy costs a network call
///
/// The app can read the household document directly; it has permission. But
/// then "may I burn?" would exist twice — once here and once in the
/// `burnHousehold` function — and the two would drift, in the direction where
/// the UI offers a button the server refuses. So the answer comes from the
/// same code that enforces it. The UI can be wrong about a lot of things; it
/// must not be wrong about this one.
///
/// Writing the policy goes straight to Firestore, because `firestore.rules`
/// genuinely can enforce that half: only `created_by` may change
/// `burn_permission` or `burn_allowed_uids` on the household document.
enum BurnPolicyService {

    enum Permission: String, CaseIterable, Sendable {
        case owner
        case selected
        case everyone
        case nobody

        var title: String {
            switch self {
            case .owner: String(localized: "Only me")
            case .selected: String(localized: "Only people I choose")
            case .everyone: String(localized: "Anyone in the household")
            case .nobody: String(localized: "Nobody")
            }
        }

        var explanation: String {
            switch self {
            case .owner:
                String(localized: "You are the only person who can erase the household's shared data.")
            case .selected:
                String(localized: "Only the people you tick below can erase the household's shared data. Add yourself if you want to keep the ability.")
            case .everyone:
                String(localized: "Any member — including a connected AI assistant — can erase everything the household shares.")
            case .nobody:
                String(localized: "Nobody can erase the household's shared data from this screen, including you. You can change this setting back at any time.")
            }
        }
    }

    struct Policy: Sendable {
        let permission: Permission
        let allowedUids: [String]
        /// Whether the caller may CHANGE the policy. Anchored on the household
        /// document's `created_by`, the same field the rules trust.
        let isOwner: Bool
        /// Whether the caller may burn RIGHT NOW under the current policy.
        /// Decided by the server, never recomputed here.
        let mayBurn: Bool

        /// What a client that could not reach the server assumes. Failing
        /// closed matters more than the screen looking complete: offering a
        /// burn the server would refuse is a worse experience than an honest
        /// "couldn't check".
        static let unknown = Policy(
            permission: .owner, allowedUids: [], isOwner: false, mayBurn: false)
    }

    static func fetch() async throws -> Policy {
        let data = try await FunctionsClient.postObject("burnPolicy")
        let raw = data["permission"] as? String ?? Permission.owner.rawValue
        return Policy(
            permission: Permission(rawValue: raw) ?? .owner,
            allowedUids: (data["allowed_uids"] as? [String]) ?? [],
            isOwner: data["is_owner"] as? Bool ?? false,
            mayBurn: data["may_burn"] as? Bool ?? false)
    }

    /// Owner-only, enforced in `firestore.rules`. A non-owner reaching this
    /// gets permission-denied from Firestore rather than a client-side guard,
    /// which is the correct place for it to fail.
    ///
    /// `burn_allowed_uids` is written on every change, not only for `selected`,
    /// so that switching to `selected` and back does not resurrect an old list
    /// the owner has forgotten about.
    static func set(
        _ permission: Permission, allowedUids: [String], householdId: String
    ) async throws {
        try await Firestore.firestore().collection("households").document(householdId)
            .updateData([
                "burn_permission": permission.rawValue,
                "burn_allowed_uids": permission == .selected ? allowedUids : [],
            ])
    }
}
