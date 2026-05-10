//
//  PushFlyStorage.swift
//  PushFly
//
//  Keychain-backed storage for the registration triple:
//    - apnsToken   — the real long hex from Apple
//    - deviceToken — the short PushFly-issued ID the app talks about
//    - auth        — per-device secret used to authenticate follow-up
//                    SDK calls (refresh / validate / unregister)
//
//  All three are written atomically at register time and cleared on
//  unregister / server-side revocation.
//

import Foundation
import Security

/// Abstraction over persistent key-value storage. Injected into
/// ``PushFly`` so unit tests can substitute an in-memory implementation.
protocol PushFlyStorage: AnyObject {
    func string(forKey key: String) -> String?
    func setString(_ value: String?, forKey key: String)
}

enum PushFlyStorageKeys {
    static let apnsToken    = "_pushflyApnsToken"
    static let deviceToken  = "_pushflyDeviceToken"
    static let auth         = "_pushflyAuth"
}

/// Default keychain-backed storage, mirrored to `UserDefaults` for
/// cheap reads. Keys are namespaced so they can't collide with
/// host-app data.
final class DefaultPushFlyStorage: PushFlyStorage {
    private let service: String
    private let defaults: UserDefaults

    init(service: String = "me.pushfly.sdk", defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? {
        if let defaultsValue = defaults.string(forKey: key) {
            return defaultsValue
        }
        if let keychainValue = readKeychain(key: key) {
            defaults.set(keychainValue, forKey: key)
            return keychainValue
        }
        return nil
    }

    func setString(_ value: String?, forKey key: String) {
        defaults.set(value, forKey: key)
        writeKeychain(key: key, value: value)
    }

    private func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            // `AfterFirstUnlockThisDeviceOnly` — the `auth` secret
            // must not sync to other devices via iCloud Keychain; it
            // identifies *this* install. `AfterFirstUnlock` makes the
            // value readable in the background after a reboot so the
            // SDK can refresh the APNs mapping without needing the
            // user to unlock first.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }

    private func readKeychain(key: String) -> String? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func writeKeychain(key: String, value: String?) {
        let base = baseQuery(key: key)
        guard let value, let data = value.data(using: .utf8) else {
            SecItemDelete(base as CFDictionary)
            return
        }
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = base
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}

/// In-memory storage used by tests.
final class InMemoryPushFlyStorage: PushFlyStorage {
    private var strings: [String: String] = [:]
    private let lock = NSLock()

    func string(forKey key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return strings[key]
    }

    func setString(_ value: String?, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        if let value { strings[key] = value } else { strings.removeValue(forKey: key) }
    }
}
