import FirebaseAuth
import Foundation

/// The app's one way of talking to a Cloud Function.
///
/// Almost everything Pacelli does goes straight to Firestore under the security
/// rules. Two things cannot: pairing an AI assistant, which needs `createUser`
/// and `createCustomToken`, and photos, which need a signed URL for a bucket no
/// client is allowed to touch. Both are privileged, both stay on the server,
/// and both come through here.
///
/// Extracted from `AILinkService` when photos became the second caller. One
/// transport means one place where the base URL, the token and the
/// `{success, data}` envelope are understood.
enum FunctionsClient {

    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Derived from the bundled Firebase plist rather than hardcoded, so a
    /// project change cannot leave a stale host string behind in Swift. The
    /// region is pinned to match `apiHandler`'s `region: "us-central1"` in
    /// `functions/src/index.ts` — if that moves, this must move with it.
    static var baseURL: URL {
        let projectId = plistProjectId ?? "pacelli-35621"
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

    /// One POST, one `{success, data}` envelope, one decoded payload.
    ///
    /// The ID token is fetched per call rather than cached. Firebase already
    /// caches it internally and refreshes it when it is close to expiry, so a
    /// second cache here could only ever serve an expired one.
    static func post(_ function: String, body: [String: Any] = [:]) async throws -> Any {
        guard let user = Auth.auth().currentUser else {
            throw APIError(message: String(localized: "You need to be signed in."))
        }
        let token = try await user.getIDToken()

        var request = URLRequest(url: baseURL.appendingPathComponent(function))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        // The API reports failure in the body as well as the status code, and
        // the body is the half that carries the sentence worth showing.
        if json["success"] as? Bool == true {
            return json["data"] ?? [:]
        }
        if let message = json["error"] as? String, !message.isEmpty {
            throw APIError(message: message)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        throw APIError(
            message: String(localized: "The server refused the request (\(code))."))
    }

    /// Same, insisting the payload is a dictionary.
    static func postObject(
        _ function: String, body: [String: Any] = [:]
    ) async throws -> [String: Any] {
        guard let d = try await post(function, body: body) as? [String: Any] else {
            throw APIError(
                message: String(localized: "The server sent back an unexpected reply."))
        }
        return d
    }
}
