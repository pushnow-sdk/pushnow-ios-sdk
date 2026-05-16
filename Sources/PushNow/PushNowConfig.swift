//
//  PushNowConfig.swift
//  PushNow
//

import Foundation

/// SDK-level constants. Kept in its own file so the version number is
/// easy to bump independently of behaviour.
public enum PushNowConfig {
    /// SDK version. Surfaced via ``PushNow/sdkVersion`` for log
    /// correlation on the backend.
    public static let sdkVersion = "0.1.0"

    /// Default PushNow API origin. Override by passing an explicit
    /// `apiBaseUrl` to ``PushNow/init(_:apiBaseUrl:)``
    /// for self-hosted / preview deployments.
    public static let defaultApiBaseUrl = "https://api.pushnow.me/"

    /// Version-prefix for every SDK-facing endpoint. The backend spec
    /// (`docs/BACKEND_API.md`) commits to `/v1/sdk/*`.
    public static let apiBasePath = "/v1/sdk"
}
