import Foundation
import Security

/// Minimal Keychain wrapper for the household-key cache.
/// Replaces flutter_secure_storage; same logical keys (`hk_<householdId>`).
///
/// Since Phase C the household key also has to be readable by the notification
/// extension, which is a separate process and therefore a separate keychain
/// client. That is done with a **keychain access group** — the app and the
/// extension both hold the `keychain-access-groups` entitlement for
/// `5PCNU95W9V.com.pacelli.shared`, and items written there are visible to
/// both and to nothing else.
///
/// Everything below is written so that a device where the access group is not
/// available — an old install, a signing misconfiguration, the simulator —
/// keeps working exactly as it did before, with the extension simply unable to
/// decrypt and iOS showing the generic notification body. Degrading is always
/// the fallback; never failing to store the key at all.
public enum SecureStore {
    private static let service = "com.pacelli.pacelli"

    /// Shared between the app and the notification extension.
    ///
    /// The team-id prefix is what the OS enforces: an app can only claim
    /// groups its entitlement lists, and its entitlement can only list groups
    /// under its own team prefix. The App Store profile already grants
    /// `5PCNU95W9V.*` (verified 2026-08-11), so no profile regeneration was
    /// needed for the app itself.
    public static let accessGroup = "5PCNU95W9V.com.pacelli.shared"

    private static func query(_ key: String, group: String?) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let group { q[kSecAttrAccessGroup as String] = group }
        return q
    }

    /// Shared group first, then the app's private keychain.
    ///
    /// The second lookup is what makes an upgrade seamless: everyone who
    /// already has a key has it outside the group, and must keep working
    /// before any migration has run.
    public static func read(_ key: String) -> String? {
        for group in [accessGroup, nil] {
            var q = query(key, group: group)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            if SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
                let data = item as? Data,
                let value = String(data: data, encoding: .utf8)
            {
                return value
            }
        }
        return nil
    }

    /// Writes into the shared group, falling back to the private keychain.
    ///
    /// The fallback matters: without the entitlement — on the simulator, or if
    /// signing is ever misconfigured — a group write fails with
    /// `errSecMissingEntitlement` and, unhandled, the key would simply not be
    /// stored. That would not degrade the notification body, it would break
    /// offline decryption for the whole app.
    @discardableResult
    public static func write(_ key: String, value: String) -> Bool {
        // Delete from BOTH locations first, or a stale copy in the other one
        // wins on the next read and quietly serves an old key.
        SecItemDelete(query(key, group: accessGroup) as CFDictionary)
        SecItemDelete(query(key, group: nil) as CFDictionary)

        for group in [accessGroup, nil] {
            var add = query(key, group: group)
            add[kSecValueData as String] = Data(value.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            if SecItemAdd(add as CFDictionary, nil) == errSecSuccess {
                return group != nil
            }
        }
        return false
    }

    /// Moves an existing key into the shared group so the extension can read
    /// it. Safe to call repeatedly; a no-op once the item is already there.
    ///
    /// A failure here is not worth surfacing: `KeyManager.loadHouseholdKey`
    /// re-fetches and re-wraps from `household_keys` on a cache miss
    /// (verified, not assumed), so the app self-heals — the only casualty is
    /// that notifications show the generic body until it succeeds.
    @discardableResult
    public static func migrateToAccessGroup(_ key: String) -> Bool {
        var q = query(key, group: accessGroup)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var existing: CFTypeRef?
        if SecItemCopyMatching(q as CFDictionary, &existing) == errSecSuccess {
            return true  // already shared
        }

        var old = query(key, group: nil)
        old[kSecReturnData as String] = true
        old[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(old as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else { return false }

        return write(key, value: value)
    }

    public static func delete(_ key: String) {
        // Both locations, always. Deleting only one leaves the household key
        // readable by the extension after the app believes it is gone.
        SecItemDelete(query(key, group: accessGroup) as CFDictionary)
        SecItemDelete(query(key, group: nil) as CFDictionary)
    }

    /// Clears every Pacelli keychain entry (sign-out / burn).
    ///
    /// Security-critical that this covers the shared group too: a burn that
    /// wiped only the app's private keychain would leave the household key
    /// sitting in a group the extension can still read.
    public static func deleteAll() {
        for group in [accessGroup, nil] {
            var q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
            ]
            if let group { q[kSecAttrAccessGroup as String] = group }
            SecItemDelete(q as CFDictionary)
        }
    }
}
