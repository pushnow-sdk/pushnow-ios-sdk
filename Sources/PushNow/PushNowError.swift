//
//  PushNowError.swift
//  PushNow
//

import Foundation

/// Stable error codes surfaced by the SDK.
///
/// Codes split into two groups:
///
/// - **Client-side:** generated on device without reaching the server
///   (permission denied, APNs failure, no network, etc.)
/// - **Backend-mirrored:** forwarded verbatim from the PushNow `ApiError`
///   envelope so callers can switch on the same string either side.
///   The full list lives in `docs/BACKEND_API.md`.
public struct PushNowErrorCode: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    // Client-side
    public static let pushPermissionDenied    = PushNowErrorCode(rawValue: "push_permission_denied")
    public static let apnsRegistrationFailed  = PushNowErrorCode(rawValue: "apns_registration_failed")
    public static let notConfigured           = PushNowErrorCode(rawValue: "not_configured")
    public static let alreadyInFlight         = PushNowErrorCode(rawValue: "already_in_flight")
    public static let timedOut                = PushNowErrorCode(rawValue: "timed_out")
    public static let missingBundleId         = PushNowErrorCode(rawValue: "missing_bundle_id")
    public static let networkError            = PushNowErrorCode(rawValue: "network_error")
    public static let invalidResponse         = PushNowErrorCode(rawValue: "invalid_response")

    // Backend-mirrored. Codes match the wire contract verbatim; the
    // set below covers everything documented in
    // `docs/BACKEND_API.md` §"Complete error code table". Unknown
    // codes pass through as ``PushNowErrorCode(rawValue: rawString)``
    // so future additions don't require an SDK release.
    public static let invalidRequest          = PushNowErrorCode(rawValue: "invalid_request")
    public static let malformedJson           = PushNowErrorCode(rawValue: "malformed_json")
    public static let invalidApnsToken        = PushNowErrorCode(rawValue: "invalid_apns_token")
    public static let invalidCredentials      = PushNowErrorCode(rawValue: "invalid_credentials")
    /// Register-time: `bundleId` doesn't match any Application on the
    /// backend. The host app either hasn't been onboarded in the
    /// PushNow dashboard or is shipping a pre-release bundle ID.
    public static let notFound                = PushNowErrorCode(rawValue: "not_found")
    /// Refresh-time: `deviceToken` no longer exists server-side.
    /// Recovery is a fresh `/register` call with the current APNs
    /// token (same as `invalidCredentials`).
    public static let deviceNotFound          = PushNowErrorCode(rawValue: "device_not_found")
    public static let rateLimited             = PushNowErrorCode(rawValue: "rate_limited")
    public static let internalError           = PushNowErrorCode(rawValue: "internal_error")
}

/// Errors raised by the PushNow SDK.
///
/// Conforms to ``LocalizedError`` so `error.localizedDescription` and
/// the Obj-C `NSError.localizedDescription` both return the real
/// SDK/backend message instead of the default "The operation couldn't
/// be completed. (...) error N." placeholder.
public struct PushNowError: Error, LocalizedError, CustomStringConvertible, Sendable {
    public let code: PushNowErrorCode
    public let message: String
    public let httpStatus: Int?
    public let retryAfterSeconds: Int?
    /// JSON path to the offending field on validation errors
    /// (`"apnsToken"`, `"bundleId"`, etc.). Populated from the
    /// backend's `field` envelope key. `nil` for non-validation errors.
    public let field: String?
    public let underlying: NSError?

    public init(
        code: PushNowErrorCode,
        message: String,
        httpStatus: Int? = nil,
        retryAfterSeconds: Int? = nil,
        field: String? = nil,
        underlying: Error? = nil
    ) {
        self.code = code
        self.message = message
        self.httpStatus = httpStatus
        self.retryAfterSeconds = retryAfterSeconds
        self.field = field
        self.underlying = underlying.map { $0 as NSError }
    }

    // MARK: - LocalizedError

    /// Surfaced via `error.localizedDescription` (and the Obj-C
    /// `NSError.localizedDescription`). Carries the backend's
    /// human-readable message verbatim when present; falls back to the
    /// stable error code so the string is never empty.
    public var errorDescription: String? {
        message.isEmpty ? code.rawValue : message
    }

    /// The stable error code, surfaced as the `failureReason` so
    /// tooling that renders both fields (e.g. NSAlert) shows the
    /// human message on top and the machine-readable code below.
    public var failureReason: String? { code.rawValue }

    public var description: String {
        "PushNowError(\(code.rawValue)): \(message)"
    }

    // MARK: - NSError bridging for Objective-C callers

    public static let errorDomain = "me.pushnow.PushNowError"
    public static let codeUserInfoKey = "PushNowErrorCode"
    public static let httpStatusUserInfoKey = "PushNowHttpStatus"
    public static let retryAfterUserInfoKey = "PushNowRetryAfterSeconds"
    public static let fieldUserInfoKey = "PushNowField"

    public func toNSError() -> NSError {
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: message,
            PushNowError.codeUserInfoKey: code.rawValue
        ]
        if let s = httpStatus { userInfo[PushNowError.httpStatusUserInfoKey] = s }
        if let r = retryAfterSeconds { userInfo[PushNowError.retryAfterUserInfoKey] = r }
        if let f = field { userInfo[PushNowError.fieldUserInfoKey] = f }
        if let u = underlying { userInfo[NSUnderlyingErrorKey] = u }
        return NSError(
            domain: PushNowError.errorDomain,
            code: Int(bitPattern: UInt(truncatingIfNeeded: code.rawValue.hashValue)),
            userInfo: userInfo
        )
    }
}
