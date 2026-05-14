import Foundation
import Security
#if canImport(AppAuth)
import AppAuth
#endif

/// Thin wrapper around the keychain for AppAuth's OIDAuthState blob.
/// Access policy: `kSecAttrAccessibleAfterFirstUnlock` — the keychain entry
/// is readable once the device has been unlocked at least once after boot
/// (matches the architecture doc §6.1 recommendation).
enum KeychainStore {

    /// Account namespace inside the keychain. The `account` parameter on each
    /// call further scopes the entry per ConnectedAccount.
    private static let service = "net.mcinnis.cadence.auth"

    // MARK: Generic data API

    @discardableResult
    static func save(_ data: Data, for account: String) -> Bool {
        // Try the real keychain first. On a properly-signed device build this
        // is the path we want (encrypted, OS-managed, survives reinstalls).
        if saveToKeychain(data, for: account) { return true }
        // Simulator fallback: an unsigned build hits errSecMissingEntitlement
        // (-34018) because there's no provisioning profile asserting app
        // identity. Persist to a file inside the app sandbox instead so
        // OAuth still works during local development.
        return saveToFile(data, for: account)
    }

    static func load(account: String) -> Data? {
        if let data = loadFromKeychain(account: account) { return data }
        return loadFromFile(account: account)
    }

    @discardableResult
    static func delete(account: String) -> Bool {
        let keychain = deleteFromKeychain(account: account)
        let file = deleteFile(account: account)
        return keychain || file
    }

    // MARK: Real Keychain path

    private static func saveToKeychain(_ data: Data, for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes, uniquingKeysWith: { _, new in new })
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    private static func loadFromKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func deleteFromKeychain(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: File fallback (simulator / unsigned-dev only)

    private static var fallbackDirectory: URL? {
        // Prefer the App Group container so the widget could read shared
        // state if it ever needed to; fall back to the app's Documents dir.
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.net.mcinnis.cadence"
        ) {
            return groupURL.appendingPathComponent("KeychainFallback", isDirectory: true)
        }
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("KeychainFallback", isDirectory: true)
    }

    private static func fallbackURL(for account: String) -> URL? {
        guard let dir = fallbackDirectory else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(account)
    }

    private static func saveToFile(_ data: Data, for account: String) -> Bool {
        guard let url = fallbackURL(for: account) else { return false }
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return true
        } catch {
            return false
        }
    }

    private static func loadFromFile(account: String) -> Data? {
        guard let url = fallbackURL(for: account) else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func deleteFile(account: String) -> Bool {
        guard let url = fallbackURL(for: account) else { return false }
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    // MARK: OIDAuthState convenience

    #if canImport(AppAuth)
    /// Persist an OIDAuthState via NSKeyedArchiver. AppAuth's OIDAuthState
    /// conforms to NSSecureCoding so this is the recommended serialization.
    @discardableResult
    static func saveAuthState(_ state: OIDAuthState, for account: String) -> Bool {
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: state,
                requiringSecureCoding: true
            )
            return save(data, for: account)
        } catch {
            return false
        }
    }

    static func loadAuthState(account: String) -> OIDAuthState? {
        guard let data = load(account: account) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: OIDAuthState.self,
            from: data
        )
    }
    #endif
}
