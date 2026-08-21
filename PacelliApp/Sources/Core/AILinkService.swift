import FirebaseAuth
import Foundation
import PacelliKit

/// Connecting an AI assistant to the household.
///
/// **This is the first HTTP client in the native app**, and it exists because
/// this one feature cannot be done from the client at all. Everything else the
/// app does goes straight to Firestore under the security rules; pairing an
/// assistant needs `admin.auth().createUser` and `createCustomToken`, which are
/// privileged operations. They run inside `functions/src/functions/ai-link.ts`
/// so that no admin credential ever has to exist on a phone.
///
/// The trust model, restated from the backend because it is what this screen
/// promises the user:
///
///   - the assistant is a **separate household member**, not a borrowed login.
///     Its writes are attributed to it, and revoking it never touches the
///     user's own credentials.
///   - the pairing code is a **bearer secret** with a ten-minute life and one
///     use. Treat it on screen the way you would treat a password: show it,
///     let it be copied, and never persist it.
///
/// Failure is surfaced with the server's own message rather than a generic
/// string, because every error this API returns is actionable by the user —
/// "This pairing code has expired", "Too many requests" — and flattening them
/// into "Something went wrong" would hide the one useful fact.
enum AILinkService {

    // MARK: - Wire types

    struct CreatedLink: Sendable {
        let code: String
        let expiresAt: Date
        let assistantUid: String
        let label: String

        var isExpired: Bool { expiresAt <= Date() }

        /// `4KMQ-7X2P` — grouped for reading off a screen, never for sending.
        /// The API matches on the raw eight characters.
        var formatted: String {
            guard code.count == 8 else { return code }
            let mid = code.index(code.startIndex, offsetBy: 4)
            return "\(code[code.startIndex..<mid])-\(code[mid...])"
        }
    }

    struct Assistant: Identifiable, Sendable {
        let assistantUid: String
        let label: String
        let joinedAt: Date?

        var id: String { assistantUid }
    }

    struct AILinkError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Endpoint

    /// Derived from the bundled Firebase plist rather than hardcoded, so a
    /// project change cannot leave a stale host string behind in Swift. The
    /// region is pinned to match `apiHandler`'s `region: "us-central1"` in
    /// `functions/src/index.ts` — if that moves, this must move with it.
    private static var baseURL: URL {
        let projectId =
            (Bundle.main.object(forInfoDictionaryKey: "FirebaseProjectID") as? String)
            ?? plistProjectId
            ?? "pacelli-35621"
        return URL(string: "https://us-central1-\(projectId).cloudfunctions.net")!
    }

    private static var plistProjectId: String? {
        guard
            let url = Bundle.main.url(
                forResource: "GoogleService-Info", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(
                from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist["PROJECT_ID"] as? String
    }

    // MARK: - Transport

    /// One POST, one `{success, data}` envelope, one decoded payload.
    ///
    /// The ID token is fetched per call rather than cached. Firebase already
    /// caches it internally and refreshes it when it is close to expiry, so a
    /// second cache here would only be a way to send an expired one.
    private static func post(
        _ function: String,
        body: [String: Any] = [:]
    ) async throws -> Any {
        guard let user = Auth.auth().currentUser else {
            throw AILinkError(message: String(localized: "You need to be signed in."))
        }
        let token = try await user.getIDToken()

        var request = URLRequest(url: baseURL.appendingPathComponent(function))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json =
            (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        // The API reports failure in the body as well as the status code, and
        // the body is the half that carries the sentence worth showing.
        if json["success"] as? Bool == true {
            return json["data"] ?? [:]
        }
        if let message = json["error"] as? String, !message.isEmpty {
            throw AILinkError(message: message)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        throw AILinkError(
            message: String(localized: "The server refused the request (\(code))."))
    }

    // MARK: - API

    /// Mint a one-shot pairing code. Each call provisions a distinct assistant,
    /// by design — connecting a laptop and a phone separately is a legitimate
    /// thing to want, and each is revocable on its own.
    static func create(label: String) async throws -> CreatedLink {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = trimmed.isEmpty ? [:] : ["label": trimmed]
        let data = try await post("aiLinkCreate", body: payload)
        guard
            let d = data as? [String: Any],
            let code = d["code"] as? String,
            let uid = d["assistantUid"] as? String
        else {
            throw AILinkError(
                message: String(localized: "The server sent back an unexpected reply."))
        }
        return CreatedLink(
            code: code,
            // A code with no readable expiry is treated as already dead rather
            // than as immortal: the server enforces the real deadline either
            // way, and the safe direction to guess is "expired".
            expiresAt: DartISO8601.date(from: d["expiresAt"] as? String) ?? Date(),
            assistantUid: uid,
            label: d["label"] as? String ?? trimmed)
    }

    /// Every assistant currently attached to the household.
    static func list() async throws -> [Assistant] {
        let data = try await post("aiLinkList")
        guard let rows = data as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            guard let uid = row["assistantUid"] as? String else { return nil }
            return Assistant(
                assistantUid: uid,
                label: row["label"] as? String ?? String(localized: "AI assistant"),
                joinedAt: DartISO8601.date(from: row["joinedAt"] as? String))
        }
        .sorted { ($0.joinedAt ?? .distantPast) < ($1.joinedAt ?? .distantPast) }
    }

    /// Cut an assistant off.
    ///
    /// This goes through the function and NOT through `MembershipService`,
    /// even though the assistant is a `household_members` row and deleting
    /// that row would make it disappear from the UI. Deleting the row alone
    /// leaves a live refresh token and a usable wrapped household key: the
    /// assistant keeps reading for up to an hour and could re-establish
    /// itself. `revokeLink` kills the session and the key first, then the row.
    static func revoke(assistantUid: String) async throws {
        let data = try await post("aiLinkRevoke", body: ["assistantUid": assistantUid])
        // `revoked: false` means the row was not ours to remove. Nothing broke,
        // but nothing happened either, and telling the user "done" would be a
        // lie about whether their assistant still has access.
        if let d = data as? [String: Any], d["revoked"] as? Bool == false {
            throw AILinkError(
                message: String(localized: "That assistant is no longer connected."))
        }
    }
}
