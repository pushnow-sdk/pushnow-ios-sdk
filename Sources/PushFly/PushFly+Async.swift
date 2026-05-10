//
//  PushFly+Async.swift
//  PushFly
//
//  Swift Concurrency wrappers around the completion-based APIs.
//

import Foundation

@available(iOS 13.0, *)
public extension PushFly {
    /// `async` variant of ``onRegister(_:)``. Returns the short PushFly
    /// device token, or throws on failure.
    func onRegister() async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            self.onRegister { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: token)
                }
            }
        }
    }

    /// `async` variant of ``unregister(_:)``.
    func unregister() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.unregister { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
