//
//  PushFlyConfig.swift
//  PushFly
//

import Foundation

/// SDK-level constants. Kept in its own file so the version number is
/// easy to bump independently of behaviour.
public enum PushFlyConfig {
    /// SDK version. Surfaced via ``PushFly/sdkVersion`` for log
    /// correlation on the backend.
    public static let sdkVersion = "0.1.0"

    /// Default PushFly API origin. Override by passing an explicit
    /// `apiBaseUrl` to ``PushFly/init(_:publishableKey:apiBaseUrl:)``
    /// for self-hosted / preview deployments.
    public static let defaultApiBaseUrl = "http://0.0.0.0:3001"

    /// Version-prefix for every SDK-facing endpoint. The backend spec
    /// (`docs/BACKEND_API.md`) commits to `/v1/sdk/*`.
    public static let apiBasePath = "/v1/sdk"
}
