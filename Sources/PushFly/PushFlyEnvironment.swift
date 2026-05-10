//
//  PushFlyEnvironment.swift
//  PushFly
//
//  Detects whether the current build targets the APNs sandbox or
//  production. We parse `embedded.mobileprovision` at runtime —
//  same approach Pushy uses — so the result matches whatever the
//  signing pipeline actually produced, not a Swift compile flag that
//  can be out of sync.
//
//  On the iOS simulator (Intel, Apple Silicon Macs, or Xcode Cloud)
//  the provisioning profile isn't present; we hard-code
//  "development" there because APNs simulator tokens only work with
//  the sandbox endpoint.
//

import Foundation

enum PushFlyEnvironment {
    /// `"development"` or `"production"`. Sent as
    /// `apnsEnvironment` on every `/v1/sdk/register` and
    /// `/v1/sdk/refresh-apns-token` call so the backend knows which
    /// APNs host to route through.
    static func current() -> String {
        #if targetEnvironment(simulator)
        return "development"
        #else
        if let provision = loadMobileProvision(),
           let entitlements = provision["Entitlements"] as? [String: Any],
           let aps = entitlements["aps-environment"] as? String,
           aps == "development" {
            return "development"
        }
        return "production"
        #endif
    }

    /// Parse the binary-wrapped plist embedded in the app bundle.
    /// Returns `nil` on any failure — callers default to production.
    private static func loadMobileProvision() -> NSDictionary? {
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            return nil
        }
        // Read as isoLatin1 so the binary wrapper doesn't get
        // decoded as UTF-8 and rejected.
        guard let raw = try? String(contentsOfFile: path, encoding: .isoLatin1) else {
            return nil
        }
        guard let plistStart = raw.range(of: "<plist"),
              let plistEnd = raw.range(of: "</plist>") else {
            return nil
        }
        let plistSlice = String(raw[plistStart.lowerBound..<plistEnd.upperBound])
        guard let data = plistSlice.data(using: .isoLatin1) else { return nil }
        return try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? NSDictionary
    }
}
