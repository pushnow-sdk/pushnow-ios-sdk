//
//  PushFlyErrorTests.swift
//  PushFlyTests
//

import XCTest
@testable import PushFly

final class PushFlyErrorTests: XCTestCase {

    func testToNSErrorCarriesCode() {
        let err = PushFlyError(
            code: .pushPermissionDenied,
            message: "nope"
        )
        let ns = err.toNSError()
        XCTAssertEqual(ns.domain, PushFlyError.errorDomain)
        XCTAssertEqual(ns.userInfo[PushFlyError.codeUserInfoKey] as? String, "push_permission_denied")
        XCTAssertEqual(ns.localizedDescription, "nope")
    }

    func testDescription() {
        let err = PushFlyError(code: .timedOut, message: "slow")
        XCTAssertTrue(err.description.contains("timed_out"))
        XCTAssertTrue(err.description.contains("slow"))
    }

    func testUnderlyingErrorBridges() {
        let inner = NSError(domain: "x", code: 7, userInfo: nil)
        let err = PushFlyError(code: .apnsRegistrationFailed, message: "bad", underlying: inner)
        let ns = err.toNSError()
        let bridged = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        XCTAssertEqual(bridged?.domain, "x")
        XCTAssertEqual(bridged?.code, 7)
    }

    /// Regression guard: callers receive the real backend message via
    /// `error.localizedDescription`, not the generic "The operation
    /// couldn't be completed…" placeholder that shows up when a Swift
    /// `Error` doesn't conform to `LocalizedError`.
    func testLocalizedDescriptionCarriesMessage() {
        let err = PushFlyError(
            code: .notFound,
            message: #"no application registered for bundleId 'me.pushfly.App'"#
        )
        let asError: any Error = err
        XCTAssertEqual(
            asError.localizedDescription,
            #"no application registered for bundleId 'me.pushfly.App'"#
        )
        // Same check through the Obj-C bridge that hosts see when they
        // cast `(any Error)` to `NSError`.
        let ns = asError as NSError
        XCTAssertEqual(
            ns.localizedDescription,
            #"no application registered for bundleId 'me.pushfly.App'"#
        )
    }

    func testLocalizedDescriptionFallsBackToCodeWhenMessageEmpty() {
        let err = PushFlyError(code: .timedOut, message: "")
        XCTAssertEqual((err as any Error).localizedDescription, "timed_out")
    }
}
