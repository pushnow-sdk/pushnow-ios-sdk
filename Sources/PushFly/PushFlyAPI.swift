//
//  PushFlyAPI.swift
//  PushFly
//
//  Wire-compatible DTOs for the PushFly SDK endpoints in
//  `docs/BACKEND_API.md`. Internal — not exposed to callers, who only
//  ever see the short `deviceToken` string.
//
//  Every request carries the app's `bundleId` so the backend can
//  route to the correct tenant/application; that's the SDK's identity.
//

import Foundation

// MARK: - POST /v1/sdk/register

struct RegisterRequest: Encodable {
    let platform: String
    let apnsToken: String
    let apnsEnvironment: String
    let bundleId: String
    let deviceModel: String?
    let systemVersion: String?
}

struct RegisterResponse: Decodable {
    let deviceToken: String
    let auth: String
    let createdAt: String?
}

// MARK: - POST /v1/sdk/refresh-apns-token

struct RefreshRequest: Encodable {
    let deviceToken: String
    let auth: String
    let apnsToken: String
    let apnsEnvironment: String
    let bundleId: String
}

// MARK: - POST /v1/sdk/validate

struct ValidateRequest: Encodable {
    let deviceToken: String
    let auth: String
    let bundleId: String
}

struct ValidateResponse: Decodable {
    let valid: Bool
}

// MARK: - POST /v1/sdk/unregister

struct UnregisterRequest: Encodable {
    let deviceToken: String
    let auth: String
    let bundleId: String
}
