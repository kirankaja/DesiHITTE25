import Foundation
import Security

/// Keychain-backed storage for third-party API keys. Kept separate from
/// UserDefaults because API keys are sensitive-ish credentials — losing the
/// device shouldn't mean handing over the user's YouTube quota.
///
/// Values are stored with `kSecAttrAccessibleAfterFirstUnlock` so background
/// refresh (e.g. the search pool warming a few seconds after workout start)
/// can still read them even if the phone is locked mid-workout.
final class APIKeyStore {
    static let shared = APIKeyStore()

    // MARK: - Keys

    private enum Key: String {
        case youtube = "com.desihitte25.apikey.youtube"
    }

    // MARK: - Public accessors

    var youtubeAPIKey: String? {
        get { load(.youtube) }
        set {
            if let v = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
                save(v, for: .youtube)
            } else {
                delete(.youtube)
            }
            NotificationCenter.default.post(name: .youtubeAPIKeyDidChange, object: nil)
        }
    }

    var hasYoutubeAPIKey: Bool {
        !(youtubeAPIKey ?? "").isEmpty
    }

    // MARK: - Keychain plumbing

    private func query(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: "DesiHITTE25"
        ]
    }

    private func load(_ key: Key) -> String? {
        var q = query(for: key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func save(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        let q = query(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        // Update-or-insert.
        let updateStatus = SecItemUpdate(q as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insertQuery = q
            insertQuery.merge(attributes) { $1 }
            SecItemAdd(insertQuery as CFDictionary, nil)
        }
    }

    private func delete(_ key: Key) {
        SecItemDelete(query(for: key) as CFDictionary)
    }
}

extension Notification.Name {
    /// Fired whenever the stored YouTube API key changes. YouTubeSearchService
    /// listens so it can invalidate its cached search pool if a new key is
    /// entered (in case the user is switching to a different quota).
    static let youtubeAPIKeyDidChange = Notification.Name("com.desihitte25.youtubeAPIKeyDidChange")
}
